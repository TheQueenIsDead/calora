// DatabaseService unit tests. Uses FFI sqlite so all queries run against
// an in-memory DB without the seed asset (foodsDb is skipped here).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:calora/models/diary_entry.dart';
import 'package:calora/models/food_item.dart';
import 'package:calora/services/database_service.dart';

FoodItem _food({
  String? id,
  String name = 'Test Food',
  double calories = 200,
  double protein = 10,
  double fat = 5,
  double carbs = 30,
}) => FoodItem(
  id: id ?? const Uuid().v4(),
  name: name,
  caloriesPer100g: calories,
  proteinPer100g: protein,
  fatPer100g: fat,
  carbsPer100g: carbs,
  source: 'test',
);

DiaryEntry _entry(
  FoodItem food, {
  required DateTime date,
  Meal meal = Meal.snack,
  double grams = 100,
}) => DiaryEntry(
  id: const Uuid().v4(),
  food: food,
  grams: grams,
  date: date,
  meal: meal,
);

void main() {
  setUpAll(() async {
    // Binding suppresses rootBundle errors when getFoodById falls back to foodsDb.
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Wipe any DB files from previous test runs so assertions start from zero.
    await DatabaseService.instance.closeForTesting();
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.userDb;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Food lookup ───────────────────────────────────────────────────────────

  test('getFoodById: finds food saved in userDb', () async {
    final food = _food();
    await DatabaseService.instance.saveFood(food);
    final found = await DatabaseService.instance.getFoodById(food.id);
    expect(found, isNotNull);
    expect(found!.id, food.id);
    expect(found.name, food.name);
  });

  test('getFoodById: returns null for unknown id', () async {
    final result = await DatabaseService.instance.getFoodById(
      'no_such_food_xyz_000',
    );
    expect(result, isNull);
  });

  // ── Goal history ──────────────────────────────────────────────────────────

  test(
    'saveGoal and getEffectiveGoal: returns saved value for same date',
    () async {
      await DatabaseService.instance.saveGoal(DateTime(2098, 1, 1), 2200);
      final result = await DatabaseService.instance.getEffectiveGoal(
        DateTime(2098, 1, 1),
      );
      expect(result, 2200);
    },
  );

  test(
    'getEffectiveGoal: step-function — applies most-recent goal on or before date',
    () async {
      await DatabaseService.instance.saveGoal(DateTime(2098, 2, 1), 1800);
      await DatabaseService.instance.saveGoal(DateTime(2098, 2, 10), 2400);

      // Between the two changes → still sees 1800
      final mid = await DatabaseService.instance.getEffectiveGoal(
        DateTime(2098, 2, 5),
      );
      expect(mid, 1800);

      // After the second change → sees 2400
      final after = await DatabaseService.instance.getEffectiveGoal(
        DateTime(2098, 2, 15),
      );
      expect(after, 2400);
    },
  );

  test('getEffectiveGoal: returns null when no goal set before date', () async {
    final result = await DatabaseService.instance.getEffectiveGoal(
      DateTime(1990, 1, 1),
    );
    expect(result, isNull);
  });

  test('getDailyGoals: fills date range with correct step values', () async {
    await DatabaseService.instance.saveGoal(DateTime(2098, 3, 1), 2000);
    await DatabaseService.instance.saveGoal(DateTime(2098, 3, 5), 2500);

    final goals = await DatabaseService.instance.getDailyGoals(
      DateTime(2098, 3, 1),
      DateTime(2098, 3, 7),
      1500,
    );

    expect(goals['2098-03-01'], 2000);
    expect(goals['2098-03-04'], 2000);
    expect(goals['2098-03-05'], 2500);
    expect(goals['2098-03-07'], 2500);
  });

  test('getDailyGoals: uses fallback when no goal exists in range', () async {
    final goals = await DatabaseService.instance.getDailyGoals(
      DateTime(1990, 1, 1),
      DateTime(1990, 1, 3),
      1750,
    );
    expect(goals['1990-01-01'], 1750);
    expect(goals['1990-01-02'], 1750);
    expect(goals['1990-01-03'], 1750);
  });

  // ── Weight log ────────────────────────────────────────────────────────────

  test(
    'saveWeight and getWeightHistory: round-trip persists the entry',
    () async {
      await DatabaseService.instance.saveWeight(DateTime(2098, 4, 1), 75.5);
      final history = await DatabaseService.instance.getWeightHistory(
        days: 365 * 200,
      );
      expect(
        history.any(
          (e) =>
              e.date.year == 2098 &&
              e.date.month == 4 &&
              (e.kg - 75.5).abs() < 0.01,
        ),
        isTrue,
      );
    },
  );

  test(
    'saveWeight: upserts — second save on same date replaces first',
    () async {
      await DatabaseService.instance.saveWeight(DateTime(2098, 4, 2), 70.0);
      await DatabaseService.instance.saveWeight(DateTime(2098, 4, 2), 72.3);
      final history = await DatabaseService.instance.getWeightHistory(
        days: 365 * 200,
      );
      final entries = history
          .where(
            (e) => e.date.year == 2098 && e.date.month == 4 && e.date.day == 2,
          )
          .toList();
      expect(entries.length, 1);
      expect(entries.first.kg, closeTo(72.3, 0.01));
    },
  );

  test(
    'getLatestWeight: returns a non-null entry after weights are saved',
    () async {
      await DatabaseService.instance.saveWeight(DateTime(2098, 4, 3), 68.0);
      final latest = await DatabaseService.instance.getLatestWeight();
      expect(latest, isNotNull);
    },
  );

  test(
    'deleteWeight: removes the entry so it no longer appears in history',
    () async {
      await DatabaseService.instance.saveWeight(DateTime(2098, 5, 1), 80.0);
      final history = await DatabaseService.instance.getWeightHistory(
        days: 365 * 200,
      );
      final entry = history.firstWhere(
        (e) => e.date.year == 2098 && e.date.month == 5 && e.date.day == 1,
      );
      await DatabaseService.instance.deleteWeight(entry.id);
      final after = await DatabaseService.instance.getWeightHistory(
        days: 365 * 200,
      );
      expect(after.any((e) => e.id == entry.id), isFalse);
    },
  );

  // ── Diary DB ──────────────────────────────────────────────────────────────

  test('deleteDiaryEntry: removes entry from DB permanently', () async {
    final food = _food();
    final entry = _entry(food, date: DateTime(2099, 3, 1));
    await DatabaseService.instance.addDiaryEntry(entry);
    final before = await DatabaseService.instance.getEntriesForDate(entry.date);
    expect(before.any((e) => e.id == entry.id), isTrue);

    await DatabaseService.instance.deleteDiaryEntry(entry.id);
    final after = await DatabaseService.instance.getEntriesForDate(entry.date);
    expect(after.any((e) => e.id == entry.id), isFalse);
  });

  test('updateEntryMeal: changes the meal column in DB', () async {
    final food = _food();
    final entry = _entry(
      food,
      date: DateTime(2099, 3, 2),
      meal: Meal.breakfast,
    );
    await DatabaseService.instance.addDiaryEntry(entry);

    await DatabaseService.instance.updateEntryMeal(entry.id, Meal.dinner);

    final rows = await DatabaseService.instance.getEntriesForDate(entry.date);
    final updated = rows.firstWhere((e) => e.id == entry.id);
    expect(updated.meal, Meal.dinner);
  });

  test(
    'getDailyCalories: aggregates kcal per day across multiple entries',
    () async {
      // 400 kcal/100g: 100g → 400 kcal, 50g → 200 kcal, 200g → 800 kcal
      final food = _food(id: const Uuid().v4(), calories: 400);
      final dateA = DateTime(2099, 4, 1);
      final dateB = DateTime(2099, 4, 2);
      await DatabaseService.instance.addDiaryEntry(
        _entry(food, date: dateA, grams: 100),
      );
      await DatabaseService.instance.addDiaryEntry(
        _entry(food, date: dateA, grams: 50),
      );
      await DatabaseService.instance.addDiaryEntry(
        _entry(food, date: dateB, grams: 200),
      );

      final result = await DatabaseService.instance.getDailyCalories(
        dateA,
        dateB,
      );
      expect(result['2099-04-01'], closeTo(600, 1));
      expect(result['2099-04-02'], closeTo(800, 1));
    },
  );

  test('getDailyMacros: aggregates protein/fat/carbs per day', () async {
    // protein=20, fat=10, carbs=40 per 100g; 200g → protein=40, fat=20, carbs=80
    final food = _food(
      id: const Uuid().v4(),
      calories: 300,
      protein: 20,
      fat: 10,
      carbs: 40,
    );
    final date = DateTime(2099, 4, 10);
    await DatabaseService.instance.addDiaryEntry(
      _entry(food, date: date, grams: 200),
    );

    final result = await DatabaseService.instance.getDailyMacros(date, date);
    final day = result[date.toIso8601String().substring(0, 10)];
    expect(day, isNotNull);
    expect(day!['protein'], closeTo(40, 0.5));
    expect(day['fat'], closeTo(20, 0.5));
    expect(day['carbs'], closeTo(80, 0.5));
  });

  // ── Recent foods ──────────────────────────────────────────────────────────

  test(
    'getRecentFoods: includes foods logged within the last 30 days',
    () async {
      final food = _food(id: const Uuid().v4(), name: 'UniqueRecentFood_XYZ');
      await DatabaseService.instance.addDiaryEntry(
        _entry(food, date: DateTime.now(), meal: Meal.snack),
      );
      final recent = await DatabaseService.instance.getRecentFoods(
        previousMeal: Meal.snack,
        date: DateTime.now(),
      );
      expect(recent.any((f) => f.id == food.id), isTrue);
    },
  );

  test(
    'getLastMealFoods: returns foods from the most recent prior occurrence of that meal',
    () async {
      final food = _food(id: const Uuid().v4(), name: 'LastMealFood_XYZ');
      // Entry on 2099-06-01; query for the most-recent snack before 2099-07-01
      await DatabaseService.instance.addDiaryEntry(
        _entry(food, date: DateTime(2099, 6, 1), meal: Meal.snack),
      );
      final result = await DatabaseService.instance.getLastMealFoods(
        meal: Meal.snack,
        date: DateTime(2099, 7, 1),
      );
      expect(result.any((f) => f.id == food.id), isTrue);
    },
  );

  // ── Recipes ───────────────────────────────────────────────────────────────

  test(
    'saveRecipeWithItems and getRecipeAsFood: computes macros proportionally',
    () async {
      // 500 kcal/100g, protein=30, fat=20, carbs=50 per 100g
      // 200g of this food → 1000 kcal total → still 500 kcal/100g normalised
      final food = _food(
        id: const Uuid().v4(),
        calories: 500,
        protein: 30,
        fat: 20,
        carbs: 50,
      );
      await DatabaseService.instance.saveFood(food);

      final recipeId = await DatabaseService.instance.saveRecipeWithItems(
        'Test Recipe',
        null,
        [(foodId: food.id, grams: 200.0)],
      );

      final recipe = await DatabaseService.instance.getRecipeAsFood(recipeId);
      expect(recipe, isNotNull);
      expect(recipe!.caloriesPer100g, closeTo(500, 1));
      expect(recipe.proteinPer100g, closeTo(30, 0.5));
      expect(recipe.name, 'Test Recipe');
      expect(recipe.id, 'recipe_$recipeId');
      // 200g total / 1 serving → servingGrams = 200
      expect(recipe.servingGrams, closeTo(200, 0.5));
    },
  );

  test(
    'getRecipesAsFood: lists all recipes and supports name filtering',
    () async {
      final food = _food(id: const Uuid().v4(), calories: 100);
      await DatabaseService.instance.saveFood(food);
      await DatabaseService.instance.saveRecipeWithItems(
        'QueryableRecipe_Alpha',
        null,
        [(foodId: food.id, grams: 100.0)],
      );

      final all = await DatabaseService.instance.getRecipesAsFood();
      expect(all.any((r) => r.name == 'QueryableRecipe_Alpha'), isTrue);

      final filtered = await DatabaseService.instance.getRecipesAsFood(
        'QueryableRecipe',
      );
      expect(filtered.any((r) => r.name == 'QueryableRecipe_Alpha'), isTrue);

      final none = await DatabaseService.instance.getRecipesAsFood(
        'zzznomatch_xyz_000',
      );
      expect(none.any((r) => r.name == 'QueryableRecipe_Alpha'), isFalse);
    },
  );

  test('renameRecipe: updates the recipe name in DB', () async {
    final food = _food(id: const Uuid().v4(), calories: 100);
    await DatabaseService.instance.saveFood(food);
    final recipeId = await DatabaseService.instance.saveRecipe('OldName', null);
    await DatabaseService.instance.addRecipeItem(recipeId, food.id, 100);

    await DatabaseService.instance.renameRecipe(recipeId, 'NewName');

    final recipe = await DatabaseService.instance.getRecipeAsFood(recipeId);
    expect(recipe!.name, 'NewName');
  });

  test('deleteRecipe: removes recipe and all its items atomically', () async {
    final food = _food(id: const Uuid().v4(), calories: 100);
    await DatabaseService.instance.saveFood(food);
    final recipeId = await DatabaseService.instance.saveRecipe(
      'ToDelete',
      null,
    );
    await DatabaseService.instance.addRecipeItem(recipeId, food.id, 100);

    await DatabaseService.instance.deleteRecipe(recipeId);

    expect(await DatabaseService.instance.getRecipeAsFood(recipeId), isNull);
    expect(await DatabaseService.instance.getRecipeItems(recipeId), isEmpty);
  });

  test(
    'addRecipeItem / updateRecipeItemGrams / deleteRecipeItem: full item CRUD',
    () async {
      final food = _food(id: const Uuid().v4(), calories: 100);
      await DatabaseService.instance.saveFood(food);
      final recipeId = await DatabaseService.instance.saveRecipe(
        'ItemCrudRecipe',
        null,
      );

      await DatabaseService.instance.addRecipeItem(recipeId, food.id, 150.0);
      final items = await DatabaseService.instance.getRecipeItems(recipeId);
      expect(items.length, 1);
      expect((items.first['grams'] as num).toDouble(), 150.0);

      final itemId = items.first['id'] as String;
      await DatabaseService.instance.updateRecipeItemGrams(itemId, 300.0);
      final updated = await DatabaseService.instance.getRecipeItems(recipeId);
      expect((updated.first['grams'] as num).toDouble(), 300.0);

      await DatabaseService.instance.deleteRecipeItem(itemId);
      expect(await DatabaseService.instance.getRecipeItems(recipeId), isEmpty);
    },
  );

  test(
    'getRecipeItems: returns enriched rows with food name and macros',
    () async {
      final food = _food(
        id: const Uuid().v4(),
        name: 'IngredientFood',
        calories: 100,
      );
      await DatabaseService.instance.saveFood(food);
      final recipeId = await DatabaseService.instance.saveRecipe(
        'EnrichedRecipe',
        null,
      );
      await DatabaseService.instance.addRecipeItem(recipeId, food.id, 75.0);

      final items = await DatabaseService.instance.getRecipeItems(recipeId);
      expect(items.length, 1);
      expect(items.first['name'], 'IngredientFood');
      expect(items.first['food_id'], food.id);
      expect((items.first['grams'] as num).toDouble(), 75.0);
    },
  );

  test(
    'updateRecipeServings: changes servings so servingGrams is divided correctly',
    () async {
      final food = _food(id: const Uuid().v4(), calories: 400);
      await DatabaseService.instance.saveFood(food);
      // 200g total, 1 serving → 200g/serving
      final recipeId = await DatabaseService.instance.saveRecipeWithItems(
        'ServingsRecipe',
        null,
        [(foodId: food.id, grams: 200.0)],
      );

      await DatabaseService.instance.updateRecipeServings(recipeId, 4);

      final recipe = await DatabaseService.instance.getRecipeAsFood(recipeId);
      // 200g / 4 servings → 50g per serving
      expect(recipe!.servingGrams, closeTo(50, 0.5));
    },
  );
}
