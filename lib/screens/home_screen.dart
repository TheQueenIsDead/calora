import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../models/water_vessel.dart';
import '../providers/diary_provider.dart';
import '../services/database_service.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_section.dart';
import 'add_food_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DiaryProvider>(
      builder: (context, diary, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => diary.loadDay(
                    diary.selectedDate.subtract(const Duration(days: 1)),
                  ),
                ),
                GestureDetector(
                  onTap: () => _pickDate(context, diary),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(diary.selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isToday(diary.selectedDate) ? null : () => diary.loadDay(
                    diary.selectedDate.add(const Duration(days: 1)),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _showGoalDialog(context, diary),
              ),
            ],
          ),
          body: diary.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => diary.loadDay(diary.selectedDate),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _WeekStrip(
                        selectedDate: diary.selectedDate,
                        onDateSelected: diary.loadDay,
                      ),
                      const SizedBox(height: 12),
                      _SummaryCard(diary: diary),
                      const SizedBox(height: 12),
                      _WaterCard(diary: diary),
                      const SizedBox(height: 20),
                      for (final meal in Meal.values)
                        MealSection(
                          meal: meal,
                          entries: diary.entriesForMeal(meal),
                          onDelete: diary.deleteEntry,
                          onAdd: () => _addFood(context, meal),
                          onMove: (entry, target) =>
                              diary.moveEntry(entry.id, target),
                          onSaveAsRecipe: () => _saveAsRecipe(context, meal),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _saveAsRecipe(BuildContext context, Meal meal) async {
    final diary = context.read<DiaryProvider>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save ${meal.label} as recipe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Recipe name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await diary.createRecipeFromMeal(meal, name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "$name" as a recipe')),
        );
      }
    }
  }

  Future<void> _addFood(BuildContext context, Meal meal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFoodScreen(defaultMeal: meal)),
    );
  }

  Future<void> _pickDate(BuildContext context, DiaryProvider diary) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: diary.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) diary.loadDay(picked);
  }

  void _showGoalDialog(BuildContext context, DiaryProvider diary) {
    final controller = TextEditingController(text: diary.dailyGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Calorie Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffix: Text('kcal')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) diary.setDailyGoal(val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
  }
}

class _SummaryCard extends StatelessWidget {
  final DiaryProvider diary;
  const _SummaryCard({required this.diary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = diary.remainingCalories;
    final isOver = remaining < 0;
    final tdeeDeficit = diary.tdee > 0 ? diary.tdee - diary.totalCalories : null;
    final tdeeIsSet = diary.tdee > 0;

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CalorieRing(progress: diary.progress, isOver: isOver, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _StatBlock(
                          label: isOver ? 'Over goal' : 'Remaining',
                          value: '${remaining.abs().toStringAsFixed(0)} kcal',
                          valueColor: isOver
                              ? theme.colorScheme.error
                              : theme.colorScheme.onPrimaryContainer,
                          labelColor: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Expanded(
                        child: _StatBlock(
                          label: tdeeIsSet
                              ? (tdeeDeficit! > 0 ? 'TDEE deficit' : 'Above TDEE')
                              : 'TDEE deficit',
                          value: tdeeIsSet
                              ? '${tdeeDeficit!.abs().toStringAsFixed(0)} kcal'
                              : '—',
                          valueColor: tdeeIsSet
                              ? (tdeeDeficit! > 0
                                  ? Colors.lightGreen.shade300
                                  : theme.colorScheme.error)
                              : theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.35),
                          labelColor: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MacroBar(
                    carbs: diary.totalCarbs,
                    protein: diary.totalProtein,
                    fat: diary.totalFat,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  final DiaryProvider diary;
  const _WaterCard({required this.diary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ml = diary.waterMl;
    final vessels = diary.vessels;

    String mlLabel() {
      if (ml == 0) return '0 ml';
      if (ml >= 1000) return '${(ml / 1000).toStringAsFixed(ml % 100 == 0 ? 1 : 2)}L';
      return '$ml ml';
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Water',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    mlLabel(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  if (vessels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: vessels.map((v) => _VesselChip(
                        vessel: v,
                        onTap: () => diary.addWaterMl(v.ml),
                        onLongPress: ml >= v.ml ? () => diary.removeWaterMl(v.ml) : null,
                        color: theme.colorScheme.onSecondaryContainer,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VesselChip extends StatelessWidget {
  final WaterVessel vessel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color color;

  const _VesselChip({
    required this.vessel,
    required this.onTap,
    required this.onLongPress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(vessel.icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              vessel.ml >= 1000 ? '${vessel.ml ~/ 1000}L' : '${vessel.ml}ml',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Week strip ───────────────────────────────────────────────────────────────

class _WeekStrip extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;
  const _WeekStrip({required this.selectedDate, required this.onDateSelected});

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  Map<String, double> _weekCalories = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_WeekStrip old) {
    super.didUpdateWidget(old);
    if (_weekStart(widget.selectedDate) != _weekStart(old.selectedDate)) {
      _load();
    }
  }

  DateTime _weekStart(DateTime d) {
    final weekday = d.weekday; // 1=Mon … 7=Sun
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
  }

  Future<void> _load() async {
    final from = _weekStart(widget.selectedDate);
    final to = from.add(const Duration(days: 6));
    final data = await DatabaseService.instance.getDailyCalories(from, to);
    if (mounted) setState(() => _weekCalories = data);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final selectedStr = widget.selectedDate.toIso8601String().substring(0, 10);
    final weekStart = _weekStart(widget.selectedDate);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(7, (i) {
            final date = weekStart.add(Duration(days: i));
            final dateStr = date.toIso8601String().substring(0, 10);
            final isSelected = dateStr == selectedStr;
            final isToday = dateStr == todayStr;
            final hasData = (_weekCalories[dateStr] ?? 0) > 0;
            final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));

            return GestureDetector(
              onTap: isFuture ? null : () => widget.onDateSelected(date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLetters[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : hasData
                              ? theme.colorScheme.primary.withValues(alpha: 0.15)
                              : null,
                      border: isToday && !isSelected
                          ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: isFuture
                        ? null
                        : hasData
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                              )
                            : isToday
                                ? Center(
                                    child: Text(
                                      '${date.day}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: labelColor),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  final double carbs;
  final double protein;
  final double fat;
  const _MacroBar({required this.carbs, required this.protein, required this.fat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onPrimaryContainer;
    final total = carbs + protein + fat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: total > 0
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (carbs > 0)
                      Expanded(
                        flex: (carbs / total * 1000).round(),
                        child: const ColoredBox(color: Colors.blue),
                      ),
                    if (protein > 0)
                      Expanded(
                        flex: (protein / total * 1000).round(),
                        child: const ColoredBox(color: Colors.orange),
                      ),
                    if (fat > 0)
                      Expanded(
                        flex: (fat / total * 1000).round(),
                        child: const ColoredBox(color: Colors.purple),
                      ),
                  ])
                : ColoredBox(color: onBg.withValues(alpha: 0.12)),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _macroLabel(context, 'Carbs', carbs, Colors.blue),
            _macroLabel(context, 'Protein', protein, Colors.orange),
            _macroLabel(context, 'Fat', fat, Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _macroLabel(BuildContext context, String label, double value, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(
          '${value.toStringAsFixed(0)}g $label',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}