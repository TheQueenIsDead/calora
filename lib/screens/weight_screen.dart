import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weight_entry.dart';
import '../services/database_service.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  List<WeightEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseService.instance.getWeightHistory(days: 365);
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _logWeight() async {
    final controller = TextEditingController();
    final latest = _entries.isNotEmpty ? _entries.last.kg : null;
    if (latest != null) controller.text = latest.toStringAsFixed(1);

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0.0', suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final kg = double.tryParse(controller.text.trim());
              if (kg != null && kg > 0) Navigator.pop(ctx, kg);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    await DatabaseService.instance.saveWeight(DateTime.now(), result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logWeight,
        icon: const Icon(Icons.add),
        label: const Text('Log weight'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  if (_entries.length >= 2) ...[
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
                              child: _WeightLineChart(entries: _entries),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          'No weight entries yet.\nTap + to log your first.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (int i = _entries.length - 1; i >= 0; i--) ...[
                            if (i < _entries.length - 1)
                              const Divider(height: 1, indent: 16),
                            _WeightTile(
                              entry: _entries[i],
                              prev: i > 0 ? _entries[i - 1] : null,
                              onDelete: () async {
                                await DatabaseService.instance.deleteWeight(
                                  _entries[i].id,
                                );
                                await _load();
                              },
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

class _WeightTile extends StatelessWidget {
  final WeightEntry entry;
  final WeightEntry? prev;
  final VoidCallback onDelete;

  const _WeightTile({
    required this.entry,
    required this.prev,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = prev != null ? entry.kg - prev!.kg : null;
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
      title: Text('${entry.kg.toStringAsFixed(1)} kg'),
      subtitle: Text(DateFormat('EEE, d MMM y').format(entry.date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (deltaStr != null)
            Text(
              deltaStr,
              style: theme.textTheme.bodySmall?.copyWith(color: deltaColor),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Shared line chart (no Card wrapper) ──────────────────────────────────────

class _WeightLineChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _WeightLineChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.kg))
        .toList();

    final minY = (entries.map((e) => e.kg).reduce((a, b) => a < b ? a : b) - 2)
        .floorToDouble();
    final maxY = (entries.map((e) => e.kg).reduce((a, b) => a > b ? a : b) + 2)
        .ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: theme.colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: entries.length <= 30,
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
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                final step = ((entries.length - 1) / 3).ceil().clamp(1, 999);
                if (idx % step != 0 && idx != entries.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d MMM').format(entries[idx].date),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final idx = s.x.toInt();
              if (idx < 0 || idx >= entries.length) return null;
              final entry = entries[idx];
              return LineTooltipItem(
                '${DateFormat('d MMM').format(entry.date)}\n'
                '${entry.kg.toStringAsFixed(1)} kg',
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
  List<WeightEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DatabaseService.instance.getWeightHistory(days: 90);
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _logWeight() async {
    final controller = TextEditingController();
    final latest = _entries.isNotEmpty ? _entries.last.kg : null;
    if (latest != null) controller.text = latest.toStringAsFixed(1);

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0.0', suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final kg = double.tryParse(controller.text.trim());
              if (kg != null && kg > 0) Navigator.pop(ctx, kg);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    await DatabaseService.instance.saveWeight(DateTime.now(), result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        TextButton.icon(
                          onPressed: _logWeight,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Log'),
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
                  if (_entries.length < 2)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      child: Text(
                        'Log at least 2 entries to see your weight trend.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: _WeightLineChart(entries: _entries),
                    ),
                ],
              ),
      ),
    );
  }
}
