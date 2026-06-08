import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diary_provider.dart';
import 'bmr_calculator_screen.dart';
import 'recipes_screen.dart';
import 'water_vessels_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Goals'),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text('Daily calorie target'),
            trailing: Text('${diary.currentGoal} kcal',
                style: Theme.of(context).textTheme.bodyMedium),
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
                style: Theme.of(context).textTheme.bodyMedium),
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
            subtitle: Text('${diary.vessels.length} vessel${diary.vessels.length == 1 ? '' : 's'} configured'),
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
          const _SectionHeader('Food'),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Recipes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecipesScreen()),
            ),
          ),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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