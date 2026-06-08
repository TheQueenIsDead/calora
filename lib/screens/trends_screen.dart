import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/diary_provider.dart';
import '../services/database_service.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  static const _days = 30;
  Map<String, double> _dailyCalories = {};
  Map<String, int> _dailyGoals = {};
  Map<String, Map<String, double>> _dailyMacros = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: _days - 1));
    final fallback = context.read<DiaryProvider>().currentGoal;
    final results = await Future.wait([
      DatabaseService.instance.getDailyCalories(from, to),
      DatabaseService.instance.getDailyGoals(from, to, fallback),
      DatabaseService.instance.getDailyMacros(from, to),
    ]);
    if (mounted) {
      setState(() {
        _dailyCalories = results[0] as Map<String, double>;
        _dailyGoals = results[1] as Map<String, int>;
        _dailyMacros = results[2] as Map<String, Map<String, double>>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CalorieChart(
                    dailyCalories: _dailyCalories,
                    dailyGoals: _dailyGoals,
                    days: _days,
                  ),
                  const SizedBox(height: 16),
                  _MacroChart(dailyMacros: _dailyMacros, days: _days),
                  const SizedBox(height: 16),
                  _SummaryStats(
                    dailyCalories: _dailyCalories,
                    dailyGoals: _dailyGoals,
                    dailyMacros: _dailyMacros,
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Calorie chart ────────────────────────────────────────────────────────────

class _CalorieChart extends StatelessWidget {
  final Map<String, double> dailyCalories;
  final Map<String, int> dailyGoals;
  final int days;

  const _CalorieChart({
    required this.dailyCalories,
    required this.dailyGoals,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final goalColor = theme.colorScheme.tertiary;

    final bars = <BarChartGroupData>[];
    final goalSpots = <FlSpot>[];
    double maxY = 0;
    double? prevGoal;

    for (var i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: days - 1 - i));
      final key = date.toIso8601String().substring(0, 10);
      final kcal = dailyCalories[key] ?? 0;
      final dayGoal = (dailyGoals[key] ?? 2000).toDouble();
      if (kcal > maxY) maxY = kcal;
      if (dayGoal > maxY) maxY = dayGoal;

      final isOver = kcal > dayGoal;
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: kcal,
            color: kcal == 0
                ? theme.colorScheme.outlineVariant
                : isOver
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      ));

      // Step function: insert a point at the old goal just before a change
      if (prevGoal != null && prevGoal != dayGoal) {
        goalSpots.add(FlSpot(i - 0.001, prevGoal));
      }
      goalSpots.add(FlSpot(i.toDouble(), dayGoal));
      prevGoal = dayGoal;
    }

    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 2400;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Calories — last $days days',
                        style: theme.textTheme.titleMedium),
                  ),
                  Container(
                    width: 16,
                    height: 2,
                    color: goalColor,
                  ),
                  const SizedBox(width: 4),
                  Text('Goal',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  BarChart(
                    BarChartData(
                      maxY: maxY,
                      barGroups: bars,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: _titlesData(theme, today),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, _) {
                            final date = today
                                .subtract(Duration(days: days - 1 - group.x));
                            final key =
                                date.toIso8601String().substring(0, 10);
                            final goalVal = dailyGoals[key] ?? 2000;
                            return BarTooltipItem(
                              '${DateFormat('d MMM').format(date)}\n'
                              '${rod.toY.toStringAsFixed(0)} kcal  '
                              '(goal $goalVal)',
                              theme.textTheme.labelSmall!.copyWith(
                                  color: theme.colorScheme.onSurface),
                            );
                          },
                        ),
                      ),
                    ),
                    duration: Duration.zero,
                  ),
                  // Goal line overlay — IgnorePointer so bar touches pass through
                  IgnorePointer(
                    child: LineChart(
                      LineChartData(
                        // minX = -1, maxX = days aligns with BarChartAlignment.spaceEvenly
                        minX: -1,
                        maxX: days.toDouble(),
                        minY: 0,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: goalSpots,
                            isCurved: false,
                            color: goalColor,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            dashArray: [6, 4],
                          ),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (_, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (_, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                      duration: Duration.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  FlTitlesData _titlesData(ThemeData theme, DateTime today) => FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, _) => Text(
              '${(v / 1000).toStringAsFixed(1)}k',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final x = v.toInt();
              if (x % 7 != 0) return const SizedBox.shrink();
              final date = today.subtract(Duration(days: days - 1 - x));
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('d MMM').format(date),
                    style: theme.textTheme.labelSmall),
              );
            },
          ),
        ),
      );
}

// ── Macro chart ──────────────────────────────────────────────────────────────

class _MacroChart extends StatelessWidget {
  final Map<String, Map<String, double>> dailyMacros;
  final int days;

  const _MacroChart({required this.dailyMacros, required this.days});

  static const _proteinColor = Color(0xFF4CAF50);
  static const _fatColor = Color(0xFFFF9800);
  static const _carbsColor = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    final bars = <BarChartGroupData>[];
    double maxY = 0;

    for (var i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: days - 1 - i));
      final key = date.toIso8601String().substring(0, 10);
      final macros = dailyMacros[key];
      final protein = macros?['protein'] ?? 0;
      final fat = macros?['fat'] ?? 0;
      final carbs = macros?['carbs'] ?? 0;
      final total = protein + fat + carbs;
      if (total > maxY) maxY = total;

      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: total,
            width: 8,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(3)),
            rodStackItems: total == 0
                ? []
                : [
                    BarChartRodStackItem(0, protein, _proteinColor),
                    BarChartRodStackItem(
                        protein, protein + fat, _fatColor),
                    BarChartRodStackItem(
                        protein + fat, total, _carbsColor),
                  ],
            color: total == 0 ? theme.colorScheme.outlineVariant : null,
          ),
        ],
      ));
    }

    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 200;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text('Macros — last $days days',
                  style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16),
              child: Row(
                children: const [
                  _LegendDot(color: _proteinColor, label: 'Protein'),
                  SizedBox(width: 16),
                  _LegendDot(color: _fatColor, label: 'Fat'),
                  SizedBox(width: 16),
                  _LegendDot(color: _carbsColor, label: 'Carbs'),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: bars,
                  gridData: FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toStringAsFixed(0)}g',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final x = v.toInt();
                          if (x % 7 != 0) return const SizedBox.shrink();
                          final date = today
                              .subtract(Duration(days: days - 1 - x));
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(DateFormat('d MMM').format(date),
                                style: theme.textTheme.labelSmall),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) {
                        final date = today
                            .subtract(Duration(days: days - 1 - group.x));
                        final macros = dailyMacros[
                            date.toIso8601String().substring(0, 10)];
                        if (macros == null) return null;
                        return BarTooltipItem(
                          '${DateFormat('d MMM').format(date)}\n'
                          'P: ${macros['protein']!.toStringAsFixed(0)}g  '
                          'F: ${macros['fat']!.toStringAsFixed(0)}g  '
                          'C: ${macros['carbs']!.toStringAsFixed(0)}g',
                          theme.textTheme.labelSmall!.copyWith(
                              color: theme.colorScheme.onSurface),
                        );
                      },
                    ),
                  ),
                ),
                duration: Duration.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

// ── Summary stats ────────────────────────────────────────────────────────────

class _SummaryStats extends StatelessWidget {
  final Map<String, double> dailyCalories;
  final Map<String, int> dailyGoals;
  final Map<String, Map<String, double>> dailyMacros;

  const _SummaryStats({
    required this.dailyCalories,
    required this.dailyGoals,
    required this.dailyMacros,
  });

  @override
  Widget build(BuildContext context) {
    final logged =
        dailyCalories.entries.where((e) => e.value > 0).toList();
    final avgCal = logged.isEmpty
        ? 0.0
        : logged.map((e) => e.value).reduce((a, b) => a + b) / logged.length;

    int daysUnder = 0;
    int daysOver = 0;
    for (final e in logged) {
      final goal = dailyGoals[e.key] ?? 2000;
      if (e.value <= goal) {
        daysUnder++;
      } else {
        daysOver++;
      }
    }

    double avgProtein = 0, avgFat = 0, avgCarbs = 0;
    if (logged.isNotEmpty) {
      for (final e in logged) {
        final m = dailyMacros[e.key];
        if (m != null) {
          avgProtein += m['protein'] ?? 0;
          avgFat += m['fat'] ?? 0;
          avgCarbs += m['carbs'] ?? 0;
        }
      }
      avgProtein /= logged.length;
      avgFat /= logged.length;
      avgCarbs /= logged.length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _StatRow(label: 'Days logged', value: '${logged.length}'),
            _StatRow(
                label: 'Average calories',
                value: '${avgCal.toStringAsFixed(0)} kcal'),
            _StatRow(label: 'Days at or under goal', value: '$daysUnder'),
            _StatRow(label: 'Days over goal', value: '$daysOver'),
            if (logged.isNotEmpty) ...[
              const Divider(height: 24),
              _StatRow(
                  label: 'Avg protein',
                  value: '${avgProtein.toStringAsFixed(0)} g'),
              _StatRow(
                  label: 'Avg fat',
                  value: '${avgFat.toStringAsFixed(0)} g'),
              _StatRow(
                  label: 'Avg carbs',
                  value: '${avgCarbs.toStringAsFixed(0)} g'),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
