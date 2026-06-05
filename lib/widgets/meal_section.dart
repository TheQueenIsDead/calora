import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../models/food_item.dart';

class MealSection extends StatelessWidget {
  final Meal meal;
  final List<DiaryEntry> entries;
  final Future<void> Function(String) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function(DiaryEntry entry, Meal target) onMove;

  const MealSection({
    super.key,
    required this.meal,
    required this.entries,
    required this.onDelete,
    required this.onAdd,
    required this.onMove,
  });

  double get _mealCalories => entries.fold(0, (sum, e) => sum + e.calories);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<DiaryEntry>(
      onWillAcceptWithDetails: (d) => d.data.meal != meal,
      onAcceptWithDetails: (d) => onMove(d.data, meal),
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: isHovered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      width: 2),
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                )
              : null,
          padding: isHovered ? const EdgeInsets.all(4) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      meal.label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (entries.isNotEmpty)
                      Text(
                        '${_mealCalories.toStringAsFixed(0)} kcal',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.add_circle_outline,
                            size: 20, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    isHovered ? 'Drop here' : 'Nothing logged yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: isHovered
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                )
              else
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      for (int i = 0; i < entries.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16),
                        _EntryTile(entry: entries[i], onDelete: onDelete),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final DiaryEntry entry;
  final Future<void> Function(String) onDelete;

  const _EntryTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LongPressDraggable<DiaryEntry>(
      data: entry,
      delay: const Duration(milliseconds: 400),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_indicator, size: 18,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  entry.food.formattedName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.calories.toStringAsFixed(0)} kcal',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _tileContent(context),
      ),
      child: Dismissible(
        key: Key(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: theme.colorScheme.errorContainer,
          child: Icon(Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer),
        ),
        onDismissed: (_) => onDelete(entry.id),
        child: _tileContent(context),
      ),
    );
  }

  Widget _tileContent(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        _categoryIcon(entry.food),
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(entry.food.formattedName, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${entry.calories.toStringAsFixed(0)} kcal',
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  static IconData _categoryIcon(FoodItem food) {
    // ID-based lookup for AUSNUT and NZ — more reliable than keyword matching
    if (food.source == 'ausnut') {
      final numeric = food.id.replaceFirst('ausnut_', '');
      if (numeric.length >= 2) {
        final icon = _ausnutIcon(numeric.substring(0, 2));
        if (icon != null) return icon;
      }
    } else if (food.source == 'nz') {
      final letter = food.id.replaceFirst('nz_', '')[0].toUpperCase();
      final icon = _nzIcon(letter);
      if (icon != null) return icon;
    }
    return _keywordIcon(food.name);
  }

  static IconData? _ausnutIcon(String prefix) => switch (prefix) {
    '11' => Icons.local_drink,
    '12' => Icons.grain,
    '13' => Icons.breakfast_dining,
    '14' => Icons.opacity,
    '15' => Icons.set_meal,
    '16' => Icons.eco,
    '17' => Icons.egg,
    '18' => Icons.set_meal,
    '19' => Icons.water_drop,
    '20' => Icons.water_drop,
    '21' => Icons.soup_kitchen,
    '22' => Icons.grain,
    '23' => Icons.opacity,
    '24' => Icons.eco,
    '25' => Icons.eco,
    '26' => Icons.fastfood,
    '27' => Icons.cake,
    '28' => Icons.cake,
    '29' => Icons.local_bar,
    '30' => Icons.fitness_center,
    '31' => Icons.breakfast_dining,
    '33' => Icons.set_meal,
    '34' => Icons.fitness_center,
    _   => null,
  };

  static IconData? _nzIcon(String letter) => switch (letter) {
    'A' => Icons.breakfast_dining,
    'B' => Icons.local_bar,
    'C' => Icons.local_drink,
    'D' => Icons.grain,
    'E' => Icons.grain,
    'F' => Icons.opacity,
    'G' => Icons.egg,
    'H' => Icons.fastfood,
    'J' => Icons.opacity,
    'K' => Icons.set_meal,
    'L' => Icons.eco,
    'M' => Icons.set_meal,
    'N' => Icons.set_meal,
    'P' => Icons.water_drop,
    'Q' => Icons.grain,
    'R' => Icons.dinner_dining,
    'S' => Icons.opacity,
    'T' => Icons.set_meal,
    'U' => Icons.fastfood,
    'V' => Icons.soup_kitchen,
    'W' => Icons.cake,
    'X' => Icons.eco,
    _   => null,
  };

  static IconData _keywordIcon(String name) {
    final n = name.toLowerCase();
    bool has(List<String> words) => words.any((w) => n.contains(w));

    if (has(['coffee', 'espresso', 'latte', 'cappuccino', 'flat white', 'mocha'])) return Icons.local_cafe;
    if (has(['tea', 'chai'])) return Icons.emoji_food_beverage;
    if (has(['beer', 'wine', 'spirit', 'alcohol', 'cider', 'liqueur', 'whisky', 'vodka', 'rum', 'gin'])) return Icons.local_bar;
    if (has(['juice', 'smoothie', 'water', 'soda', 'cola', 'drink', 'beverage', 'milkshake'])) return Icons.local_drink;
    if (has(['egg', 'omelette', 'omelet'])) return Icons.egg;
    if (has(['apple', 'banana', 'orange', 'grape', 'berry', 'mango', 'pear', 'peach', 'plum', 'cherry', 'melon', 'pineapple', 'kiwi', 'lemon', 'lime', 'fruit', 'avocado', 'fig', 'apricot', 'nectarine', 'guava', 'papaya', 'passionfruit'])) return Icons.eco;
    if (has(['vegetable', 'veg', 'carrot', 'broccoli', 'spinach', 'lettuce', 'tomato', 'cucumber', 'onion', 'garlic', 'potato', 'pea', 'bean', 'corn', 'celery', 'zucchini', 'courgette', 'capsicum', 'pepper', 'mushroom', 'salad', 'kale', 'cabbage', 'cauliflower', 'asparagus', 'beetroot', 'leek', 'pumpkin', 'squash', 'artichoke', 'eggplant', 'aubergine', 'silverbeet', 'bok choy', 'rocket'])) return Icons.eco;
    if (has(['beef', 'chicken', 'pork', 'lamb', 'turkey', 'meat', 'steak', 'mince', 'sausage', 'bacon', 'ham', 'salami', 'pepperoni', 'venison', 'duck', 'veal', 'liver', 'prosciutto', 'chorizo', 'schnitzel'])) return Icons.set_meal;
    if (has(['fish', 'salmon', 'tuna', 'cod', 'prawn', 'shrimp', 'crab', 'lobster', 'squid', 'seafood', 'mussel', 'oyster', 'anchovy', 'sardine', 'mackerel', 'snapper', 'hoki', 'barramundi', 'trout'])) return Icons.set_meal;
    if (has(['bread', 'toast', 'roll', 'bagel', 'wrap', 'tortilla', 'pita', 'naan', 'sourdough', 'baguette', 'croissant', 'crumpet', 'flatbread', 'focaccia'])) return Icons.breakfast_dining;
    if (has(['pasta', 'noodle', 'spaghetti', 'penne', 'lasagne', 'lasagna', 'gnocchi', 'rice', 'risotto', 'couscous', 'quinoa', 'polenta'])) return Icons.dinner_dining;
    if (has(['oat', 'cereal', 'muesli', 'granola', 'grain', 'barley', 'bran', 'porridge'])) return Icons.grain;
    if (has(['milk', 'cheese', 'yogurt', 'yoghurt', 'butter', 'cream', 'dairy', 'whey', 'cheddar', 'mozzarella', 'feta', 'ricotta', 'custard'])) return Icons.water_drop;
    if (has(['nut', 'almond', 'walnut', 'cashew', 'peanut', 'pistachio', 'pecan', 'hazelnut', 'macadamia', 'seed', 'chia', 'tahini'])) return Icons.grain;
    if (has(['burger', 'pizza', 'chips', 'fries', 'hot dog', 'kebab', 'taco', 'burrito', 'nugget', 'takeaway', 'takeout'])) return Icons.fastfood;
    if (has(['cake', 'cookie', 'biscuit', 'chocolate', 'candy', 'sweet', 'dessert', 'ice cream', 'gelato', 'pudding', 'brownie', 'donut', 'doughnut', 'tart', 'muffin', 'scone', 'waffle', 'pancake', 'lolly', 'lollies'])) return Icons.cake;
    if (has(['soup', 'broth', 'stew', 'chowder', 'ramen', 'pho', 'laksa'])) return Icons.soup_kitchen;
    if (has(['oil', 'dressing', 'sauce', 'mayonnaise', 'ketchup', 'mustard', 'vinegar', 'pesto', 'hummus', 'jam', 'honey', 'syrup', 'spread', 'vegemite', 'marmite'])) return Icons.opacity;
    if (has(['protein', 'supplement', 'powder', 'creatine'])) return Icons.fitness_center;
    return Icons.restaurant;
  }
}
