import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diary_provider.dart';
import '../services/database_service.dart';
import 'bmr_calculator_screen.dart';
import 'recipes_screen.dart';
import 'water_vessels_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _recipes = [];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final recipes = await DatabaseService.instance.getRecipes();
    if (mounted) setState(() => _recipes = recipes);
  }

  Future<void> _createRecipe() async {
    final name = await _promptName();
    if (name == null || name.trim().isEmpty) return;
    final id = await DatabaseService.instance.saveRecipe(name.trim(), null);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipeId: id, recipeName: name.trim()),
      ),
    );
    _loadRecipes();
  }

  Future<String?> _promptName() {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget? _recipeSubtitle(Map<String, dynamic> r) {
    final kcal = (r['total_kcal'] as num?)?.toDouble() ?? 0;
    final kcalStr = kcal > 0 ? '${kcal.toStringAsFixed(0)} kcal' : null;
    final description = r['description'] as String?;
    final parts = [
      if (description != null && description.isNotEmpty) description,
      ?kcalStr,
    ];
    return parts.isNotEmpty ? Text(parts.join('  ·  ')) : null;
  }

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRecipe,
        icon: const Icon(Icons.add),
        label: const Text('New recipe'),
      ),
      body: ListView(
        children: [
          const _SectionHeader('Goals'),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Daily calorie target'),
            trailing: Text('${diary.currentGoal} kcal',
                style: theme.textTheme.bodyMedium),
            onTap: () => _editInt(
              context,
              title: 'Daily calorie target',
              suffix: 'kcal',
              current: diary.currentGoal,
              onSave: diary.setDailyGoal,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text('Daily water target'),
            trailing: Text('${diary.waterTargetMl} ml',
                style: theme.textTheme.bodyMedium),
            onTap: () => _editInt(
              context,
              title: 'Daily water target',
              suffix: 'ml',
              current: diary.waterTargetMl,
              onSave: diary.setWaterTargetMl,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_drink_outlined),
            title: const Text('Water vessels'),
            subtitle: Text(
                '${diary.vessels.length} vessel${diary.vessels.length == 1 ? '' : 's'} configured'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WaterVesselsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('BMR / TDEE calculator'),
            subtitle: const Text('Estimate your calorie needs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BmrCalculatorScreen()),
            ),
          ),
          const Divider(),
          const _SectionHeader('Recipes'),
          if (_recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 48, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text('No recipes yet',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          else
            for (final r in _recipes)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(r['name'] as String),
                subtitle: _recipeSubtitle(r),
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
                  _loadRecipes();
                },
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _editInt(
    BuildContext context, {
    required String title,
    required String suffix,
    required int current,
    required Future<void> Function(int) onSave,
  }) async {
    final controller = TextEditingController(text: current.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffix: Text(suffix)),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) onSave(val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
