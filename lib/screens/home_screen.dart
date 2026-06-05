import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
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
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addFood(context, Meal.snack),
            icon: const Icon(Icons.add),
            label: const Text('Add Food'),
          ),
        );
      },
    );
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

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CalorieRing(progress: diary.progress, isOver: isOver),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOver ? 'Over goal' : 'Remaining',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${remaining.abs().toStringAsFixed(0)} kcal',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOver ? theme.colorScheme.error : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MacroRow(label: 'Carbs', value: diary.totalCarbs, color: Colors.blue),
                  const SizedBox(height: 4),
                  _MacroRow(label: 'Protein', value: diary.totalProtein, color: Colors.orange),
                  const SizedBox(height: 4),
                  _MacroRow(label: 'Fat', value: diary.totalFat, color: Colors.purple),
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
    final cups = diary.waterCups;
    final ml = cups * 250;

    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
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
                    '$cups cups  ·  $ml ml',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: theme.colorScheme.onSecondaryContainer,
              onPressed: cups > 0 ? () => diary.setWaterCups(cups - 1) : null,
            ),
            Text(
              '$cups',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: theme.colorScheme.onSecondaryContainer,
              onPressed: () => diary.setWaterCups(cups + 1),
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

class _MacroRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label  ${value.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}