// UI-only widget tests. No direct DB access — widget tests use Flutter's fake
// async clock, which is incompatible with sqflite's real 10-second transaction
// timers. DiaryProvider unit tests live in provider_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:calora/main.dart';
import 'package:calora/models/diary_entry.dart';
import 'package:calora/models/food_item.dart';
import 'package:calora/providers/diary_provider.dart';
import 'package:calora/providers/settings_provider.dart';
import 'package:calora/screens/add_food_screen.dart';
import 'package:calora/screens/food_detail_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app renders without crashing', (tester) async {
    final diary = DiaryProvider();
    final settings = SettingsProvider(onGoalChanged: diary.refreshCurrentDay);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: diary),
        ],
        child: const CaloraApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('AddFoodScreen shows search bar', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: DiaryProvider(),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: AddFoodScreen(defaultMeal: Meal.lunch)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Search foods…'), findsOneWidget);
  });

  testWidgets('AddFoodScreen shows loading indicator while searching', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: DiaryProvider(),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: AddFoodScreen(defaultMeal: Meal.lunch)),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(SearchBar), 'chicken');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  // ── FoodDetailScreen ──────────────────────────────────────────────────────

  // Passing initialGrams avoids the async getLastUsedGrams DB call in initState,
  // keeping these tests compatible with Flutter's fake-async clock.

  testWidgets('FoodDetailScreen shows Save Changes button in edit mode', (
    tester,
  ) async {
    final food = FoodItem(
      id: 'test_edit_food',
      name: 'Chicken Breast',
      caloriesPer100g: 165,
      source: 'test',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: FoodDetailScreen(
          food: food,
          defaultMeal: Meal.lunch,
          existingEntryId: 'entry-abc',
          initialGrams: 150,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Add to Diary'), findsNothing);
    expect(find.text('Add to Recipe'), findsNothing);
  });

  testWidgets('FoodDetailScreen shows Add to Diary button in normal add mode', (
    tester,
  ) async {
    final food = FoodItem(
      id: 'test_add_food',
      name: 'Brown Rice',
      caloriesPer100g: 130,
      source: 'test',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: FoodDetailScreen(
          food: food,
          defaultMeal: Meal.dinner,
          initialGrams: 100,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Add to Diary'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Add to Recipe'), findsNothing);
  });

  testWidgets(
    'FoodDetailScreen shows Add to Recipe button in recipe ingredient mode',
    (tester) async {
      final food = FoodItem(
        id: 'test_recipe_food',
        name: 'Olive Oil',
        caloriesPer100g: 884,
        source: 'test',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: FoodDetailScreen(
            food: food,
            defaultMeal: Meal.dinner,
            initialGrams: 15,
            onAdd: (grams) async {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add to Recipe'), findsOneWidget);
      expect(find.text('Add to Diary'), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
    },
  );
}
