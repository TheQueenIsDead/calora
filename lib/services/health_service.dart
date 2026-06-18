import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthService {
  HealthService._();
  static final instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  static const List<HealthDataAccess> _access = [
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

  Future<int?> getActiveCaloriesToday() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );
      var total = 0.0;
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) {
          total += v.numericValue.toDouble();
        }
      }
      return total.round();
    } catch (_) {
      return null;
    }
  }

  Future<double?> getLatestWeightKg() => _getLatestNumeric(HealthDataType.WEIGHT);

  /// Health Connect stores HEIGHT in metres; we convert to cm here.
  Future<int?> getLatestHeightCm() async {
    final m = await _getLatestNumeric(HealthDataType.HEIGHT);
    if (m == null) return null;
    return (m * 100).round();
  }

  Future<double?> _getLatestNumeric(HealthDataType type) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: now,
      );
      if (points.isEmpty) return null;
      points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final v = points.first.value;
      if (v is NumericHealthValue) return v.numericValue.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }
}

extension on TargetPlatform {
  bool get supportsHealthConnect => this == TargetPlatform.android;
}