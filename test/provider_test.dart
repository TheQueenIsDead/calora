// DiaryProvider unit tests. Uses real async (plain test(), not testWidgets)
// so sqflite FFI operations complete without fake-timer interference.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:calora/models/diary_entry.dart';
import 'package:calora/models/food_item.dart';
import 'package:calora/providers/diary_provider.dart';
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
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    // Pre-open the DB once here (may take a moment on first FFI init) so
    // individual tests reuse the cached connection and stay within 30s.
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

  test('changeToken increments on entry mutations (WeekStrip reactivity)', () async {
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
  });

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
}
