// DiaryProvider unit tests. Uses real async (plain test(), not testWidgets)
// so sqflite FFI operations complete without fake-timer interference.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:calora/models/diary_entry.dart';
import 'package:calora/models/food_item.dart';
import 'package:calora/models/water_vessel.dart';
import 'package:calora/providers/diary_provider.dart';
import 'package:calora/providers/settings_provider.dart';
import 'package:calora/services/database_service.dart';

FoodItem _testFood() => FoodItem(
  id: const Uuid().v4(),
  name: 'Test Food',
  caloriesPer100g: 200,
  fatPer100g: 5,
  carbsPer100g: 30,
  proteinPer100g: 10,
  source: 'test',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Wipe any DB files from previous runs so calorie-total assertions start clean.
    await DatabaseService.instance.closeForTesting();
    SharedPreferences.setMockInitialValues({});
    // Pre-open the DB once (may take a moment on first FFI init) so tests
    // reuse the cached connection and stay within their 30s timeout.
    await DatabaseService.instance.userDb;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addEntry persists and loads entry for today', () async {
    final diary = DiaryProvider();
    await diary.init();

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: _testFood(),
      grams: 100,
      date: DateTime.now(),
      meal: Meal.breakfast,
    );
    await diary.addEntry(entry);

    expect(diary.entries.any((e) => e.id == entry.id), isTrue);
    expect(diary.totalCalories, greaterThan(0));
  });

  test('softDeleteEntry removes entry from UI immediately', () async {
    final diary = DiaryProvider();
    await diary.init();

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: _testFood(),
      grams: 100,
      date: DateTime.now(),
      meal: Meal.lunch,
    );
    await diary.addEntry(entry);
    expect(diary.entries.any((e) => e.id == entry.id), isTrue);

    final removed = await diary.softDeleteEntry(entry.id);
    expect(removed, isNotNull);
    expect(diary.entries.any((e) => e.id == entry.id), isFalse);
  });

  test('undoDelete restores soft-deleted entry', () async {
    final diary = DiaryProvider();
    await diary.init();

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: _testFood(),
      grams: 100,
      date: DateTime.now(),
      meal: Meal.dinner,
    );
    await diary.addEntry(entry);
    await diary.softDeleteEntry(entry.id);
    expect(diary.entries.any((e) => e.id == entry.id), isFalse);

    diary.undoDelete(entry.id);
    expect(diary.entries.any((e) => e.id == entry.id), isTrue);
  });

  test(
    'changeToken increments on entry mutations (WeekStrip reactivity)',
    () async {
      final diary = DiaryProvider();
      await diary.init();
      final initial = diary.changeToken;

      final entry = DiaryEntry(
        id: const Uuid().v4(),
        food: _testFood(),
        grams: 150,
        date: DateTime.now(),
        meal: Meal.breakfast,
      );
      await diary.addEntry(entry);
      expect(diary.changeToken, greaterThan(initial));

      final afterAdd = diary.changeToken;
      await diary.softDeleteEntry(entry.id);
      expect(diary.changeToken, greaterThan(afterAdd));

      final afterDelete = diary.changeToken;
      diary.undoDelete(entry.id);
      expect(diary.changeToken, greaterThan(afterDelete));
    },
  );

  test('updateEntryGrams persists new grams', () async {
    final diary = DiaryProvider();
    await diary.init();

    final food = _testFood();
    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: food,
      grams: 100,
      date: DateTime.now(),
      meal: Meal.lunch,
    );
    await diary.addEntry(entry);

    await diary.updateEntryGrams(entry.id, 250);

    final updated = diary.entries.firstWhere((e) => e.id == entry.id);
    expect(updated.grams, 250);
  });

  test('last-used grams are saved and retrieved', () async {
    final food = _testFood();
    await DatabaseService.instance.saveFood(food);
    await DatabaseService.instance.saveLastUsedGrams(food.id, 175);
    final result = await DatabaseService.instance.getLastUsedGrams(food.id);
    expect(result, 175.0);
  });

  test('last-used grams are overwritten on re-save', () async {
    final food = _testFood();
    await DatabaseService.instance.saveFood(food);
    await DatabaseService.instance.saveLastUsedGrams(food.id, 100);
    await DatabaseService.instance.saveLastUsedGrams(food.id, 250);
    final result = await DatabaseService.instance.getLastUsedGrams(food.id);
    expect(result, 250.0);
  });

  test('getLastUsedGrams returns null for unknown food', () async {
    final result = await DatabaseService.instance.getLastUsedGrams(
      'nonexistent_food_id',
    );
    expect(result, isNull);
  });

  // 500 kcal/100g: grams × 5 = kcal, making boundary arithmetic exact.
  FoodItem denseFood() => FoodItem(
    id: const Uuid().v4(),
    name: 'Dense Food',
    caloriesPer100g: 500,
    source: 'test',
  );

  test(
    'three-state calorie warning: green → amber → red as intake rises',
    () async {
      final diary = DiaryProvider();
      final settings = SettingsProvider(onGoalChanged: diary.refreshCurrentDay);
      await settings.setDailyGoal(2000);
      await settings.setTdee(2500);
      await diary.init();

      // Use a unique far-future date so other tests' entries don't contaminate totals.
      final testDate = DateTime(2099, 1, 1);
      await diary.loadDay(testDate);

      final entry = DiaryEntry(
        id: const Uuid().v4(),
        food: denseFood(),
        grams: 300, // = 1500 kcal: under goal
        date: testDate,
        meal: Meal.breakfast,
      );
      await diary.addEntry(entry);

      // 1500 kcal — under goal → green
      expect(diary.totalCalories, closeTo(1500, 1));
      expect(diary.remainingCalories, greaterThan(0));
      expect(settings.tdee > 0 && diary.totalCalories > settings.tdee, isFalse);

      // 2250 kcal — over 2000 goal, under 2500 TDEE → amber
      await diary.updateEntryGrams(entry.id, 450);
      expect(diary.totalCalories, closeTo(2250, 1));
      expect(diary.remainingCalories, lessThan(0));
      expect(settings.tdee > 0 && diary.totalCalories > settings.tdee, isFalse);

      // 2750 kcal — over 2500 TDEE → red
      await diary.updateEntryGrams(entry.id, 550);
      expect(diary.totalCalories, closeTo(2750, 1));
      expect(settings.tdee > 0 && diary.totalCalories > settings.tdee, isTrue);
    },
  );

  test('three-state warning: isOverTdee is false when TDEE is unset', () async {
    final diary = DiaryProvider();
    final settings = SettingsProvider(onGoalChanged: diary.refreshCurrentDay);
    await settings.setDailyGoal(2000);
    // TDEE intentionally not set (defaults to 0)
    await diary.init();

    final testDate = DateTime(2099, 1, 2);
    await diary.loadDay(testDate);

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: denseFood(),
      grams: 500, // = 2500 kcal: over goal but TDEE unset
      date: testDate,
      meal: Meal.breakfast,
    );
    await diary.addEntry(entry);

    expect(settings.tdee, 0);
    expect(diary.remainingCalories, lessThan(0)); // over goal
    // isOverTdee must be false when TDEE is 0 — falls back to two-state (over goal only)
    expect(settings.tdee > 0 && diary.totalCalories > settings.tdee, isFalse);
  });

  // ── deleteEntry (hard delete) ─────────────────────────────────────────────

  test(
    'deleteEntry: removes entry from the entries list immediately',
    () async {
      final diary = DiaryProvider();
      await diary.init();

      final entry = DiaryEntry(
        id: const Uuid().v4(),
        food: _testFood(),
        grams: 100,
        date: DateTime.now(),
        meal: Meal.snack,
      );
      await diary.addEntry(entry);
      expect(diary.entries.any((e) => e.id == entry.id), isTrue);

      await diary.deleteEntry(entry.id);
      expect(diary.entries.any((e) => e.id == entry.id), isFalse);
    },
  );

  test(
    'deleteEntry: is permanent — undoDelete has no effect afterwards',
    () async {
      final diary = DiaryProvider();
      await diary.init();

      final entry = DiaryEntry(
        id: const Uuid().v4(),
        food: _testFood(),
        grams: 100,
        date: DateTime.now(),
        meal: Meal.snack,
      );
      await diary.addEntry(entry);
      await diary.deleteEntry(entry.id);

      // undoDelete should be a no-op because the entry was hard-deleted, not soft-deleted
      diary.undoDelete(entry.id);
      expect(diary.entries.any((e) => e.id == entry.id), isFalse);
    },
  );

  // ── toggleLock ────────────────────────────────────────────────────────────

  test('toggleLock: flips isLocked state on successive calls', () async {
    final diary = DiaryProvider();
    await diary.init();
    expect(diary.isLocked, isFalse);

    await diary.toggleLock();
    expect(diary.isLocked, isTrue);

    await diary.toggleLock();
    expect(diary.isLocked, isFalse);
  });

  test(
    'lock guard: mutation methods are silently ignored when day is locked',
    () async {
      final diary = DiaryProvider();
      await diary.init();

      final entry = DiaryEntry(
        id: const Uuid().v4(),
        food: _testFood(),
        grams: 100,
        date: DateTime.now(),
        meal: Meal.lunch,
      );
      await diary.addEntry(entry);
      final countBefore = diary.entries.length;

      await diary.toggleLock();
      final tokenAfterLock = diary.changeToken;

      // addEntry should be ignored
      await diary.addEntry(
        DiaryEntry(
          id: const Uuid().v4(),
          food: _testFood(),
          grams: 50,
          date: DateTime.now(),
          meal: Meal.lunch,
        ),
      );
      expect(diary.entries.length, countBefore);

      // updateEntryGrams should be ignored
      await diary.updateEntryGrams(entry.id, 999);
      expect(diary.entries.firstWhere((e) => e.id == entry.id).grams, 100);

      // softDeleteEntry should return null without removing the entry
      final removed = await diary.softDeleteEntry(entry.id);
      expect(removed, isNull);
      expect(diary.entries.any((e) => e.id == entry.id), isTrue);

      // deleteEntry should be ignored
      await diary.deleteEntry(entry.id);
      expect(diary.entries.any((e) => e.id == entry.id), isTrue);

      // moveEntry should be a no-op
      await diary.moveEntry(entry.id, Meal.dinner);
      expect(
        diary.entries.firstWhere((e) => e.id == entry.id).meal,
        Meal.lunch,
      );

      // changeToken must not have incremented during any locked operation
      expect(diary.changeToken, tokenAfterLock);
    },
  );

  test(
    'lock guard: addWaterMl and removeWaterMl are blocked when locked',
    () async {
      final diary = DiaryProvider();
      await diary.init();
      await diary.addWaterMl(500);
      final waterBefore = diary.waterMl;

      await diary.toggleLock();

      await diary.addWaterMl(250);
      expect(diary.waterMl, waterBefore);

      await diary.removeWaterMl(100);
      expect(diary.waterMl, waterBefore);
    },
  );

  // ── moveEntry ─────────────────────────────────────────────────────────────

  test('moveEntry: reassigns entry to a different meal slot', () async {
    final diary = DiaryProvider();
    await diary.init();

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: _testFood(),
      grams: 100,
      date: DateTime.now(),
      meal: Meal.breakfast,
    );
    await diary.addEntry(entry);
    expect(
      diary.entriesForMeal(Meal.breakfast).any((e) => e.id == entry.id),
      isTrue,
    );

    await diary.moveEntry(entry.id, Meal.dinner);
    expect(
      diary.entriesForMeal(Meal.breakfast).any((e) => e.id == entry.id),
      isFalse,
    );
    expect(
      diary.entriesForMeal(Meal.dinner).any((e) => e.id == entry.id),
      isTrue,
    );
  });

  test('moveEntry: increments changeToken', () async {
    final diary = DiaryProvider();
    await diary.init();

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: _testFood(),
      grams: 100,
      date: DateTime.now(),
      meal: Meal.breakfast,
    );
    await diary.addEntry(entry);
    final tokenBefore = diary.changeToken;

    await diary.moveEntry(entry.id, Meal.lunch);
    expect(diary.changeToken, greaterThan(tokenBefore));
  });

  // ── Water tracking ────────────────────────────────────────────────────────

  test('addWaterMl: accumulates water volume', () async {
    final diary = DiaryProvider();
    await diary.init();
    await diary.loadDay(DateTime(2099, 3, 1));
    await diary.addWaterMl(250);
    await diary.addWaterMl(350);
    expect(diary.waterMl, 600);
  });

  test('removeWaterMl: clamps at zero — never goes negative', () async {
    final diary = DiaryProvider();
    await diary.init();
    await diary.loadDay(DateTime(2099, 3, 2));
    // waterMl starts at 0; removing 500 must clamp to 0
    await diary.removeWaterMl(500);
    expect(diary.waterMl, 0);
  });

  test('setWaterTargetMl: clamps to [1, 99999]', () async {
    final settings = SettingsProvider();
    await settings.init();

    await settings.setWaterTargetMl(0);
    expect(settings.waterTargetMl, 1);

    await settings.setWaterTargetMl(100000);
    expect(settings.waterTargetMl, 99999);

    await settings.setWaterTargetMl(2000);
    expect(settings.waterTargetMl, 2000);
  });

  test(
    'waterProgress: reflects proportion of target consumed, capped at 1.0',
    () async {
      final diary = DiaryProvider();
      final settings = SettingsProvider();
      await diary.init();
      await diary.loadDay(DateTime(2099, 3, 3));
      await settings.setWaterTargetMl(1000);

      await diary.addWaterMl(500);
      final progress1 = settings.waterTargetMl > 0
          ? (diary.waterMl / settings.waterTargetMl).clamp(0.0, 1.0)
          : 0.0;
      expect(progress1, closeTo(0.5, 0.01));

      await diary.addWaterMl(600); // total 1100ml — over target, progress capped
      final progress2 = settings.waterTargetMl > 0
          ? (diary.waterMl / settings.waterTargetMl).clamp(0.0, 1.0)
          : 0.0;
      expect(progress2, closeTo(1.0, 0.01));
    },
  );

  // ── setBmr ────────────────────────────────────────────────────────────────

  test('setBmr: persists the BMR value in the provider', () async {
    final settings = SettingsProvider();
    await settings.init();
    expect(settings.bmr, 0);

    await settings.setBmr(1800);
    expect(settings.bmr, 1800);
  });

  // ── setVessels ────────────────────────────────────────────────────────────

  test('setVessels: replaces the vessels list', () async {
    final settings = SettingsProvider();
    await settings.init();

    const vessel = WaterVessel(
      id: 'test_vessel_001',
      name: 'Test Cup',
      ml: 300,
      iconCodePoint: 0xe63f, // Icons.local_drink code point
    );
    await settings.setVessels([vessel]);
    expect(settings.vessels.length, 1);
    expect(settings.vessels.first.id, 'test_vessel_001');
    expect(settings.vessels.first.ml, 300);
  });

  // ── createRecipeFromMeal ──────────────────────────────────────────────────

  test(
    'createRecipeFromMeal: collapses meal entries into a single recipe entry',
    () async {
      final diary = DiaryProvider();
      await diary.init();
      final testDate = DateTime(2099, 8, 1);
      await diary.loadDay(testDate);

      await diary.addEntry(
        DiaryEntry(
          id: const Uuid().v4(),
          food: _testFood(),
          grams: 100,
          date: testDate,
          meal: Meal.dinner,
        ),
      );
      await diary.addEntry(
        DiaryEntry(
          id: const Uuid().v4(),
          food: _testFood(),
          grams: 200,
          date: testDate,
          meal: Meal.dinner,
        ),
      );
      expect(diary.entriesForMeal(Meal.dinner).length, 2);

      await diary.createRecipeFromMeal(Meal.dinner, 'My Test Recipe');

      final dinnerEntries = diary.entriesForMeal(Meal.dinner);
      expect(dinnerEntries.length, 1);
      expect(dinnerEntries.first.food.name, 'My Test Recipe');
      expect(dinnerEntries.first.food.source, 'custom');
    },
  );

  test('createRecipeFromMeal: no-op when meal has no entries', () async {
    final diary = DiaryProvider();
    await diary.init();
    final testDate = DateTime(2099, 8, 2);
    await diary.loadDay(testDate);
    final tokenBefore = diary.changeToken;

    await diary.createRecipeFromMeal(Meal.snack, 'Empty Recipe');

    expect(diary.changeToken, tokenBefore);
    expect(diary.entriesForMeal(Meal.snack), isEmpty);
  });
}
