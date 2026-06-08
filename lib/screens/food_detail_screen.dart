import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart' show Uuid;
import '../models/diary_entry.dart';
import '../models/food_item.dart';
import '../providers/diary_provider.dart';
import '../services/database_service.dart';

class FoodDetailScreen extends StatefulWidget {
  final FoodItem food;
  final Meal defaultMeal;
  /// If provided, the screen operates in "recipe ingredient" mode:
  /// the meal picker is hidden and this callback receives the chosen grams.
  final Future<void> Function(double grams)? onAdd;

  /// Override the initial gram value (defaults to last-used → servingGrams → 100).
  final double? initialGrams;

  /// If set, the screen edits an existing diary entry instead of adding a new one.
  final String? existingEntryId;

  const FoodDetailScreen({
    super.key,
    required this.food,
    required this.defaultMeal,
    this.onAdd,
    this.initialGrams,
    this.existingEntryId,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _gramsController;
  late Meal _meal;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final defaultGrams = widget.initialGrams ?? widget.food.servingGrams ?? 100.0;
    _gramsController = TextEditingController(text: defaultGrams.toStringAsFixed(0));
    _meal = widget.defaultMeal;

    // Load last-used grams when no explicit override is provided.
    if (widget.initialGrams == null) {
      DatabaseService.instance.getLastUsedGrams(widget.food.id).then((g) {
        if (g != null && mounted) {
          _gramsController.text = g.toStringAsFixed(0);
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  double get _grams => double.tryParse(_gramsController.text) ?? 100;
  double get _calories => widget.food.caloriesForGrams(_grams);

  static String _sourceLabel(FoodItem food) {
    if (food.id.startsWith('recipe_')) return 'Your recipe';
    return switch (food.source) {
      'ausnut'        => 'AUSNUT 2023',
      'nz'            => 'NZ Food Composition',
      'usda'          => 'USDA',
      'off_nz' || 'off' => 'Open Food Facts',
      'custom'        => 'Custom entry',
      _               => food.source,
    };
  }

  List<Widget> _buildPortionChips(FoodItem food) {
    final List<({String label, double grams})> presets;

    if (food.servingGrams != null && food.servingGrams! > 0) {
      final s = food.servingGrams!;
      presets = [
        (label: '½ serving', grams: s / 2),
        (label: '1 serving', grams: s),
        (label: '2 servings', grams: s * 2),
      ];
    } else {
      presets = _portionSuggestions(food.name);
    }

    if (presets.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: presets.map((p) => ActionChip(
          label: Text('${p.label} (${p.grams.toStringAsFixed(0)}g)'),
          onPressed: () {
            _gramsController.text = p.grams.toStringAsFixed(0);
            setState(() {});
          },
        )).toList(),
      ),
    ];
  }

  static List<({String label, double grams})> _portionSuggestions(String name) {
    final n = name.toLowerCase();
    bool has(String k) => n.contains(k);

    // Fruit
    if (has('banana')) return [(label: 'Small', grams: 90), (label: 'Medium', grams: 120), (label: 'Large', grams: 150)];
    if (has('kiwifruit') || has('kiwi fruit') || (has('kiwi') && !has('chicken'))) return [(label: '1 fruit', grams: 76), (label: '2 fruit', grams: 152)];
    if (has('apple')) return [(label: 'Small', grams: 130), (label: 'Medium', grams: 185), (label: 'Large', grams: 240)];
    if (has('pear')) return [(label: 'Small', grams: 140), (label: 'Medium', grams: 180), (label: 'Large', grams: 220)];
    if (has('orange')) return [(label: 'Small', grams: 130), (label: 'Medium', grams: 180), (label: 'Large', grams: 230)];
    if (has('mandarin') || has('clementine') || has('satsuma')) return [(label: '1 fruit', grams: 75), (label: '2 fruit', grams: 150)];
    if (has('avocado')) return [(label: '½ avocado', grams: 85), (label: '1 avocado', grams: 170)];
    if (has('mango')) return [(label: '½ cup', grams: 83), (label: '1 cup', grams: 165)];
    if (has('peach') || has('nectarine') || has('plum') || has('apricot')) return [(label: '1 fruit', grams: 130), (label: '2 fruit', grams: 260)];
    if (has('grape')) return [(label: 'Small bunch', grams: 80), (label: '1 cup', grams: 150)];
    if (has('strawberr') || has('blueberr') || has('raspberr')) return [(label: 'Handful', grams: 80), (label: '1 cup', grams: 150)];
    if (has('watermelon')) return [(label: '1 slice', grams: 280), (label: '1 cup', grams: 154)];
    if (has('pineapple')) return [(label: '1 ring', grams: 84), (label: '1 cup', grams: 165)];
    if (has('lemon') || has('lime')) return [(label: '1 fruit', grams: 58), (label: '½ fruit', grams: 29)];

    // Vegetables
    if (has('potato') && !has('sweet')) return [(label: 'Small', grams: 150), (label: 'Medium', grams: 200), (label: 'Large', grams: 300)];
    if (has('sweet potato') || has('kumara')) return [(label: 'Small', grams: 130), (label: 'Medium', grams: 180), (label: 'Large', grams: 250)];
    if (has('carrot')) return [(label: '1 medium', grams: 61), (label: '2 medium', grams: 122)];
    if (has('broccoli')) return [(label: '1 cup', grams: 91), (label: '½ head', grams: 200)];
    if (has('cauliflower')) return [(label: '1 cup', grams: 107), (label: '½ head', grams: 300)];
    if (has('tomato')) return [(label: 'Small', grams: 90), (label: 'Medium', grams: 130), (label: 'Large', grams: 180)];
    if (has('capsicum') || has('bell pepper')) return [(label: '½ capsicum', grams: 60), (label: '1 capsicum', grams: 120)];
    if (has('onion')) return [(label: 'Small', grams: 70), (label: 'Medium', grams: 110), (label: 'Large', grams: 150)];
    if (has('corn') || has('sweetcorn')) return [(label: '½ cob', grams: 90), (label: '1 cob', grams: 180)];
    if (has('cucumber')) return [(label: '½ cucumber', grams: 150), (label: '1 cucumber', grams: 300)];
    if (has('zucchini') || has('courgette')) return [(label: '½ medium', grams: 100), (label: '1 medium', grams: 196)];
    if (has('eggplant') || has('aubergine')) return [(label: '½ eggplant', grams: 200), (label: '1 eggplant', grams: 400)];
    if (has('pumpkin')) return [(label: '1 cup cubed', grams: 116), (label: '2 cups cubed', grams: 232)];
    if (has('mushroom')) return [(label: '1 cup', grams: 96), (label: '4 medium', grams: 72)];
    if (has('spinach') || has('silverbeet')) return [(label: '1 cup raw', grams: 30), (label: '½ cup cooked', grams: 90)];
    if (has('lettuce') || has('salad green')) return [(label: '1 cup', grams: 47), (label: '2 cups', grams: 94)];
    if (has('celery')) return [(label: '1 stalk', grams: 40), (label: '3 stalks', grams: 120)];
    if (has('asparagus')) return [(label: '4 spears', grams: 60), (label: '8 spears', grams: 120)];
    if (has('pea')) return [(label: '½ cup', grams: 80), (label: '1 cup', grams: 160)];
    if (has('bean') && (has('green') || has('string'))) return [(label: '½ cup', grams: 55), (label: '1 cup', grams: 110)];

    // Grains
    if (has('bread') || has('toast')) return [(label: '1 thin slice', grams: 25), (label: '1 slice', grams: 35), (label: '1 thick slice', grams: 45)];
    if (has('rice') && !has('rice cake')) return [(label: '½ cup', grams: 100), (label: '1 cup', grams: 200), (label: '1½ cups', grams: 300)];
    if (has('pasta') || has('spaghetti') || has('penne') || has('macaroni') || has('fettuccine')) return [(label: '1 cup', grams: 140), (label: '1½ cups', grams: 210)];
    if (has('noodle')) return [(label: '1 cup', grams: 140), (label: '2 cups', grams: 280)];
    if (has('oat') || has('porridge') || has('muesli')) return [(label: '½ cup dry', grams: 45), (label: '1 cup cooked', grams: 250)];
    if (has('wrap') || has('tortilla')) return [(label: '1 small', grams: 35), (label: '1 large', grams: 50)];

    // Protein
    if (has('egg')) return [(label: '1 medium', grams: 58), (label: '2 medium', grams: 116), (label: '3 medium', grams: 174)];
    if (has('chicken breast')) return [(label: 'Small', grams: 120), (label: 'Medium', grams: 170), (label: 'Large', grams: 230)];
    if (has('chicken thigh')) return [(label: 'Small', grams: 90), (label: 'Medium', grams: 130), (label: 'Large', grams: 180)];
    if (has('chicken') && has('drumstick')) return [(label: '1 drumstick', grams: 100), (label: '2 drumsticks', grams: 200)];
    if (has('salmon')) return [(label: 'Small fillet', grams: 100), (label: 'Medium fillet', grams: 150), (label: 'Large fillet', grams: 200)];
    if (has('tuna')) return [(label: '½ can', grams: 95), (label: '1 can', grams: 185)];
    if (has('beef') || has('steak')) return [(label: 'Small', grams: 100), (label: 'Medium', grams: 150), (label: 'Large', grams: 200)];
    if (has('lamb chop') || has('pork chop')) return [(label: '1 chop', grams: 100), (label: '2 chops', grams: 200)];
    if (has('tofu')) return [(label: '½ cup', grams: 126), (label: '1 cup', grams: 252)];
    if (has('lentil') || has('chickpea') || (has('bean') && !has('coffee') && !has('green'))) return [(label: '½ cup cooked', grams: 100), (label: '1 cup cooked', grams: 200)];
    if (has('peanut butter') || has('almond butter')) return [(label: '1 tbsp', grams: 16), (label: '2 tbsp', grams: 32)];
    if (has('almond') || has('cashew') || has('walnut') || has('pecan') || has('pistachio')) return [(label: 'Small handful', grams: 20), (label: 'Large handful', grams: 40)];

    // Dairy
    if (has('milk')) return [(label: '½ cup', grams: 125), (label: '1 cup', grams: 250)];
    if (has('cheese') && !has('cheesecake')) return [(label: '1 slice', grams: 20), (label: 'Thick slice', grams: 30), (label: '¼ cup grated', grams: 30)];
    if (has('yoghurt') || has('yogurt')) return [(label: 'Small pot', grams: 100), (label: 'Large pot', grams: 170)];
    if (has('butter') || has('margarine')) return [(label: '1 tsp', grams: 5), (label: '1 tbsp', grams: 14)];

    return [];
  }

  Future<void> _log() async {
    if (widget.onAdd != null) {
      await widget.onAdd!(_grams);
      if (mounted) Navigator.pop(context);
      return;
    }

    await DatabaseService.instance.saveLastUsedGrams(widget.food.id, _grams);

    if (widget.existingEntryId != null) {
      await context.read<DiaryProvider>().updateEntryGrams(widget.existingEntryId!, _grams);
      if (mounted) Navigator.pop(context);
      return;
    }

    final entry = DiaryEntry(
      id: const Uuid().v4(),
      food: widget.food,
      grams: _grams,
      date: context.read<DiaryProvider>().selectedDate,
      meal: _meal,
    );
    await context.read<DiaryProvider>().addEntry(entry);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;

    return Scaffold(
      appBar: AppBar(
        title: Text(food.formattedName, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Portion'),
            Tab(text: 'Macros'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PortionPage(
            food: food,
            gramsController: _gramsController,
            meal: _meal,
            showMealPicker: widget.onAdd == null,
            calories: _calories,
            grams: _grams,
            sourceLabel: _sourceLabel(food),
            portionChips: _buildPortionChips(food),
            onMealChanged: (m) => setState(() => _meal = m),
            onGramsChanged: () => setState(() {}),
          ),
          _MacrosPage(food: food, grams: _grams, calories: _calories),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _grams > 0 ? _log : null,
            icon: const Icon(Icons.add),
            label: Text(widget.onAdd != null
                ? 'Add to Recipe'
                : widget.existingEntryId != null
                    ? 'Save Changes'
                    : 'Add to Diary'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
      ),
    );
  }
}

// ── Page 1: Portion ───────────────────────────────────────────────────────────

class _PortionPage extends StatelessWidget {
  final FoodItem food;
  final TextEditingController gramsController;
  final Meal meal;
  final bool showMealPicker;
  final double calories;
  final double grams;
  final String sourceLabel;
  final List<Widget> portionChips;
  final void Function(Meal) onMealChanged;
  final VoidCallback onGramsChanged;

  const _PortionPage({
    required this.food,
    required this.gramsController,
    required this.meal,
    required this.showMealPicker,
    required this.calories,
    required this.grams,
    required this.sourceLabel,
    required this.portionChips,
    required this.onMealChanged,
    required this.onGramsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (food.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(food.imageUrl!, height: 180, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        if (food.brand != null) ...[
          const SizedBox(height: 4),
          Text(food.brand!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.storage_outlined,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65)),
            const SizedBox(width: 4),
            Text(sourceLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.65))),
          ],
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Portion size', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: gramsController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            suffix: Text('g'), border: OutlineInputBorder()),
                        onChanged: (_) => onGramsChanged(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (food.servingGrams != null)
                      TextButton(
                        onPressed: () {
                          gramsController.text =
                              food.servingGrams!.toStringAsFixed(0);
                          onGramsChanged();
                        },
                        child: Text(
                            '1 serving (${food.servingGrams!.toStringAsFixed(0)}g)'),
                      ),
                  ],
                ),
                ...portionChips,
                const SizedBox(height: 8),
                Text(
                  '= ${calories.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (showMealPicker)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meal', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: Meal.values
                        .map((m) => ChoiceChip(
                              label: Text(m.label),
                              selected: meal == m,
                              onSelected: (_) => onMealChanged(m),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Page 2: Macros ────────────────────────────────────────────────────────────

class _MacrosPage extends StatelessWidget {
  final FoodItem food;
  final double grams;
  final double calories;

  const _MacrosPage({
    required this.food,
    required this.grams,
    required this.calories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = grams;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nutrition per ${g.toStringAsFixed(0)}g',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                _NutrientRow('Calories', '${calories.toStringAsFixed(0)} kcal',
                    bold: true),
                _NutrientRow('Carbohydrates',
                    '${food.carbsForGrams(g).toStringAsFixed(1)}g'),
                _NutrientRow(
                    '  of which sugars',
                    '${(food.sugarsPer100g * g / 100).toStringAsFixed(1)}g',
                    indent: true),
                _NutrientRow(
                    'Fat', '${food.fatForGrams(g).toStringAsFixed(1)}g'),
                _NutrientRow(
                    '  of which saturates',
                    '${(food.saturatedFatPer100g * g / 100).toStringAsFixed(1)}g',
                    indent: true),
                _NutrientRow('Protein',
                    '${food.proteinForGrams(g).toStringAsFixed(1)}g'),
                _NutrientRow(
                    'Fibre', '${(food.fiberPer100g * g / 100).toStringAsFixed(1)}g'),
                _NutrientRow('Sodium',
                    '${(food.sodiumPer100g * g / 100 * 1000).toStringAsFixed(0)}mg'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Per 100g', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                _NutrientRow('Calories',
                    '${food.caloriesPer100g.toStringAsFixed(0)} kcal',
                    bold: true),
                _NutrientRow('Carbohydrates',
                    '${food.carbsPer100g.toStringAsFixed(1)}g'),
                _NutrientRow('  of which sugars',
                    '${food.sugarsPer100g.toStringAsFixed(1)}g',
                    indent: true),
                _NutrientRow(
                    'Fat', '${food.fatPer100g.toStringAsFixed(1)}g'),
                _NutrientRow('  of which saturates',
                    '${food.saturatedFatPer100g.toStringAsFixed(1)}g',
                    indent: true),
                _NutrientRow(
                    'Protein', '${food.proteinPer100g.toStringAsFixed(1)}g'),
                _NutrientRow(
                    'Fibre', '${food.fiberPer100g.toStringAsFixed(1)}g'),
                _NutrientRow('Sodium',
                    '${(food.sodiumPer100g * 1000).toStringAsFixed(0)}mg'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool indent;

  const _NutrientRow(this.label, this.value,
      {this.bold = false, this.indent = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: indent
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
