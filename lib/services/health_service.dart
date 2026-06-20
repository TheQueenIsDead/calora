import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

class HealthService {
  HealthService._();
  static final instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.WORKOUT,
    // The package's WORKOUT read also queries Distance + Steps internally.
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.STEPS,
  ];

  // Read-only integration; derived from _types so adding a type can't drift.
  static final List<HealthDataAccess> _access = List.filled(
    _types.length,
    HealthDataAccess.READ,
  );

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> isAvailable() async {
    if (!defaultTargetPlatform.supportsHealthConnect) return false;
    await _ensureConfigured();
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  Future<bool> hasPermissions() async {
    await _ensureConfigured();
    return await _health.hasPermissions(_types, permissions: _access) ?? false;
  }

  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    return await _health.requestAuthorization(_types, permissions: _access);
  }


  Future<double?> getLatestWeightKg() =>
      _getLatestNumeric(HealthDataType.WEIGHT);

  /// Returns weight history (kg) sorted by date ascending, going back [days].
  Future<List<HcWeightPoint>> getWeightHistoryKg({int days = 365}) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: start,
        endTime: now,
      );
      final out = <HcWeightPoint>[];
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) {
          out.add(HcWeightPoint(date: p.dateTo, kg: v.numericValue.toDouble()));
        }
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      debugPrint(
        '[HealthService] weight history last $days days: ${out.length} point(s)',
      );
      return out;
    } catch (e, st) {
      debugPrint('[HealthService] weight history error: $e\n$st');
      return const [];
    }
  }

  /// HC stores HEIGHT in metres; we convert to cm here.
  Future<int?> getLatestHeightCm() async {
    final m = await _getLatestNumeric(HealthDataType.HEIGHT);
    if (m == null) return null;
    return (m * 100).round();
  }

  /// HC may write BMR (BasalEnergyBurned) at a high rate from wearables, so
  /// we bound the lookup window — pulling the full history every 5-min tick
  /// would be wasteful.
  Future<int?> getLatestBmrKcal() async {
    final v = await _getLatestNumeric(
      HealthDataType.BASAL_ENERGY_BURNED,
      start: DateTime.now().subtract(const Duration(days: 30)),
    );
    return v?.round();
  }

  /// Returns the most recent numeric value of [type] in HC's record store.
  /// Defaults to scanning from the Unix epoch — fine for sporadic series
  /// (height, weight) but callers should pass an explicit [start] for series
  /// HC writes frequently.
  Future<double?> _getLatestNumeric(
    HealthDataType type, {
    DateTime? start,
  }) async {
    await _ensureConfigured();
    final now = DateTime.now();
    start ??= DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: now,
      );
      debugPrint(
        '[HealthService] ${type.name} latest: ${points.length} record(s) found',
      );
      if (points.isEmpty) return null;
      points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final v = points.first.value;
      if (v is NumericHealthValue) {
        debugPrint(
          '[HealthService] ${type.name} latest value: ${v.numericValue} (at ${points.first.dateTo})',
        );
        return v.numericValue.toDouble();
      }
      debugPrint('[HealthService] ${type.name} latest value not numeric: $v');
      return null;
    } catch (e, st) {
      debugPrint('[HealthService] ${type.name} read error: $e\n$st');
      return null;
    }
  }

  /// Returns workouts and ambient active calories for [date]. Each workout's
  /// activeKcal is the sum of ACTIVE_ENERGY_BURNED records whose midpoint
  /// falls inside its time window — i.e. true active burn from HC, with no
  /// basal double-count. Ambient is the remainder of the day's active not
  /// claimed by any workout. totalActiveKcal is the day's full active sum.
  Future<HcDailyActivity> getActivityForDay(DateTime date) async {
    await _ensureConfigured();
    final start = DateTime(date.year, date.month, date.day);
    final dayEnd = start.add(const Duration(days: 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final queryEnd = start.isAtSameMomentAs(today) ? now : dayEnd;
    final dateStr = start.toIso8601String().substring(0, 10);
    try {
      // Two HC reads in parallel — workouts and active calorie records for
      // the day. We attribute each active record to its enclosing workout
      // (by midpoint) or fall back to ambient.
      final reads = await Future.wait([
        _health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: start,
          endTime: queryEnd,
        ),
        _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: start,
          endTime: queryEnd,
        ),
      ]);
      final workoutPoints = reads[0];
      final activePoints = reads[1];

      // Build the workouts list, filtered to those whose midpoint lands
      // in this day so midnight-crossing sessions count once.
      final workouts = <_MutableWorkout>[];
      for (final p in workoutPoints) {
        final v = p.value;
        if (v is! WorkoutHealthValue) continue;
        final mid = _midpoint(p.dateFrom, p.dateTo);
        if (mid.isBefore(start) || !mid.isBefore(dayEnd)) continue;
        workouts.add(
          _MutableWorkout(
            activityType: v.workoutActivityType,
            totalKcal: v.totalEnergyBurned,
            start: p.dateFrom,
            end: p.dateTo,
          ),
        );
      }
      workouts.sort((a, b) => a.start.compareTo(b.start));

      // Attribute each active record. Midpoint-in-window keeps a single
      // record from being split across two buckets.
      var ambient = 0.0;
      var totalActive = 0.0;
      for (final p in activePoints) {
        final v = p.value;
        if (v is! NumericHealthValue) continue;
        final kcal = v.numericValue.toDouble();
        totalActive += kcal;
        final mid = _midpoint(p.dateFrom, p.dateTo);
        final w = workouts.firstWhereOrNull(
          (w) => !mid.isBefore(w.start) && mid.isBefore(w.end),
        );
        if (w != null) {
          w.activeKcal += kcal;
        } else {
          ambient += kcal;
        }
      }

      debugPrint(
        '[HealthService] activity $dateStr: ${workouts.length} workout(s), '
        '${totalActive.round()} kcal active total '
        '(${ambient.round()} ambient)',
      );

      return HcDailyActivity(
        workouts: workouts
            .map((w) => HcWorkout(
                  activityType: w.activityType,
                  activeKcal: w.activeKcal.round(),
                  totalKcal: w.totalKcal,
                  start: w.start,
                  end: w.end,
                ))
            .toList(growable: false),
        ambientKcal: ambient.round(),
        totalActiveKcal: totalActive.round(),
      );
    } catch (e, st) {
      debugPrint('[HealthService] activity error: $e\n$st');
      return const HcDailyActivity(
        workouts: [],
        ambientKcal: 0,
        totalActiveKcal: 0,
      );
    }
  }

  static DateTime _midpoint(DateTime a, DateTime b) =>
      a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));

  /// Opens Health Connect's permission management screen for this app, so
  /// users can grant types we can't re-prompt for (HC's two-strike policy).
  Future<void> openHealthConnectPermissions() async {
    const channel = MethodChannel('nz.calora.calora/health');
    try {
      await channel.invokeMethod<void>('openHealthPermissions');
    } catch (e) {
      debugPrint('[HealthService] openHealthConnectPermissions failed: $e');
    }
  }
}

extension on TargetPlatform {
  bool get supportsHealthConnect => this == TargetPlatform.android;
}

class HcWeightPoint {
  final DateTime date;
  final double kg;
  const HcWeightPoint({required this.date, required this.kg});
}

class HcWorkout {
  final HealthWorkoutActivityType activityType;

  /// Sum of ACTIVE_ENERGY_BURNED records whose midpoint fell inside this
  /// workout's window. Excludes basal — safe to add on top of BMR.
  final int activeKcal;

  /// HC's own ExerciseSession.totalEnergyBurned (basal + active for the
  /// workout window). Surfaced only as a display fallback when no
  /// matching ACTIVE_ENERGY_BURNED records were written by the source.
  final int? totalKcal;

  final DateTime start;
  final DateTime end;

  const HcWorkout({
    required this.activityType,
    required this.activeKcal,
    required this.totalKcal,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);
}

class HcDailyActivity {
  final List<HcWorkout> workouts;
  final int ambientKcal;
  final int totalActiveKcal;

  const HcDailyActivity({
    required this.workouts,
    required this.ambientKcal,
    required this.totalActiveKcal,
  });
}

/// Internal accumulator while attributing active records to workouts.
class _MutableWorkout {
  final HealthWorkoutActivityType activityType;
  final int? totalKcal;
  final DateTime start;
  final DateTime end;
  double activeKcal = 0;

  _MutableWorkout({
    required this.activityType,
    required this.totalKcal,
    required this.start,
    required this.end,
  });
}

extension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}