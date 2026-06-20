import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../services/user_preferences.dart';

class CalorieWidgetService {
  CalorieWidgetService._();
  static final instance = CalorieWidgetService._();

  // Fully qualified so home_widget resolves the class in the namespace package,
  // not the (potentially `.debug`-suffixed) applicationId. Passed via
  // `qualifiedAndroidName`, which skips the packageName prefix.
  static const _androidWidget = 'nz.calora.calora.CalorieWidgetProvider';

  Future<void> initialize(
    DiaryProvider diary,
    SettingsProvider settings,
  ) async {
    await _push(settings);
    diary.addListener(() => _push(settings));
    settings.addListener(() => _push(settings));
  }

  /// Always pushes TODAY's calories to the widget, even if the diary
  /// provider is currently displaying a past day. Reads straight from
  /// SQLite so the widget never reflects historical navigation.
  Future<void> _push(SettingsProvider settings) async {
    final today = DateTime.now();
    final entries = await DatabaseService.instance.getEntriesForDate(today);
    final total = entries.fold<double>(0, (s, e) => s + e.calories);
    final goal = await DatabaseService.instance.getEffectiveGoal(today) ??
        await UserPreferences.instance.getDailyGoal();
    final tdee = settings.tdee;
    final progress = (goal > 0 ? total / goal : 0.0).clamp(0.0, 1.0);
    final hasTdee = tdee > 0;

    final Color ringColor;
    if (hasTdee && total > tdee) {
      ringColor = const Color(0xFFEF5350);
    } else if (total > goal) {
      ringColor = Colors.amber;
    } else {
      ringColor = const Color(0xFF42C750);
    }

    try {
      await HomeWidget.renderFlutterWidget(
        _CalorieRingBitmap(
          progress: progress,
          total: total.round(),
          color: ringColor,
        ),
        logicalSize: const Size(110, 110),
        key: 'calorie_ring_path',
      );
    } catch (_) {}

    await HomeWidget.updateWidget(qualifiedAndroidName: _androidWidget);
  }
}

/// Self-contained widget rendered to PNG via a single CustomPainter pass:
/// dark circle background → ring track → progress arc → text.
/// More reliable than ClipOval for offscreen renderFlutterWidget rendering.
class _CalorieRingBitmap extends StatelessWidget {
  final double progress;
  final int total;
  final Color color;

  const _CalorieRingBitmap({
    required this.progress,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CustomPaint(
        size: const Size(110, 110),
        painter: _CalorieWidgetPainter(
          progress: progress,
          total: total,
          color: color,
        ),
      ),
    );
  }
}

class _CalorieWidgetPainter extends CustomPainter {
  final double progress;
  final int total;
  final Color color;

  _CalorieWidgetPainter({
    required this.progress,
    required this.total,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.shortestSide / 2;

    // Dark circle background
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..color = const Color(0xFF1E2124),
    );

    // Ring track
    final ringRadius = radius * 0.72;
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = size.width * 0.09
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), ringRadius, trackPaint);

    // Progress arc
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: ringRadius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );

    // Calories label
    final totalSpan = TextSpan(
      text: total.toString(),
      style: TextStyle(
        color: Colors.white,
        fontSize: size.width * 0.2,
        fontWeight: FontWeight.bold,
        height: 1.1,
      ),
    );
    final totalPainter = TextPainter(
      text: totalSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    totalPainter.paint(
      canvas,
      Offset(cx - totalPainter.width / 2, cy - totalPainter.height * 0.65),
    );

    // "kcal" sublabel
    final kcalSpan = TextSpan(
      text: 'kcal',
      style: TextStyle(
        color: const Color(0xFF9EAAB5),
        fontSize: size.width * 0.1,
        height: 1,
      ),
    );
    final kcalPainter = TextPainter(
      text: kcalSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    kcalPainter.paint(
      canvas,
      Offset(cx - kcalPainter.width / 2, cy + totalPainter.height * 0.15),
    );
  }

  @override
  bool shouldRepaint(_CalorieWidgetPainter old) =>
      old.progress != progress || old.total != total || old.color != color;
}
