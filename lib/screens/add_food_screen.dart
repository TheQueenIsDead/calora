import 'dart:async';
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';
import '../services/food_lookup_service.dart';
import 'barcode_scan_screen.dart';
import 'food_detail_screen.dart';

class AddFoodScreen extends StatefulWidget {
  final Meal defaultMeal;
  const AddFoodScreen({super.key, required this.defaultMeal});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _searchController = TextEditingController();
  final _lookup = FoodLookupService();
  List<FoodItem> _foodResults = [];
  List<FoodItem> _recipeResults = [];
  List<FoodItem> _recentFoods = [];
  List<FoodItem> _previousMealFoods = [];
  bool _searching = false;
  String? _error;
  Timer? _debounce;

  // The meal that preceded the current one in the day's natural flow.
  Meal get _previousMeal => switch (widget.defaultMeal) {
        Meal.lunch => Meal.breakfast,
        Meal.dinner => Meal.lunch,
        Meal.snack => Meal.dinner,
        Meal.breakfast => Meal.snack,
      };

  @override
  void initState() {
    super.initState();
    _loadIdleState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIdleState() async {
    final today = DateTime.now();
    final results = await Future.wait([
      DatabaseService.instance.getRecipesAsFood(),
      DatabaseService.instance.getRecentFoods(previousMeal: _previousMeal, date: today),
      DatabaseService.instance.getLastMealFoods(meal: widget.defaultMeal, date: today),
    ]);
    // Foods already logged in today's current meal — omit from suggestion strips
    // so items the user has already added don't clutter the "Previous X" section.
    final todayEntries = await DatabaseService.instance.getEntriesForDate(today);
    final alreadyLoggedIds = todayEntries
        .where((e) => e.meal == widget.defaultMeal)
        .map((e) => e.food.id)
        .toSet();
    if (mounted) {
      final prevIds = results[2].map((f) => f.id).toSet();
      setState(() {
        _recipeResults = results[0];
        // Exclude foods already shown in the Previous [Meal] strip.
        _recentFoods = results[1].where((f) => !prevIds.contains(f.id)).toList();
        // Exclude foods already logged in today's meal from the suggestion strip.
        _previousMealFoods = results[2].where((f) => !alreadyLoggedIds.contains(f.id)).toList();
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      if (mounted) setState(() { _foodResults = []; _searching = false; _error = null; });
      _loadIdleState();
      return;
    }
    if (mounted) setState(() { _searching = true; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await Future.wait([
        _lookup.search(query.trim()),
        DatabaseService.instance.getRecipesAsFood(query.trim()),
      ]);
      if (mounted) {
        setState(() {
          _foodResults = results[0];
          _recipeResults = results[1];
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Search failed. Check your connection.'; _searching = false; });
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (barcode == null || !mounted) return;

    setState(() { _searching = true; _error = null; });
    final food = await _lookup.lookupBarcode(barcode);
    if (!mounted) return;

    if (food == null) {
      setState(() {
        _searching = false;
        _error = 'Product not found for barcode $barcode. Try searching by name.';
      });
      return;
    }
    setState(() => _searching = false);
    _openDetail(food);
  }

  void _openDetail(FoodItem food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(food: food, defaultMeal: widget.defaultMeal),
      ),
    );
  }

  bool get _hasResults => _foodResults.isNotEmpty || _recipeResults.isNotEmpty;
  bool get _isSearching => _searchController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search foods…',
              leading: const Icon(Icons.search),
              onChanged: _onSearchChanged,
              onSubmitted: _search,
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            )
          else if (!_hasResults && _isSearching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No results found.'),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  // ── Previous meal strip (idle state only) ────────────────
                  if (!_isSearching && _previousMealFoods.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.restaurant_menu,
                      label: 'Previous ${widget.defaultMeal.label}',
                    ),
                    for (final food in _previousMealFoods)
                      ListTile(
                        leading: const Icon(Icons.restaurant_menu, size: 20),
                        title: Text(food.formattedName),
                        subtitle: food.brand != null ? Text(food.brand!) : null,
                        trailing: Text(
                          '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () => _openDetail(food),
                      ),
                  ],
                  // ── Recent foods (idle state only) ───────────────────────
                  if (!_isSearching && _recentFoods.isNotEmpty) ...[
                    const _SectionHeader(icon: Icons.history, label: 'Recent'),
                    for (final food in _recentFoods)
                      ListTile(
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(food.formattedName),
                        subtitle: food.brand != null ? Text(food.brand!) : null,
                        trailing: Text(
                          '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () => _openDetail(food),
                      ),
                  ],
                  // ── Recipes section ──────────────────────────────────────
                  if (_recipeResults.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.menu_book_outlined,
                      label: 'My Recipes',
                    ),
                    for (final food in _recipeResults)
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(food.formattedName),
                        subtitle: food.servingGrams != null
                            ? Text('${food.servingGrams!.toStringAsFixed(0)} g total')
                            : const Text('No ingredients yet'),
                        trailing: food.caloriesPer100g > 0
                            ? Text(
                                '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                                style: theme.textTheme.bodySmall,
                              )
                            : null,
                        onTap: food.caloriesPer100g > 0
                            ? () => _openDetail(food)
                            : null,
                      ),
                    if (_foodResults.isNotEmpty)
                      const _SectionHeader(icon: Icons.search, label: 'Foods'),
                  ],
                  // ── Foods section ────────────────────────────────────────
                  for (final food in _foodResults)
                    ListTile(
                      title: Text(food.formattedName),
                      subtitle: food.brand != null ? Text(food.brand!) : null,
                      trailing: Text(
                        '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => _openDetail(food),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
