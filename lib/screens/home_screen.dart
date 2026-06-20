import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:health/health.dart' show HealthWorkoutActivityType;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../models/water_vessel.dart';
import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_section.dart';
import 'add_food_screen.dart';
import 'food_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Resting calories that Out includes but the workouts + ambient rows don't —
/// i.e. HC's TOTAL minus everything the activity card already itemises.
/// Returns 0 when TOTAL is unavailable so we don't fabricate the number.
int _restingKcal(DiaryProvider diary) {
  final total = diary.totalBurnHc;
  if (total == null) return 0;
  final workoutsTotal = diary.workouts.fold<int>(
    0,
    (s, w) => s + (w.totalKcal ?? w.activeKcal),
  );
  final resting = total - workoutsTotal - diary.ambientActiveKcal;
  return resting > 0 ? resting : 0;
}

int _computeExpenditure(DiaryProvider diary, SettingsProvider settings) {
  // Two clean branches: when Health Connect is on, Out is whatever HC says
  // it is (TOTAL_CALORIES_BURNED summed over the day, basal + active). When
  // it's off, Out is the user's static TDEE from the BMR calculator. No
  // hybrid estimation — keeps the number trustable and the model simple.
  if (!settings.useHealthConnect) return settings.tdee;
  return diary.totalBurnHc ?? settings.tdee;
}


class _HomeScreenState extends State<HomeScreen> {
  // Pinned key so snackbars always target this specific ScaffoldMessenger,
  // bypassing the global messenger that all tab Scaffolds share via IndexedStack.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  // External Dart timer to guarantee snackbar dismissal. ScaffoldMessenger's
  // internal ticker-based timer can be disrupted by Consumer rebuilds.
  Timer? _snackDismissTimer;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Consumer<DiaryProvider>(
        builder: (context, diary, _) {
          final settings = context.watch<SettingsProvider>();
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(diary.isLocked ? Icons.lock : Icons.lock_open),
                tooltip: diary.isLocked ? 'Unlock day' : 'Lock day',
                onPressed: diary.toggleLock,
              ),
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
                    onTap: () => _pickDate(diary),
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
                    onPressed: _isToday(diary.selectedDate)
                        ? null
                        : () => diary.loadDay(
                            diary.selectedDate.add(const Duration(days: 1)),
                          ),
                  ),
                ],
              ),
              centerTitle: true,
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
                          changeToken: diary.changeToken,
                          onDateSelected: diary.loadDay,
                        ),
                        const SizedBox(height: 12),
                        _SummaryCard(
                          diary: diary,
                          expenditure: _computeExpenditure(diary, settings),
                        ),
                        const SizedBox(height: 12),
                        _WaterCard(
                          diary: diary,
                          isLocked: diary.isLocked,
                          waterTargetMl: settings.waterTargetMl,
                          vessels: settings.vessels,
                        ),
                        if (settings.useHealthConnect &&
                            (diary.workouts.isNotEmpty ||
                                diary.ambientActiveKcal > 0)) ...[
                          const SizedBox(height: 12),
                          _ActivitiesCard(
                            workouts: diary.workouts,
                            ambientActiveKcal: diary.ambientActiveKcal,
                            restingKcal: _restingKcal(diary),
                          ),
                        ],
                        const SizedBox(height: 20),
                        for (final meal in Meal.values)
                          MealSection(
                            meal: meal,
                            entries: diary.entriesForMeal(meal),
                            onDelete: (id) => _handleDelete(diary, id),
                            onEdit: _editEntry,
                            onAdd: () => _addFood(meal),
                            onMove: (entry, target) =>
                                diary.moveEntry(entry.id, target),
                            onSaveAsRecipe: () => _saveAsRecipe(diary, meal),
                            isLocked: diary.isLocked,
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _snackDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleDelete(DiaryProvider diary, String id) async {
    final entry = await diary.softDeleteEntry(id);
    if (entry == null || !mounted) return;
    _snackDismissTimer?.cancel();
    _messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${entry.food.formattedName}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _snackDismissTimer?.cancel();
              diary.undoDelete(id);
            },
          ),
        ),
      );
    // Belt-and-suspenders: Dart Timer is independent of Flutter's ticker/
    // TickerMode so it fires even when ScaffoldMessenger's own timer doesn't.
    _snackDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _messengerKey.currentState?.clearSnackBars();
    });
  }

  Future<void> _saveAsRecipe(DiaryProvider diary, Meal meal) async {
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await diary.createRecipeFromMeal(meal, name);
      if (mounted) context.read<SettingsProvider>().loadRecipes();
      if (mounted) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Saved "$name" as a recipe')),
        );
      }
    }
  }

  Future<void> _editEntry(DiaryEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: entry.food,
          defaultMeal: entry.meal,
          existingEntryId: entry.id,
          initialGrams: entry.grams,
        ),
      ),
    );
  }

  Future<void> _addFood(Meal meal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddFoodScreen(defaultMeal: meal)),
    );
  }

  Future<void> _pickDate(DiaryProvider diary) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: diary.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) diary.loadDay(picked);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
  final int expenditure;
  const _SummaryCard({required this.diary, required this.expenditure});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = diary.remainingCalories;
    final isOverGoal = remaining < 0;
    final isOverTdee = expenditure > 0 && diary.totalCalories > expenditure;
    final intake = diary.totalCalories;
    final deficit = expenditure > 0 ? expenditure - intake : null;

    final Color ringValueColor;
    final String ringTagline;
    if (isOverTdee) {
      ringValueColor = theme.colorScheme.error;
      ringTagline = 'over TDEE';
    } else if (isOverGoal) {
      ringValueColor = Colors.amber.shade800;
      ringTagline = 'over goal';
    } else {
      ringValueColor = theme.colorScheme.onPrimaryContainer;
      ringTagline = 'left';
    }
    final mutedColor = theme.colorScheme.onPrimaryContainer
        .withValues(alpha: 0.7);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CalorieRing(
              progress: diary.progress,
              size: 72,
              color: isOverTdee
                  ? theme.colorScheme.error
                  : isOverGoal
                  ? Colors.amber
                  : null,
              centerChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    remaining.abs().toStringAsFixed(0),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ringValueColor,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    ringTagline,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: mutedColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EnergyBalanceLine(
                    intake: intake,
                    expenditure: expenditure,
                    deficit: deficit,
                    mutedColor: mutedColor,
                    valueColor: theme.colorScheme.onPrimaryContainer,
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

class _ActivitiesCard extends StatelessWidget {
  final List<HcWorkout> workouts;
  final int ambientActiveKcal;

  /// HC TOTAL minus everything itemised below — i.e. basal-at-rest plus
  /// movement that wasn't claimed by a workout or the ambient stream.
  /// Zero when HC TOTAL is unavailable, in which case the row is hidden.
  final int restingKcal;

  const _ActivitiesCard({
    required this.workouts,
    required this.ambientActiveKcal,
    required this.restingKcal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Match the per-row display (totalKcal preferred, else activeKcal) so
    // the header sum equals what the user sees expanded.
    final workoutSum = workouts.fold<int>(
      0,
      (s, w) => s + (w.totalKcal ?? w.activeKcal),
    );
    final totalKcal = workoutSum + ambientActiveKcal + restingKcal;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile draws a divider on top by default; suppress it.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          leading: Icon(
            Icons.fitness_center,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            'Health Connect activities',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            '$totalKcal kcal',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            for (final w in workouts) _ActivityRow(workout: w),
            if (ambientActiveKcal > 0) _AmbientRow(kcal: ambientActiveKcal),
            if (restingKcal > 0) _RestingRow(kcal: restingKcal),
          ],
        ),
      ),
    );
  }
}

class _AmbientRow extends StatelessWidget {
  final int kcal;
  const _AmbientRow({required this.kcal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ambient movement', style: theme.textTheme.bodyMedium),
                Text(
                  'Active calories outside tracked workouts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$kcal kcal',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestingRow extends StatelessWidget {
  final int kcal;
  const _RestingRow({required this.kcal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.bedtime_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resting', style: theme.textTheme.bodyMedium),
                Text(
                  'Basal calories Health Connect tracked for you',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$kcal kcal',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final HcWorkout workout;
  const _ActivityRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat.jm().format(workout.start);
    final mins = workout.duration.inMinutes;
    final durStr = mins >= 60
        ? '${mins ~/ 60}h ${mins % 60}m'
        : '${mins}m';
    // Out is sourced from HC's TOTAL_CALORIES_BURNED sum when available,
    // so the activity card is purely informational. Show HC's reported
    // session total when present (matches what HC's own UI shows for the
    // workout), otherwise fall back to our measured active.
    final display = workout.totalKcal ?? workout.activeKcal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            _iconFor(workout.activityType),
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _friendly(workout.activityType),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '$timeStr  ·  $durStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$display kcal',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _friendly(HealthWorkoutActivityType type) {
    if (type.name == 'OTHER') return 'Activity';
    final parts = type.name.split('_');
    if (parts.isEmpty) return type.name;
    return parts
        .map(
          (p) => p.isEmpty
              ? p
              : p[0].toUpperCase() + p.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  static IconData _iconFor(HealthWorkoutActivityType type) {
    final name = type.name;
    if (name.contains('RUNNING')) return Icons.directions_run;
    if (name.contains('WALKING')) return Icons.directions_walk;
    if (name.contains('BIKING') || name.contains('CYCLING')) {
      return Icons.directions_bike;
    }
    if (name.contains('SWIMMING')) return Icons.pool;
    if (name.contains('STRENGTH') || name.contains('WEIGHT')) {
      return Icons.fitness_center;
    }
    if (name.contains('YOGA')) return Icons.self_improvement;
    if (name.contains('HIKING')) return Icons.terrain;
    return Icons.local_fire_department;
  }
}

class _WaterCard extends StatefulWidget {
  final DiaryProvider diary;
  final bool isLocked;
  final int waterTargetMl;
  final List<WaterVessel> vessels;
  const _WaterCard({
    required this.diary,
    required this.waterTargetMl,
    required this.vessels,
    this.isLocked = false,
  });

  @override
  State<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<_WaterCard> {
  bool _subtracting = false;

  String _mlLabel(int ml) {
    if (ml == 0) return '0\nml';
    if (ml >= 1000) {
      final l = ml / 1000;
      return '${l % 1 == 0 ? l.toInt() : l.toStringAsFixed(1)}\nL';
    }
    return '$ml\nml';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diary = widget.diary;
    final ml = diary.waterMl;
    final targetMl = widget.waterTargetMl;
    final vessels = widget.vessels;
    final onBg = theme.colorScheme.onSecondaryContainer;
    final chipColor = _subtracting ? theme.colorScheme.error : onBg;

    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CalorieRing(
              progress: targetMl > 0 ? (ml / targetMl).clamp(0.0, 1.0) : 0.0,
              size: 72,
              label: _mlLabel(ml),
              color: Colors.lightBlue.shade400,
              labelColor: onBg,
              backgroundColor: Colors.lightBlue.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/water_bottle.svg',
                        width: 14,
                        height: 14,
                        colorFilter: ColorFilter.mode(
                          onBg.withValues(alpha: 0.7),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Water',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onBg.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      if (!widget.isLocked)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _subtracting = !_subtracting),
                          child: SizedBox(
                            width: 56,
                            height: 26,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: onBg.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeInOut,
                                  alignment: _subtracting
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  child: Container(
                                    width: 28,
                                    height: 22,
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: _subtracting
                                          ? theme.colorScheme.error
                                          : Colors.lightBlue.shade400,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: _subtracting
                                              ? Colors.white
                                              : onBg.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Icon(
                                          Icons.add,
                                          size: 14,
                                          color: !_subtracting
                                              ? Colors.white
                                              : onBg.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'Target  $targetMl ml',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onBg.withValues(alpha: 0.7),
                    ),
                  ),
                  if (!widget.isLocked && vessels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: vessels
                          .map(
                            (v) => _VesselChip(
                              vessel: v,
                              onTap: () => _subtracting
                                  ? diary.removeWaterMl(v.ml)
                                  : diary.addWaterMl(v.ml),
                              color: chipColor,
                            ),
                          )
                          .toList(),
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
  final Color color;

  const _VesselChip({
    required this.vessel,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vessel.isSvgIcon && vessel.svgAsset != null)
              SvgPicture.asset(
                vessel.svgAsset!,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
            else
              Icon(vessel.icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              vessel.ml >= 1000 ? '${vessel.ml ~/ 1000}L' : '${vessel.ml}ml',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
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
  final int changeToken;
  final void Function(DateTime) onDateSelected;
  const _WeekStrip({
    required this.selectedDate,
    required this.changeToken,
    required this.onDateSelected,
  });

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
    if (_weekStart(widget.selectedDate) != _weekStart(old.selectedDate) ||
        widget.changeToken != old.changeToken) {
      _load();
    }
  }

  DateTime _weekStart(DateTime d) {
    final weekday = d.weekday; // 1=Mon … 7=Sun
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(Duration(days: weekday - 1));
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
            final isFuture = date.isAfter(
              DateTime(today.year, today.month, today.day),
            );

            return GestureDetector(
              onTap: isFuture ? null : () => widget.onDateSelected(date),
              child: Container(
                width: 30,
                height: 30,
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
                child: Center(
                  child: Text(
                    dayLetters[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: (isSelected || isToday)
                          ? FontWeight.bold
                          : null,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : (hasData || isToday)
                          ? theme.colorScheme.primary
                          : isFuture
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.35,
                            )
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _EnergyBalanceLine extends StatelessWidget {
  final double intake;
  final int expenditure;
  final double? deficit;
  final Color mutedColor;
  final Color valueColor;

  const _EnergyBalanceLine({
    required this.intake,
    required this.expenditure,
    required this.deficit,
    required this.mutedColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenditureSet = expenditure > 0;
    final inSurplus = (deficit ?? 0) < 0;
    final deficitColor = !expenditureSet
        ? mutedColor
        : inSurplus
        ? theme.colorScheme.error
        : Colors.lightGreen.shade700;

    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: mutedColor);
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      color: valueColor,
      fontWeight: FontWeight.w700,
    );

    Widget cell(String label, String value, {Color? color}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 2),
        Text(value, style: valueStyle?.copyWith(color: color)),
      ],
    );

    return Row(
      children: [
        Expanded(child: cell('In', intake.toStringAsFixed(0))),
        Expanded(
          child: cell('Out', expenditureSet ? '$expenditure' : '—'),
        ),
        Expanded(
          child: cell(
            inSurplus ? 'Surplus' : 'Deficit',
            expenditureSet ? deficit!.abs().toStringAsFixed(0) : '—',
            color: deficitColor,
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
  const _MacroBar({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

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
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                    ],
                  )
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

  Widget _macroLabel(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          '${value.toStringAsFixed(0)}g $label',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
