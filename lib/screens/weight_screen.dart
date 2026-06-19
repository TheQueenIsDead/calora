import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/health_service.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<HcWeightPoint> _points = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.read<SettingsProvider>().useHealthConnect) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final points = await HealthService.instance.getWeightHistoryKg(days: 365);
    if (mounted) {
      setState(() {
        _points = points;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useHc = context.watch<SettingsProvider>().useHealthConnect;
    return Scaffold(
      appBar: AppBar(title: const Text('Weight')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (!useHc)
                    const _HealthConnectEmpty()
                  else if (_points.length < 2)
                    const _NoDataEmpty()
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                bottom: 12,
                              ),
                              child: Text(
                                'Weight — last year',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            SizedBox(
                              height: 200,
                              child: _WeightLineChart(points: _points),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          for (int i = _points.length - 1; i >= 0; i--) ...[
                            if (i < _points.length - 1)
                              const Divider(height: 1, indent: 16),
                            _WeightTile(
                              point: _points[i],
                              prev: i > 0 ? _points[i - 1] : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _HealthConnectEmpty extends StatelessWidget {
  const _HealthConnectEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.scale_outlined,
            size: 48,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Weight is sourced from Health Connect.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Enable Health Connect in Settings to see your weight history.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoDataEmpty extends StatelessWidget {
  const _NoDataEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.scale_outlined,
            size: 48,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No weight data in Health Connect yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Log weight from your scale, Fit, or another connected app.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightTile extends StatelessWidget {
  final HcWeightPoint point;
  final HcWeightPoint? prev;

  const _WeightTile({required this.point, required this.prev});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = prev != null ? point.kg - prev!.kg : null;
    final deltaStr = delta == null
        ? null
        : delta >= 0
        ? '+${delta.toStringAsFixed(1)} kg'
        : '${delta.toStringAsFixed(1)} kg';
    final deltaColor = delta == null
        ? null
        : delta > 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return ListTile(
      title: Text('${point.kg.toStringAsFixed(1)} kg'),
      subtitle: Text(DateFormat('EEE, d MMM y').format(point.date)),
      trailing: deltaStr == null
          ? null
          : Text(
              deltaStr,
              style: theme.textTheme.bodySmall?.copyWith(color: deltaColor),
            ),
    );
  }
}

// ── Date-based line chart ────────────────────────────────────────────────────

class _WeightLineChart extends StatelessWidget {
  final List<HcWeightPoint> points;
  const _WeightLineChart({required this.points});

  static double _epochDays(DateTime d) =>
      d.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstX = _epochDays(points.first.date);
    final lastX = _epochDays(points.last.date);
    final spots = points
        .map((p) => FlSpot(_epochDays(p.date) - firstX, p.kg))
        .toList();
    final kgValues = points.map((p) => p.kg);
    final minY = (kgValues.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = (kgValues.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();
    final spanDays = (lastX - firstX).clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: spanDays,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: theme.colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: points.length <= 30,
              getDotPainter: (spot, xPercentage, bar, barIndex) =>
                  FlDotCirclePainter(
                    radius: 3,
                    color: theme.colorScheme.primary,
                    strokeWidth: 0,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(0.5, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                '${v.toStringAsFixed(0)} kg',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (spanDays / 3).clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  ((firstX + v) * Duration.millisecondsPerDay).round(),
                  isUtc: true,
                ).toLocal();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d MMM').format(date),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              final date = DateTime.fromMillisecondsSinceEpoch(
                ((firstX + s.x) * Duration.millisecondsPerDay).round(),
                isUtc: true,
              ).toLocal();
              return LineTooltipItem(
                '${DateFormat('d MMM').format(date)}\n'
                '${s.y.toStringAsFixed(1)} kg',
                theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              );
            }).toList(),
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }
}

// ── Embeddable card for TrendsScreen ─────────────────────────────────────────

class WeightChartCard extends StatefulWidget {
  const WeightChartCard({super.key});

  @override
  State<WeightChartCard> createState() => _WeightChartCardState();
}

class _WeightChartCardState extends State<WeightChartCard> {
  List<HcWeightPoint> _points = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.read<SettingsProvider>().useHealthConnect) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final points = await HealthService.instance.getWeightHistoryKg(days: 90);
    if (mounted) {
      setState(() {
        _points = points;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useHc = context.watch<SettingsProvider>().useHealthConnect;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: _loading
            ? const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Weight',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WeightScreen(),
                            ),
                          ).then((_) => _load()),
                          child: const Text('History'),
                        ),
                      ],
                    ),
                  ),
                  if (!useHc)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Text(
                        'Enable Health Connect in Settings to track weight.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else if (_points.length < 2)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Text(
                        'Add at least 2 weight entries in Health Connect to see your trend.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: _WeightLineChart(points: _points),
                    ),
                ],
              ),
      ),
    );
  }
}
