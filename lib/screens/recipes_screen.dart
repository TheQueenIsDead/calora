import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';
import 'add_food_screen.dart';
import 'food_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Map<String, dynamic>> _recipes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipes = await DatabaseService.instance.getRecipes();
    if (mounted) setState(() => _recipes = recipes);
  }

  Future<void> _createRecipe() async {
    final name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;
    final id = await DatabaseService.instance.saveRecipe(name.trim(), null);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecipeDetailScreen(recipeId: id, recipeName: name.trim()),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRecipe,
        icon: const Icon(Icons.add),
        label: const Text('New recipe'),
      ),
      body: _recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recipes yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to create your first recipe',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _recipes.length,
              itemBuilder: (context, i) {
                final r = _recipes[i];
                final kcal = (r['total_kcal'] as num?)?.toDouble() ?? 0;
                final kcalStr = kcal > 0
                    ? '${kcal.toStringAsFixed(0)} kcal'
                    : null;
                final description = r['description'] as String?;
                final subtitleParts = [
                  if (description != null && description.isNotEmpty)
                    description,
                  ?kcalStr,
                ];
                return ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(r['name'] as String),
                  subtitle: subtitleParts.isNotEmpty
                      ? Text(subtitleParts.join('  ·  '))
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(
                          recipeId: r['id'] as String,
                          recipeName: r['name'] as String,
                        ),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
    );
  }

  Future<String?> _promptName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recipe name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Overnight oats'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ── Recipe detail / ingredient editor ────────────────────────────────────────

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  final String recipeName;
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    required this.recipeName,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  List<Map<String, dynamic>> _items = [];
  late String _name;
  int _servings = 1;

  @override
  void initState() {
    super.initState();
    _name = widget.recipeName;
    _load();
  }

  Future<void> _load() async {
    final items = await DatabaseService.instance.getRecipeItems(
      widget.recipeId,
    );
    final recipes = await DatabaseService.instance.getRecipes();
    final recipe = recipes.firstWhere(
      (r) => r['id'] == widget.recipeId,
      orElse: () => <String, dynamic>{},
    );
    if (mounted) {
      setState(() {
        _items = items;
        _servings = (recipe['servings'] as int?) ?? 1;
      });
    }
  }

  double get _totalCalories => _items.fold(
    0,
    (s, i) => s + (i['grams'] as num) * (i['calories_per_100g'] as num) / 100,
  );
  double get _totalProtein => _items.fold(
    0,
    (s, i) => s + (i['grams'] as num) * (i['protein_per_100g'] as num) / 100,
  );
  double get _totalFat => _items.fold(
    0,
    (s, i) => s + (i['grams'] as num) * (i['fat_per_100g'] as num) / 100,
  );
  double get _totalCarbs => _items.fold(
    0,
    (s, i) => s + (i['grams'] as num) * (i['carbs_per_100g'] as num) / 100,
  );

  static String _sourceLabel(String source) => switch (source) {
    'ausnut' => 'AUSNUT 2023',
    'nz' => 'NZ Food Comp.',
    'usda' => 'USDA',
    'off_nz' || 'off' => 'Open Food Facts',
    'custom' => 'Custom',
    _ => source,
  };

  Future<void> _addIngredient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodScreen(
          defaultMeal: Meal.breakfast,
          onIngredientAdded: (food, grams) async {
            await DatabaseService.instance.saveFood(food);
            await DatabaseService.instance.addRecipeItem(
              widget.recipeId,
              food.id,
              grams,
            );
            _load();
          },
        ),
      ),
    );
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final food = await DatabaseService.instance.getFoodById(
      item['food_id'] as String,
    );
    if (food == null || !mounted) return;

    double? newGrams;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: food,
          defaultMeal: Meal.breakfast,
          initialGrams: (item['grams'] as num).toDouble(),
          onAdd: (grams) async {
            newGrams = grams;
          },
        ),
      ),
    );
    if (newGrams != null && mounted) {
      await DatabaseService.instance.updateRecipeItemGrams(
        item['id'] as String,
        newGrams!,
      );
      _load();
    }
  }

  Future<void> _deleteItem(String id) async {
    await DatabaseService.instance.deleteRecipeItem(id);
    _load();
  }

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text(
          'This will permanently delete "$_name" and all its ingredients.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DatabaseService.instance.deleteRecipe(widget.recipeId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editServings() async {
    final controller = TextEditingController(text: _servings.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servings'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Number of servings'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              Navigator.pop(ctx, (v != null && v > 0) ? v : null);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await DatabaseService.instance.updateRecipeServings(
      widget.recipeId,
      result,
    );
    setState(() => _servings = result);
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename recipe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Recipe name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == _name || !mounted) {
      return;
    }
    await DatabaseService.instance.renameRecipe(widget.recipeId, newName);
    setState(() => _name = newName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_outlined),
            tooltip: 'Set servings',
            onPressed: _editServings,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename recipe',
            onPressed: _rename,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Delete recipe',
            onPressed: _deleteRecipe,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addIngredient,
        icon: const Icon(Icons.add),
        label: const Text('Add ingredient'),
      ),
      body: Column(
        children: [
          if (_items.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MacroChip(
                          '${(_totalCalories / _servings).toStringAsFixed(0)} kcal',
                          'Calories',
                        ),
                        _MacroChip(
                          '${(_totalProtein / _servings).toStringAsFixed(1)}g',
                          'Protein',
                        ),
                        _MacroChip(
                          '${(_totalFat / _servings).toStringAsFixed(1)}g',
                          'Fat',
                        ),
                        _MacroChip(
                          '${(_totalCarbs / _servings).toStringAsFixed(1)}g',
                          'Carbs',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _editServings,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_servings serving${_servings == 1 ? '' : 's'} · per serving',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      'No ingredients yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final kcal =
                          (item['grams'] as num) *
                          (item['calories_per_100g'] as num) /
                          100;
                      return Dismissible(
                        key: Key(item['id'] as String),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: theme.colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) => _deleteItem(item['id'] as String),
                        child: ListTile(
                          title: Text(
                            FoodItem.formatName(item['name'] as String),
                          ),
                          subtitle: Text(
                            '${(item['grams'] as num).toStringAsFixed(0)} g'
                            '  ·  ${_sourceLabel(item['source'] as String? ?? '')}',
                          ),
                          trailing: Text(
                            '${kcal.toStringAsFixed(0)} kcal',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => _editItem(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String value;
  final String label;
  const _MacroChip(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
