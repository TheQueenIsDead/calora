import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/food_item.dart';
import '../models/diary_entry.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _foodsDb;
  static Database? _userDb;
  List<String>? _vocabulary;

  DatabaseService._();
  static DatabaseService get instance => _instance ??= DatabaseService._();

  // ── DB version constants ──────────────────────────────────────────────────

  // Bump this + PRAGMA user_version in build_db.py whenever food data changes.
  static const _kFoodsVersion = 2;

  // ── Connection accessors ──────────────────────────────────────────────────

  Future<Database> get foodsDb async {
    _foodsDb ??= await _openFoodsDb();
    return _foodsDb!;
  }

  Future<Database> get userDb async {
    _userDb ??= await _openUserDb();
    return _userDb!;
  }

  // ── Foods DB (seed-backed, safe to wipe) ─────────────────────────────────

  Future<Database> _openFoodsDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'calora_foods.db');
    if (!File(path).existsSync() || await _readUserVersion(path) < _kFoodsVersion) {
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

  static const _kUserVersion = 3;

  Future<Database> _openUserDb() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'calora_user.db');
    return openDatabase(
      path,
      version: _kUserVersion,
      onCreate: _createUserSchema,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createGoalHistoryTable(db);
        if (oldV < 3) {
          await db.execute(
              'ALTER TABLE recipes ADD COLUMN servings INTEGER NOT NULL DEFAULT 1');
        }
      },
      onOpen: (db) async {
        // Idempotent guard: ensures goal_history exists even on devices
        // whose DB was already at version 2 before the table was added.
        await _createGoalHistoryTable(db);
      },
    );
  }

  Future<void> _createGoalHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_history (
        date     TEXT PRIMARY KEY,
        calories INTEGER NOT NULL
      )
    ''');
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
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Read user_version from bytes 60-63 of SQLite file header (big-endian int32).
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
    final d = await userDb;
    await d.insert('foods', food.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<FoodItem?> getFoodById(String id) async {
    // Prefer user DB (cached/custom foods); fall back to foods DB.
    final u = await userDb;
    final uRows = await u.query('foods', where: 'id = ?', whereArgs: [id]);
    if (uRows.isNotEmpty) return FoodItem.fromMap(uRows.first);

    final f = await foodsDb;
    final fRows = await f.query('foods', where: 'id = ?', whereArgs: [id]);
    return fRows.isEmpty ? null : FoodItem.fromMap(fRows.first);
  }

  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    final u = await userDb;
    final uRows = await u.query('foods', where: 'barcode = ?', whereArgs: [barcode]);
    if (uRows.isNotEmpty) return FoodItem.fromMap(uRows.first);

    final f = await foodsDb;
    final fRows = await f.query('foods', where: 'barcode = ?', whereArgs: [barcode]);
    return fRows.isEmpty ? null : FoodItem.fromMap(fRows.first);
  }

  // ── Search (always against foods DB) ─────────────────────────────────────

  Future<List<FoodItem>> searchFoods(String query) async {
    final d = await foodsDb;
    final term = query.trim().toLowerCase();
    final words = term
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return [];

    final ftsResults = await _ftsSearch(d, words);
    if (ftsResults.isNotEmpty) return _rankByRelevance(ftsResults, term, words);

    final vocab = await _loadVocabulary(d);
    final corrected = words.map((w) => _closestWord(w, vocab)).toList();
    if (corrected.join(' ') != words.join(' ')) {
      final correctedResults = await _ftsSearch(d, corrected);
      if (correctedResults.isNotEmpty) return _rankByRelevance(correctedResults, term, words);
    }

    final wordClauses = words.map((_) => "LOWER(name) LIKE ?").join(' AND ');
    final brandClauses = words.map((_) => "LOWER(brand) LIKE ?").join(' AND ');
    final wordArgs = words.map((w) => '%$w%').toList();
    final likeRows = await d.rawQuery('''
      SELECT * FROM foods
      WHERE ($wordClauses) OR ($brandClauses)
      LIMIT 60
    ''', [...wordArgs, ...wordArgs]);
    final likeResults = likeRows.map(FoodItem.fromMap).toList();
    return _rankByRelevance(likeResults, term, words);
  }

  /// Sorts [items] so the closest match to [term]/[words] comes first.
  /// Scoring (lower = better):
  ///   0   exact name match
  ///   1   name starts with full term
  ///   2   name contains full term as substring
  ///   3+  all words present but scattered — penalised by sum of word positions + name length
  List<FoodItem> _rankByRelevance(
      List<FoodItem> items, String term, List<String> words) {
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
      final rows = await d.rawQuery('''
        SELECT f.* FROM foods_fts
        JOIN foods f ON f.rowid = foods_fts.rowid
        WHERE foods_fts MATCH ?
        ORDER BY CASE WHEN f.source IN ('ausnut','nz','usda') THEN 0 ELSE 1 END, rank
        LIMIT 30
      ''', [ftsQuery]);
      return rows.map(FoodItem.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _loadVocabulary(Database d) async {
    _vocabulary ??= (await d.query('vocabulary', columns: ['word']))
        .map((r) => r['word'] as String)
        .toList();
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
      final tmp = prev; prev = curr; curr = tmp;
    }
    return prev[b.length];
  }

  // ── Goal history ──────────────────────────────────────────────────────────

  Future<void> saveGoal(DateTime date, int calories) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final db = await userDb;
    try {
      await db.insert(
        'goal_history',
        {'date': dateStr, 'calories': calories},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      await _createGoalHistoryTable(db);
      await db.insert(
        'goal_history',
        {'date': dateStr, 'calories': calories},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Returns the effective calorie goal on [date], or null if no history exists.
  Future<int?> getEffectiveGoal(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final db = await userDb;
    try {
      final rows = await db.rawQuery('''
        SELECT calories FROM goal_history
        WHERE date <= ? ORDER BY date DESC LIMIT 1
      ''', [dateStr]);
      return rows.isEmpty ? null : rows.first['calories'] as int;
    } catch (_) {
      await _createGoalHistoryTable(db);
      return null;
    }
  }

  /// Returns a map of date-string → effective goal for every day in [from]..[to].
  /// Falls back to [fallback] for days before any goal was recorded.
  Future<Map<String, int>> getDailyGoals(
      DateTime from, DateTime to, int fallback) async {
    final toStr = to.toIso8601String().substring(0, 10);
    final db = await userDb;
    List<Map<String, Object?>> changes;
    try {
      changes = await db.rawQuery('''
        SELECT date, calories FROM goal_history
        WHERE date <= ? ORDER BY date ASC
      ''', [toStr]);
    } catch (_) {
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

  /// Returns all recipes (or those matching [query]) as virtual FoodItems with
  /// per-100g nutrition derived from their ingredients. Pass an empty string to
  /// return all recipes (used to populate the list before the user types).
  Future<List<FoodItem>> getRecipesAsFood([String query = '']) async {
    final d = await userDb;
    final term = query.trim().isEmpty ? '%' : '%${query.trim().toLowerCase()}%';
    final rows = await d.rawQuery('''
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
    ''', [term]);

    return rows.map((row) {
      final totalGrams = (row['total_grams'] as num).toDouble();
      final servings = (row['servings'] as num?)?.toInt() ?? 1;
      final factor = totalGrams > 0 ? 100.0 / totalGrams : 0.0;
      final servingGrams = totalGrams > 0 ? totalGrams / servings : null;
      return FoodItem(
        id: 'recipe_${row['id']}',
        name: row['name'] as String,
        caloriesPer100g: (row['cal']     as num).toDouble() * factor,
        proteinPer100g:  (row['protein'] as num).toDouble() * factor,
        fatPer100g:      (row['fat']     as num).toDouble() * factor,
        carbsPer100g:    (row['carbs']   as num).toDouble() * factor,
        servingGrams:    servingGrams,
        source: 'custom',
      );
    }).toList();
  }

  Future<FoodItem?> getRecipeAsFood(String recipeId) async {
    final d = await userDb;
    final rows = await d.rawQuery('''
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
    ''', [recipeId]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final totalGrams = (row['total_grams'] as num).toDouble();
    final servings = (row['servings'] as num?)?.toInt() ?? 1;
    final factor = totalGrams > 0 ? 100.0 / totalGrams : 0.0;
    return FoodItem(
      id: 'recipe_$recipeId',
      name: row['name'] as String,
      caloriesPer100g: (row['cal']     as num).toDouble() * factor,
      proteinPer100g:  (row['protein'] as num).toDouble() * factor,
      fatPer100g:      (row['fat']     as num).toDouble() * factor,
      carbsPer100g:    (row['carbs']   as num).toDouble() * factor,
      servingGrams:    totalGrams > 0 ? totalGrams / servings : null,
      source: 'custom',
    );
  }

  // ── Diary ─────────────────────────────────────────────────────────────────

  Future<void> addDiaryEntry(DiaryEntry entry) async {
    final d = await userDb;
    await saveFood(entry.food); // snapshot food into user DB
    await d.insert('diary_entries', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDiaryEntry(String id) async {
    final d = await userDb;
    await d.delete('diary_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateEntryMeal(String id, Meal newMeal) async {
    await (await userDb).update(
      'diary_entries',
      {'meal': newMeal.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, Map<String, double>>> getDailyMacros(
      DateTime from, DateTime to) async {
    final d = await userDb;
    final rows = await d.rawQuery('''
      SELECT e.date,
        SUM(e.grams * f.protein_per_100g / 100.0) AS protein,
        SUM(e.grams * f.fat_per_100g / 100.0)     AS fat,
        SUM(e.grams * f.carbs_per_100g / 100.0)   AS carbs
      FROM diary_entries e
      JOIN foods f ON f.id = e.food_id
      WHERE e.date BETWEEN ? AND ?
      GROUP BY e.date
      ORDER BY e.date
    ''', [
      from.toIso8601String().substring(0, 10),
      to.toIso8601String().substring(0, 10),
    ]);
    return {
      for (final r in rows)
        r['date'] as String: {
          'protein': (r['protein'] as num?)?.toDouble() ?? 0,
          'fat': (r['fat'] as num?)?.toDouble() ?? 0,
          'carbs': (r['carbs'] as num?)?.toDouble() ?? 0,
        }
    };
  }

  Future<Map<String, double>> getDailyCalories(DateTime from, DateTime to) async {
    final d = await userDb;
    final rows = await d.rawQuery('''
      SELECT e.date, SUM(e.grams * f.calories_per_100g / 100.0) AS calories
      FROM diary_entries e
      JOIN foods f ON f.id = e.food_id
      WHERE e.date BETWEEN ? AND ?
      GROUP BY e.date
      ORDER BY e.date
    ''', [
      from.toIso8601String().substring(0, 10),
      to.toIso8601String().substring(0, 10),
    ]);
    return {for (final r in rows) r['date'] as String: (r['calories'] as num).toDouble()};
  }

  Future<List<DiaryEntry>> getEntriesForDate(DateTime date) async {
    final d = await userDb;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await d.query('diary_entries', where: 'date = ?', whereArgs: [dateStr]);
    final entries = <DiaryEntry>[];
    for (final row in rows) {
      final food = await getFoodById(row['food_id'] as String);
      if (food != null) entries.add(DiaryEntry.fromMap(row, food));
    }
    return entries;
  }

  // ── Recipes ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecipes() async {
    return (await userDb).rawQuery('''
      SELECT r.id, r.name, r.description, r.servings,
        COALESCE(SUM(ri.grams * f.calories_per_100g / 100.0), 0) AS total_kcal
      FROM recipes r
      LEFT JOIN recipe_items ri ON ri.recipe_id = r.id
      LEFT JOIN foods         f  ON f.id = ri.food_id
      GROUP BY r.id
      ORDER BY r.name
    ''');
  }

  Future<void> updateRecipeServings(String id, int servings) async {
    await (await userDb).update('recipes', {'servings': servings},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<String> saveRecipe(String name, String? description) async {
    final id = const Uuid().v4();
    await (await userDb).insert('recipes', {'id': id, 'name': name, 'description': description});
    return id;
  }

  Future<void> renameRecipe(String id, String name) async {
    await (await userDb).update('recipes', {'name': name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRecipe(String id) async {
    final d = await userDb;
    await d.delete('recipe_items', where: 'recipe_id = ?', whereArgs: [id]);
    await d.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addRecipeItem(String recipeId, String foodId, double grams) async {
    await (await userDb).insert('recipe_items', {
      'id': const Uuid().v4(),
      'recipe_id': recipeId,
      'food_id': foodId,
      'grams': grams,
    });
  }

  Future<void> updateRecipeItemGrams(String id, double grams) async {
    await (await userDb).update(
      'recipe_items',
      {'grams': grams},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRecipeItem(String id) async {
    await (await userDb).delete('recipe_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getRecipeItems(String recipeId) async {
    return (await userDb).rawQuery('''
      SELECT ri.id, ri.food_id, ri.grams, f.name, f.calories_per_100g,
             f.protein_per_100g, f.fat_per_100g, f.carbs_per_100g, f.source
      FROM recipe_items ri
      JOIN foods f ON f.id = ri.food_id
      WHERE ri.recipe_id = ?
      ORDER BY f.name
    ''', [recipeId]);
  }
}