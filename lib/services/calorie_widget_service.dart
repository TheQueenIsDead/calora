import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/calorie_ring.dart';

class CalorieWidgetService {
  CalorieWidgetService._();
  static final instance = CalorieWidgetService._();

  static const _androidWidget = 'CalorieWidgetProvider';

  Future<void> initialize(DiaryProvider diary, SettingsProvider settings) async {
    await _push(diary, settings);
    diary.addListener(() => _push(diary, settings));
    settings.addListener(() => _push(diary, settings));
  }

  Future<void> _push(DiaryProvider diary, SettingsProvider settings) async {
    final total    = diary.totalCalories;
    final goal     = diary.dailyGoal;
    final tdee     = settings.tdee;
    final progress = (goal > 0 ? total / goal : 0.0).clamp(0.0, 1.0);
    final hasTdee  = tdee > 0;

    final Color ringColor;
    if (hasTdee && total > tdee) {
      ringColor = const Color(0xFFEF5350);
    } else if (total > goal) {
      ringColor = Colors.amber;
    } else {
      ringColor = const Color(0xFF42C750);
    }

    final deficit = hasTdee ? tdee - total.round() : null;
    final remaining = goal - total.round();

    try {
      await HomeWidget.renderFlutterWidget(
        _CalorieRingBitmap(
          progress: progress,
          remaining: remaining,
          deficit: deficit,
          color: ringColor,
        ),
        logicalSize: const Size(100, 110),
        key: 'calorie_ring_path',
      );
    } catch (_) {}

    await HomeWidget.updateWidget(androidName: _androidWidget);
  }
}

/// Self-contained widget rendered to PNG — uses explicit colors so it
/// doesn't depend on a Theme being present.
class _CalorieRingBitmap extends StatelessWidget {
  final double progress;
  final int remaining;
  final int? deficit;
  final Color color;

  const _CalorieRingBitmap({
    required this.progress,
    required this.remaining,
    required this.deficit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final deficitText = deficit == null
        ? null
        : deficit! >= 0
            ? '−$deficit kcal'
            : '+${-deficit!} kcal';

    // Transparent background so the circular widget bg shows through.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 110,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CalorieRing(
              progress: progress,
              size: 80,
              label: remaining.abs().toString(),
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              labelColor: Colors.white,
            ),
            if (deficitText != null) ...[
              const SizedBox(height: 2),
              Text(
                deficitText,
                style: const TextStyle(
                  color: Color(0xFF9EAAB5),
                  fontSize: 9,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
