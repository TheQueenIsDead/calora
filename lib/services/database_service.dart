import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../models/diary_entry.dart';
import '../models/weight_entry.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _foodsDb;
  static Database? _userDb;
  // Guards against concurrent opens: multiple callers share one in-flight Future.
  static Completer<Database>? _foodsDbOpening;
  static Completer<Database>? _userDbOpening;
  List<String>? _vocabulary;

  DatabaseService._();
  static DatabaseService get instance => _instance ??= DatabaseService._();

  // Closes open connections, clears cached state, and deletes DB files.
  // For use in tests only — gives each test a clean slate.
  Future<void> closeForTesting() async {
    // Wait for any in-progress opens before closing so nothing is left orphaned.
    await _userDbOpening?.future.then((_) {}, onError: (_) {});
    await _foodsDbOpening?.future.then((_) {}, onError: (_) {});
    await _foodsDb?.close();
    await _userDb?.close();
    _foodsDb = null;
    _userDb = null;
    _foodsDbOpening = null;
    _userDbOpening = null;
    _vocabulary = null;
    final dir = await getDatabasesPath();
    for (final name in ['calora_user.db', 'calora_foods.db']) {
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File(join(dir, '$name$suffix'));
        if (f.existsSync()) f.deleteSync();
      }
    }
  }

  // ── DB version constants ──────────────────────────────────────────────────

  // Bump this + PRAGMA user_version in build_db.py whenever food data changes.
  static const _kFoodsVersion = 4;

  // ── Connection accessors ──────────────────────────────────────────────────

  Future<Database> get foodsDb async {
    if (_foodsDb != null) return _foodsDb!;
    if (_foodsDbOpening != null) return _foodsDbOpening!.future;
    final c = _foodsDbOpening = Completer<Database>();
    _openFoodsDb()
        .then((db) {
          _foodsDb = db;
          c.complete(db);
        }, onError: c.completeError)
        .whenComplete(() {
          _foodsDbOpening = null;
        });
    return c.future;
  }

  Future<Database> get userDb async {
    if (_userDb != null) return _userDb!;
    if (_userDbOpening != null) return _userDbOpening!.future;
    final c = _userDbOpening = Completer<Database>();
    _openUserDb()
        .then((db) {
          _userDb = db;
          c.complete(db);
        }, onError: c.completeError)
        .whenComplete(() {
          _userDbOpening = null;
        });
    return c.future;
  }

  // ── Foods DB (seed-backed, safe to wipe) ─────────────────────────────────

  Future<Database> _openFoodsDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'calora_foods.db');
    if (!File(path).existsSync() ||
        await _readUserVersion(path) < _kFoodsVersion) {
      await _copySeed(path);
    }
    return openDatabase(path, version: _kFoodsVersion);
  }

  Future<void> _copySeed(String path) async {
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('$path$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    final bytes = await rootBundle.load('assets/calora_seed.db');
    await File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }

  // ── User DB (never wiped, holds diary + recipes + food cache) ─────────────

  static const _kUserVersion = 5;

  Future<Database> _openUserDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'calora_user.db');
    final db = await openDatabase(
      path,
      version: _kUserVersion,
      onCreate: _createUserSchema,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createGoalHistoryTable(db);
        if (oldV < 3) {
          await db.execute(
            'ALTER TABLE recipes ADD COLUMN servings INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldV < 4) await _createWeightLogTable(db);
        if (oldV < 5) await _createLastUsedGramsTable(db);
      },
    );
    await _createGoalHistoryTable(db);
    await _ensureRecipesServingsColumn(db);
    await _createWeightLogTable(db);
    await _createLastUsedGramsTable(db);
    return db;
  }

  Future<void> _ensureRecipesServingsColumn(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(recipes)');
    if (!cols.any((c) => c['name'] == 'servings')) {
      await db.execute(
        'ALTER TABLE recipes ADD COLUMN servings INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _createGoalHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_history (
        date     TEXT PRIMARY KEY,
        calories INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createWeightLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_log (
        id   TEXT PRIMARY KEY,
        date TEXT UNIQUE NOT NULL,
        kg   REAL NOT NULL
      )
    ''');
  }

  Future<void> _createLastUsedGramsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS last_used_grams (
        food_id TEXT PRIMARY KEY,
        grams   REAL NOT NULL
      )
    ''');
  }

  Future<void> saveLastUsedGrams(String foodId, double grams) async {
    try {
      await (await userDb).insert('last_used_grams', {
        'food_id': foodId,
        'grams': grams,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('saveLastUsedGrams error: $e');
    }
  }

  Future<double?> getLastUsedGrams(String foodId) async {
    try {
      final rows = await (await userDb).query(
        'last_used_grams',
        columns: ['grams'],
        where: 'food_id = ?',
        whereArgs: [foodId],
      );
      return rows.isEmpty ? null : (rows.first['grams'] as num).toDouble();
    } catch (e) {
      debugPrint('getLastUsedGrams error: $e');
      return null;
    }
  }

  Future<void> updateDiaryEntryGrams(String id, double grams) async {
    try {
      await (await userDb).update(
        'diary_entries',
        {'grams': grams},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('updateDiaryEntryGrams error: $e');
      rethrow;
    }
  }

  Future<void> _createUserSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods (
        id                     TEXT PRIMARY KEY,
        name                   TEXT NOT NULL,
        brand                  TEXT,
        barcode                TEXT,
        calories_per_100g      REAL NOT NULL,
        fat_per_100g           REAL DEFAULT 0,
        saturated_fat_per_100g REAL DEFAULT 0,
        carbs_per_100g         REAL DEFAULT 0,
        sugars_per_100g        REAL DEFAULT 0,
        fiber_per_100g         REAL DEFAULT 0,
        protein_per_100g       REAL DEFAULT 0,
        sodium_per_100g        REAL DEFAULT 0,
        serving_size           TEXT,
        serving_grams          REAL,
        image_url              TEXT,
        source                 TEXT DEFAULT 'custom'
      )
    ''');
    await db.execute('''
      CREATE TABLE diary_entries (
        id      TEXT PRIMARY KEY,
        food_id TEXT NOT NULL,
        grams   REAL NOT NULL,
        date    TEXT NOT NULL,
        meal    TEXT NOT NULL,
        FOREIGN KEY (food_id) REFERENCES foods (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE recipes (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        description TEXT,
        servings    INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE recipe_items (
        id        TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        food_id   TEXT NOT NULL,
        grams     REAL NOT NULL,
        FOREIGN KEY (recipe_id) REFERENCES recipes (id),
        FOREIGN KEY (food_id)   REFERENCES foods (id)
      )
    ''');
    await db.execute('CREATE INDEX idx_diary_date    ON diary_entries (date)');
    await db.execute('CREATE INDEX idx_foods_barcode ON foods (barcode)');
    await _createGoalHistoryTable(db);
    await _createWeightLogTable(db);
    await _createLastUsedGramsTable(db);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<int> _readUserVersion(String path) async {
    try {
      final bytes = await File(path)
          .openRead(60, 64)
          .fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
      if (bytes.length < 4) return 0;
      return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    } catch (_) {
      return 0;
    }
  }

  // ── Food lookup ───────────────────────────────────────────────────────────

  Future<void> saveFood(FoodItem food) async {
    try {
      final d = await userDb;
      await d.insert(
        'foods',
        food.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('saveFood error: $e');
      rethrow;
    }
  }

  Future<FoodItem?> getFoodById(String id) async {
    try {
      final u = await userDb;
      final uRows = await u.query('foods', where: 'id = ?', whereArgs: [id]);
      if (uRows.isNotEmpty) return FoodItem.fromMap(uRows.first);
      final f = await foodsDb;
      final fRows = await f.query('foods', where: 'id = ?', whereArgs: [id]);
      return fRows.isEmpty ? null : FoodItem.fromMap(fRows.first);
    } catch (e) {
      debugPrint('getFoodById error: $e');
      return null;
    }
  }

  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    try {
      final u = await userDb;
      final uRows = await u.query(
        'foods',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      if (uRows.isNotEmpty) return FoodItem.fromMap(uRows.first);
      final f = await foodsDb;
      final fRows = await f.query(
        'foods',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      return fRows.isEmpty ? null : FoodItem.fromMap(fRows.first);
    } catch (e) {
      debugPrint('getFoodByBarcode error: $e');
      return null;
    }
  }

  // ── Search (bundled foods DB + user DB) ──────────────────────────────────

  Future<List<FoodItem>> searchFoods(String query) async {
    try {
      final d = await foodsDb;
      final term = query.trim().toLowerCase();
      final words = term
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();

      if (words.isEmpty) return [];

      // Search bundled foods DB via FTS → spell-correction → LIKE fallback.
      List<FoodItem> mainResults = await _ftsSearch(d, words);

      if (mainResults.isEmpty) {
        final vocab = await _loadVocabulary(d);
        final corrected = words.map((w) => _closestWord(w, vocab)).toList();
        if (corrected.join(' ') != words.join(' ')) {
          mainResults = await _ftsSearch(d, corrected);
        }
      }

      if (mainResults.isEmpty) {
        mainResults = await _likeSearch(d, words, limit: 60);
      }

      // Also search user DB so barcode-scanned and custom foods are findable.
      final userResults = await _searchUserFoods(words);
      final seen = mainResults.map((f) => f.id).toSet();
      final merged = [
        ...mainResults,
        ...userResults.where((f) => !seen.contains(f.id)),
      ];

      return _rankByRelevance(merged, term, words);
    } catch (e) {
      debugPrint('searchFoods error: $e');
      return [];
    }
  }

  // Each word must appear in EITHER name or brand — cross-field AND matching.
  Future<List<FoodItem>> _likeSearch(
    Database d,
    List<String> words, {
    int limit = 60,
  }) async {
    final clause = words
        .map((_) => '(LOWER(name) LIKE ? OR LOWER(brand) LIKE ?)')
        .join(' AND ');
    final args = words.expand((w) => ['%$w%', '%$w%']).toList();
    final rows = await d.rawQuery(
      'SELECT * FROM foods WHERE $clause LIMIT $limit',
      args,
    );
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<List<FoodItem>> _searchUserFoods(List<String> words) async {
    try {
      final u = await userDb;
      return _likeSearch(u, words, limit: 20);
    } catch (e) {
      debugPrint('_searchUserFoods error: $e');
      return [];
    }
  }

  /// Returns all foods from the most recent logged instance of [meal] on a
  /// date strictly before [date]. Used to show a "Previous Breakfast / …"
  /// strip without echoing back what's already in today's diary.
  Future<List<FoodItem>> getLastMealFoods({
    required Meal meal,
    required DateTime date,
  }) async {
    try {
      final d = await userDb;
      final dateStr = date.toIso8601String().substring(0, 10);
      final rows = await d.rawQuery(
        '''
        SELECT f.* FROM diary_entries e
        JOIN foods f ON f.id = e.food_id
        WHERE e.meal = ? AND e.date = (
          SELECT MAX(date) FROM diary_entries WHERE meal = ? AND date < ?
        )
        GROUP BY f.id
        ORDER BY MIN(e.rowid)
      ''',
        [meal.name, meal.name, dateStr],
      );
      return rows.map((r) => FoodItem.fromMap(r)).toList();
    } catch (e) {
      debugPrint('getLastMealFoods error: $e');
      return [];
    }
  }

  /// Returns recent foods from diary, prioritising [previousMeal] on [date].
  /// Used to populate suggestions when the search query is empty.
  Future<List<FoodItem>> getRecentFoods({
    required Meal previousMeal,
    required DateTime date,
    int limit = 20,
  }) async {
    try {
      final d = await userDb;
      final dateStr = date.toIso8601String().substring(0, 10);
      final cutoff = date
          .subtract(const Duration(days: 30))
          .toIso8601String()
          .substring(0, 10);

      // Pull distinct foods from last 30 days; prioritise previous meal on date.
      final rows = await d.rawQuery(
        '''
        SELECT f.*,
          MAX(e.date) AS last_date,
          MAX(CASE WHEN e.date = ? AND e.meal = ? THEN 1 ELSE 0 END) AS is_prev_meal
        FROM diary_entries e
        JOIN foods f ON f.id = e.food_id
        WHERE e.date BETWEEN ? AND ?
        GROUP BY f.id
        ORDER BY is_prev_meal DESC, last_date DESC
        LIMIT ?
      ''',
        [dateStr, previousMeal.name, cutoff, dateStr, limit],
      );

      return rows.map((r) => FoodItem.fromMap(r)).toList();
    } catch (e) {
      debugPrint('getRecentFoods error: $e');
      return [];
    }
  }

  List<FoodItem> _rankByRelevance(
    List<FoodItem> items,
    String term,
    List<String> words,
  ) {
    int score(FoodItem item) {
      final n = item.name.toLowerCase();
      if (n == term) return 0;
      if (n.startsWith(term)) return 1;
      if (n.contains(term)) return 2;
      final posSum = words.fold(0, (s, w) {
        final i = n.indexOf(w);
        return s + (i < 0 ? 500 : i);
      });
      return 3 + posSum + n.length;
    }

    final sorted = [...items]..sort((a, b) => score(a).compareTo(score(b)));
    return sorted.take(30).toList();
  }

  Future<List<FoodItem>> _ftsSearch(Database d, List<String> words) async {
    final ftsQuery = words.map((w) => '$w*').join(' ');
    try {
      final rows = await d.rawQuery(
        '''
        SELECT f.* FROM foods_fts
        JOIN foods f ON f.rowid = foods_fts.rowid
        WHERE foods_fts MATCH ?
        ORDER BY rank
        LIMIT 30
      ''',
        [ftsQuery],
      );
      return rows.map(FoodItem.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _loadVocabulary(Database d) async {
    _vocabulary ??= (await d.query(
      'vocabulary',
      columns: ['word'],
    )).map((r) => r['word'] as String).toList();
    return _vocabulary!;
  }

  String _closestWord(String word, List<String> vocab) {
    if (word.length < 4) return word;
    final threshold = word.length <= 5 ? 1 : 2;
    String best = word;
    int bestDist = threshold + 1;
    for (final v in vocab) {
      if ((v.length - word.length).abs() > threshold) continue;
      final d = _levenshtein(word, v);
      if (d < bestDist) {
        bestDist = d;
        best = v;
        if (d == 1) break;
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        curr[j + 1] = a[i] == b[j]
            ? prev[j]
            : 1 + min(prev[j], min(prev[j + 1], curr[j]));
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  // ── Goal history ──────────────────────────────────────────────────────────

  Future<void> saveGoal(DateTime date, int calories) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final db = await userDb;
    try {
      await db.insert('goal_history', {
        'date': dateStr,
        'calories': calories,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('saveGoal error: $e');
      await _createGoalHistoryTable(db);
      await db.insert('goal_history', {
        'date': dateStr,
        'calories': calories,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<int?> getEffectiveGoal(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final db = await userDb;
    try {
      final rows = await db.rawQuery(
        '''
        SELECT calories FROM goal_history
        WHERE date <= ? ORDER BY date DESC LIMIT 1
      ''',
        [dateStr],
      );
      return rows.isEmpty ? null : rows.first['calories'] as int;
    } catch (e) {
      debugPrint('getEffectiveGoal error: $e');
      await _createGoalHistoryTable(db);
      return null;
    }
  }

  Future<Map<String, int>> getDailyGoals(
    DateTime from,
    DateTime to,
    int fallback,
  ) async {
    final toStr = to.toIso8601String().substring(0, 10);
    final db = await userDb;
    List<Map<String, Object?>> changes;
    try {
      changes = await db.rawQuery(
        '''
        SELECT date, calories FROM goal_history
        WHERE date <= ? ORDER BY date ASC
      ''',
        [toStr],
      );
    } catch (e) {
      debugPrint('getDailyGoals error: $e');
      await _createGoalHistoryTable(db);
      changes = [];
    }

    final result = <String, int>{};
    final dayCount = to.difference(from).inDays + 1;
    for (var i = 0; i < dayCount; i++) {
      final date = from.add(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      var goal = fallback;
      for (final row in changes) {
        if ((row['date'] as String).compareTo(dateStr) <= 0) {
          goal = row['calories'] as int;
        } else {
          break;
        }
      }
      result[dateStr] = goal;
    }
    return result;
  }

  // ── Weight log ────────────────────────────────────────────────────────────

  Future<void> saveWeight(DateTime date, double kg) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final db = await userDb;
      await db.insert('weight_log', {
        'id': const Uuid().v4(),
        'date': dateStr,
        'kg': kg,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('saveWeight error: $e');
      rethrow;
    }
  }

  Future<List<WeightEntry>> getWeightHistory({int days = 90}) async {
    try {
      final db = await userDb;
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String()
          .substring(0, 10);
      final rows = await db.rawQuery(
        'SELECT * FROM weight_log WHERE date >= ? ORDER BY date ASC',
        [cutoff],
      );
      return rows.map(WeightEntry.fromMap).toList();
    } catch (e) {
      debugPrint('getWeightHistory error: $e');
      return [];
    }
  }

  Future<WeightEntry?> getLatestWeight() async {
    try {
      final db = await userDb;
      final rows = await db.rawQuery(
        'SELECT * FROM weight_log ORDER BY date DESC LIMIT 1',
      );
      return rows.isEmpty ? null : WeightEntry.fromMap(rows.first);
    } catch (e) {
      debugPrint('getLatestWeight error: $e');
      return null;
    }
  }

  Future<void> deleteWeight(String id) async {
    try {
      await (await userDb).delete(
        'weight_log',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('deleteWeight error: $e');
      rethrow;
    }
  }

  // ── Recipes (as virtual FoodItems) ────────────────────────────────────────

  Future<List<FoodItem>> getRecipesAsFood([String query = '']) async {
    try {
      final d = await userDb;
      final term = query.trim().isEmpty
          ? '%'
          : '%${query.trim().toLowerCase()}%';
      final rows = await d.rawQuery(
        '''
        SELECT r.id, r.name, r.servings,
          COALESCE(SUM(ri.grams), 0)                                AS total_grams,
          COALESCE(SUM(ri.grams * f.calories_per_100g / 100.0), 0) AS cal,
          COALESCE(SUM(ri.grams * f.protein_per_100g  / 100.0), 0) AS protein,
          COALESCE(SUM(ri.grams * f.fat_per_100g      / 100.0), 0) AS fat,
          COALESCE(SUM(ri.grams * f.carbs_per_100g    / 100.0), 0) AS carbs
        FROM recipes r
        LEFT JOIN recipe_items ri ON ri.recipe_id = r.id
        LEFT JOIN foods         f  ON f.id = ri.food_id
        WHERE LOWER(r.name) LIKE ?
        GROUP BY r.id
        ORDER BY r.name
      ''',
        [term],
      );

      return rows.map((row) {
        final totalGrams = (row['total_grams'] as num).toDouble();
        final servings = (row['servings'] as num?)?.toInt() ?? 1;
        final factor = totalGrams > 0 ? 100.0 / totalGrams : 0.0;
        final servingGrams = totalGrams > 0 ? totalGrams / servings : null;
        return FoodItem(
          id: 'recipe_${row['id']}',
          name: row['name'] as String,
          caloriesPer100g: (row['cal'] as num).toDouble() * factor,
          proteinPer100g: (row['protein'] as num).toDouble() * factor,
          fatPer100g: (row['fat'] as num).toDouble() * factor,
          carbsPer100g: (row['carbs'] as num).toDouble() * factor,
          servingGrams: servingGrams,
          source: 'custom',
        );
      }).toList();
    } catch (e) {
      debugPrint('getRecipesAsFood error: $e');
      return [];
    }
  }

  Future<FoodItem?> getRecipeAsFood(String recipeId) async {
    try {
      final d = await userDb;
      final rows = await d.rawQuery(
        '''
        SELECT r.id, r.name, r.servings,
          COALESCE(SUM(ri.grams), 0)                                AS total_grams,
          COALESCE(SUM(ri.grams * f.calories_per_100g / 100.0), 0) AS cal,
          COALESCE(SUM(ri.grams * f.protein_per_100g  / 100.0), 0) AS protein,
          COALESCE(SUM(ri.grams * f.fat_per_100g      / 100.0), 0) AS fat,
          COALESCE(SUM(ri.grams * f.carbs_per_100g    / 100.0), 0) AS carbs
        FROM recipes r
        LEFT JOIN recipe_items ri ON ri.recipe_id = r.id
        LEFT JOIN foods         f  ON f.id = ri.food_id
        WHERE r.id = ?
        GROUP BY r.id
      ''',
        [recipeId],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final totalGrams = (row['total_grams'] as num).toDouble();
      final servings = (row['servings'] as num?)?.toInt() ?? 1;
      final factor = totalGrams > 0 ? 100.0 / totalGrams : 0.0;
      return FoodItem(
        id: 'recipe_$recipeId',
        name: row['name'] as String,
        caloriesPer100g: (row['cal'] as num).toDouble() * factor,
        proteinPer100g: (row['protein'] as num).toDouble() * factor,
        fatPer100g: (row['fat'] as num).toDouble() * factor,
        carbsPer100g: (row['carbs'] as num).toDouble() * factor,
        servingGrams: totalGrams > 0 ? totalGrams / servings : null,
        source: 'custom',
      );
    } catch (e) {
      debugPrint('getRecipeAsFood error: $e');
      return null;
    }
  }

  // ── Diary ─────────────────────────────────────────────────────────────────

  Future<void> addDiaryEntry(DiaryEntry entry) async {
    try {
      final d = await userDb;
      await saveFood(entry.food);
      await d.insert(
        'diary_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('addDiaryEntry error: $e');
      rethrow;
    }
  }

  Future<void> deleteDiaryEntry(String id) async {
    try {
      final d = await userDb;
      await d.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('deleteDiaryEntry error: $e');
      rethrow;
    }
  }

  Future<void> updateEntryMeal(String id, Meal newMeal) async {
    try {
      await (await userDb).update(
        'diary_entries',
        {'meal': newMeal.name},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('updateEntryMeal error: $e');
      rethrow;
    }
  }

  Future<Map<String, Map<String, double>>> getDailyMacros(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final d = await userDb;
      final rows = await d.rawQuery(
        '''
        SELECT e.date,
          SUM(e.grams * f.protein_per_100g / 100.0) AS protein,
          SUM(e.grams * f.fat_per_100g / 100.0)     AS fat,
          SUM(e.grams * f.carbs_per_100g / 100.0)   AS carbs
        FROM diary_entries e
        JOIN foods f ON f.id = e.food_id
        WHERE e.date BETWEEN ? AND ?
        GROUP BY e.date
        ORDER BY e.date
      ''',
        [
          from.toIso8601String().substring(0, 10),
          to.toIso8601String().substring(0, 10),
        ],
      );
      return {
        for (final r in rows)
          r['date'] as String: {
            'protein': (r['protein'] as num?)?.toDouble() ?? 0,
            'fat': (r['fat'] as num?)?.toDouble() ?? 0,
            'carbs': (r['carbs'] as num?)?.toDouble() ?? 0,
          },
      };
    } catch (e) {
      debugPrint('getDailyMacros error: $e');
      return {};
    }
  }

  Future<Map<String, double>> getDailyCalories(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final d = await userDb;
      final rows = await d.rawQuery(
        '''
        SELECT e.date, SUM(e.grams * f.calories_per_100g / 100.0) AS calories
        FROM diary_entries e
        JOIN foods f ON f.id = e.food_id
        WHERE e.date BETWEEN ? AND ?
        GROUP BY e.date
        ORDER BY e.date
      ''',
        [
          from.toIso8601String().substring(0, 10),
          to.toIso8601String().substring(0, 10),
        ],
      );
      return {
        for (final r in rows)
          r['date'] as String: (r['calories'] as num).toDouble(),
      };
    } catch (e) {
      debugPrint('getDailyCalories error: $e');
      return {};
    }
  }

  Future<List<DiaryEntry>> getEntriesForDate(DateTime date) async {
    try {
      final d = await userDb;
      final dateStr = date.toIso8601String().substring(0, 10);
      final rows = await d.query(
        'diary_entries',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      final entries = <DiaryEntry>[];
      for (final row in rows) {
        final food = await getFoodById(row['food_id'] as String);
        if (food != null) entries.add(DiaryEntry.fromMap(row, food));
      }
      return entries;
    } catch (e) {
      debugPrint('getEntriesForDate error: $e');
      return [];
    }
  }

  // ── Recipes ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      return (await userDb).rawQuery('''
        SELECT r.id, r.name, r.description, r.servings,
          COALESCE(SUM(ri.grams * f.calories_per_100g / 100.0), 0) AS total_kcal
        FROM recipes r
        LEFT JOIN recipe_items ri ON ri.recipe_id = r.id
        LEFT JOIN foods         f  ON f.id = ri.food_id
        GROUP BY r.id
        ORDER BY r.name
      ''');
    } catch (e) {
      debugPrint('getRecipes error: $e');
      return [];
    }
  }

  Future<void> updateRecipeServings(String id, int servings) async {
    try {
      await (await userDb).update(
        'recipes',
        {'servings': servings},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('updateRecipeServings error: $e');
      rethrow;
    }
  }

  Future<String> saveRecipe(String name, String? description) async {
    try {
      final id = const Uuid().v4();
      await (await userDb).insert('recipes', {
        'id': id,
        'name': name,
        'description': description,
        'servings': 1,
      });
      return id;
    } catch (e) {
      debugPrint('saveRecipe error: $e');
      rethrow;
    }
  }

  /// Creates a recipe and all its items atomically in a single transaction.
  Future<String> saveRecipeWithItems(
    String name,
    String? description,
    List<({String foodId, double grams})> items,
  ) async {
    try {
      final id = const Uuid().v4();
      final db = await userDb;
      await db.transaction((txn) async {
        await txn.insert('recipes', {
          'id': id,
          'name': name,
          'description': description,
          'servings': 1,
        });
        for (final item in items) {
          await txn.insert('recipe_items', {
            'id': const Uuid().v4(),
            'recipe_id': id,
            'food_id': item.foodId,
            'grams': item.grams,
          });
        }
      });
      return id;
    } catch (e) {
      debugPrint('saveRecipeWithItems error: $e');
      rethrow;
    }
  }

  Future<void> renameRecipe(String id, String name) async {
    try {
      await (await userDb).update(
        'recipes',
        {'name': name},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('renameRecipe error: $e');
      rethrow;
    }
  }

  Future<void> deleteRecipe(String id) async {
    try {
      final d = await userDb;
      await d.transaction((txn) async {
        await txn.delete(
          'recipe_items',
          where: 'recipe_id = ?',
          whereArgs: [id],
        );
        await txn.delete('recipes', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      debugPrint('deleteRecipe error: $e');
      rethrow;
    }
  }

  Future<void> addRecipeItem(
    String recipeId,
    String foodId,
    double grams,
  ) async {
    try {
      await (await userDb).insert('recipe_items', {
        'id': const Uuid().v4(),
        'recipe_id': recipeId,
        'food_id': foodId,
        'grams': grams,
      });
    } catch (e) {
      debugPrint('addRecipeItem error: $e');
      rethrow;
    }
  }

  Future<void> updateRecipeItemGrams(String id, double grams) async {
    try {
      await (await userDb).update(
        'recipe_items',
        {'grams': grams},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('updateRecipeItemGrams error: $e');
      rethrow;
    }
  }

  Future<void> deleteRecipeItem(String id) async {
    try {
      await (await userDb).delete(
        'recipe_items',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('deleteRecipeItem error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRecipeItems(String recipeId) async {
    try {
      return (await userDb).rawQuery(
        '''
        SELECT ri.id, ri.food_id, ri.grams, f.name, f.calories_per_100g,
               f.protein_per_100g, f.fat_per_100g, f.carbs_per_100g, f.source
        FROM recipe_items ri
        JOIN foods f ON f.id = ri.food_id
        WHERE ri.recipe_id = ?
        ORDER BY f.name
      ''',
        [recipeId],
      );
    } catch (e) {
      debugPrint('getRecipeItems error: $e');
      return [];
    }
  }

  // ── Export / Import ───────────────────────────────────────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> exportUserTables() async {
    final d = await userDb;
    return {
      'foods': await d.query('foods'),
      'diary_entries': await d.query('diary_entries'),
      'recipes': await d.query('recipes'),
      'recipe_items': await d.query('recipe_items'),
      'goal_history': await d.query('goal_history'),
      'weight_log': await d.query('weight_log'),
      'last_used_grams': await d.query('last_used_grams'),
    };
  }

  Future<void> importUserTables(Map<String, dynamic> tables) async {
    final d = await userDb;
    await d.transaction((txn) async {
      // Delete in FK-safe order
      for (final t in [
        'last_used_grams',
        'diary_entries',
        'recipe_items',
        'recipes',
        'foods',
        'goal_history',
        'weight_log',
      ]) {
        await txn.delete(t);
      }
      // Insert in FK-safe order
      for (final t in [
        'foods',
        'recipes',
        'recipe_items',
        'diary_entries',
        'goal_history',
        'weight_log',
        'last_used_grams',
      ]) {
        for (final row in (tables[t] as List? ?? [])) {
          await txn.insert(
            t,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
