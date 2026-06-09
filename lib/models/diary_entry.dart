import 'food_item.dart';

enum Meal { breakfast, lunch, dinner, snack }

extension MealLabel on Meal {
  String get label => switch (this) {
    Meal.breakfast => 'Breakfast',
    Meal.lunch => 'Lunch',
    Meal.dinner => 'Dinner',
    Meal.snack => 'Snack',
  };
}

class DiaryEntry {
  final String id;
  final FoodItem food;
  final double grams;
  final DateTime date;
  final Meal meal;

  const DiaryEntry({
    required this.id,
    required this.food,
    required this.grams,
    required this.date,
    required this.meal,
  });

  double get calories => food.caloriesForGrams(grams);
  double get fat => food.fatForGrams(grams);
  double get carbs => food.carbsForGrams(grams);
  double get protein => food.proteinForGrams(grams);

  Map<String, dynamic> toMap() => {
    'id': id,
    'food_id': food.id,
    'grams': grams,
    'date': date.toIso8601String().substring(0, 10),
    'meal': meal.name,
  };

  factory DiaryEntry.fromMap(Map<String, dynamic> m, FoodItem food) =>
      DiaryEntry(
        id: m['id'] as String,
        food: food,
        grams: (m['grams'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        meal: Meal.values.firstWhere(
          (e) => e.name == m['meal'],
          orElse: () => Meal.snack,
        ),
      );
}
