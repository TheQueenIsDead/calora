import 'package:flutter/material.dart';
import 'dart:math' as math;

class CalorieRing extends StatelessWidget {
  final double progress;
  final bool isOver;
  final double size;

  /// Override the centre label. Defaults to the percentage string. Ignored
  /// when [centerChild] is set.
  final String? label;

  /// Custom widget rendered inside the ring. Wins over [label].
  final Widget? centerChild;

  /// Override the ring fill colour. Defaults to primary / error.
  final Color? color;

  /// Override the centre text colour. Defaults to onPrimaryContainer.
  final Color? labelColor;

  /// Override the ring background colour.
  final Color? backgroundColor;

  const CalorieRing({
    super.key,
    required this.progress,
    this.isOver = false,
    this.size = 90,
    this.label,
    this.centerChild,
    this.color,
    this.labelColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor =
        color ?? (isOver ? theme.colorScheme.error : theme.colorScheme.primary);
    final bgColor =
        backgroundColor ??
        theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15);
    final textColor = labelColor ?? theme.colorScheme.onPrimaryContainer;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: ringColor,
          backgroundColor: bgColor,
        ),
        child: Center(
          child: centerChild ??
              Text(
                label ?? '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.shortestSide - 12) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
