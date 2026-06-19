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
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.WORKOUT,
    // The package's WORKOUT read also queries Distance + Steps internally.
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.STEPS,
  ];

  static const List<HealthDataAccess> _access = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

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

  /// Returns (active, total) kcal for [date]. Either or both may be null
  /// if the data type isn't populated in Health Connect. Callers prefer
  /// total when present (it already includes basal + active), otherwise
  /// add active onto a separately-computed BMR.
  Future<({int? active, int? total})> getCaloriesForDay(DateTime date) async {
    await _ensureConfigured();
    final start = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = start.isAtSameMomentAs(today)
        ? now
        : start.add(const Duration(days: 1));
    final dateStr = start.toIso8601String().substring(0, 10);
    final active = await _sumKcal(
      HealthDataType.ACTIVE_ENERGY_BURNED,
      start,
      end,
      dateStr,
    );
    final total = await _sumKcal(
      HealthDataType.TOTAL_CALORIES_BURNED,
      start,
      end,
      dateStr,
    );
    return (active: active, total: total);
  }

  Future<int?> _sumKcal(
    HealthDataType type,
    DateTime start,
    DateTime end,
    String dateStr,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      var total = 0.0;
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) {
          total += v.numericValue.toDouble();
        }
      }
      debugPrint(
        '[HealthService] ${type.name} $dateStr: '
        '${points.length} point(s), total ${total.round()} kcal',
      );
      return total.round();
    } catch (e, st) {
      debugPrint('[HealthService] ${type.name} error: $e\n$st');
      return null;
    }
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

  Future<List<HcWorkout>> getWorkoutsForDay(DateTime date) async {
    await _ensureConfigured();
    final start = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = start.isAtSameMomentAs(today)
        ? now
        : start.add(const Duration(days: 1));
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );
      final workouts = <HcWorkout>[];
      for (final p in points) {
        final v = p.value;
        if (v is WorkoutHealthValue) {
          workouts.add(
            HcWorkout(
              activityType: v.workoutActivityType,
              kcal: v.totalEnergyBurned,
              start: p.dateFrom,
              end: p.dateTo,
            ),
          );
        }
      }
      workouts.sort((a, b) => a.start.compareTo(b.start));
      debugPrint(
        '[HealthService] workouts ${start.toIso8601String().substring(0, 10)}: '
        '${workouts.length} workout(s)',
      );
      return workouts;
    } catch (e, st) {
      debugPrint('[HealthService] workouts error: $e\n$st');
      return const [];
    }
  }

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
  final int? kcal;
  final DateTime start;
  final DateTime end;

  const HcWorkout({
    required this.activityType,
    required this.kcal,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);
}