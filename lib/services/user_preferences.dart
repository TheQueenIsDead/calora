import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_vessel.dart';

class UserPreferences {
  UserPreferences._();
  static final instance = UserPreferences._();

  // ── Goal ─────────────────────────────────────────────────────────────────

  Future<int> getDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_goal') ?? 2000;
  }

  Future<void> setDailyGoal(int calories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_goal', calories);
  }

  // ── Water ─────────────────────────────────────────────────────────────────

  Future<int> getWaterTargetMl() async {
    final prefs = await SharedPreferences.getInstance();
    final oldTarget = prefs.getInt('water_target');
    if (oldTarget != null) {
      final ml = oldTarget * 250;
      await prefs.setInt('water_target_ml', ml);
      await prefs.remove('water_target');
      return ml;
    }
    return prefs.getInt('water_target_ml') ?? 2000;
  }

  Future<void> setWaterTargetMl(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_target_ml', ml);
  }

  Future<int> getWaterMlForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'water_ml_${date.toIso8601String().substring(0, 10)}';
    final oldKey = 'water_${date.toIso8601String().substring(0, 10)}';
    final oldCups = prefs.getInt(oldKey);
    if (oldCups != null && oldCups > 0) {
      final ml = oldCups * 250;
      await prefs.setInt(key, ml);
      await prefs.remove(oldKey);
      return ml;
    }
    return prefs.getInt(key) ?? 0;
  }

  Future<void> setWaterMlForDate(DateTime date, int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'water_ml_${date.toIso8601String().substring(0, 10)}', ml);
  }

  // ── Vessels ───────────────────────────────────────────────────────────────

  Future<List<WaterVessel>> getVessels() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('water_vessels');
    if (json == null) return WaterVessel.defaults;
    final list = jsonDecode(json) as List;
    return list
        .map((j) => WaterVessel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> setVessels(List<WaterVessel> vessels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'water_vessels', jsonEncode(vessels.map((v) => v.toJson()).toList()));
  }

  // ── BMR / TDEE ────────────────────────────────────────────────────────────

  Future<int> getBmr() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('bmr_value') ?? 0;
  }

  Future<void> setBmr(int bmr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bmr_value', bmr);
  }

  Future<int> getTdee() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tdee_value') ?? 0;
  }

  Future<void> setTdee(int tdee) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tdee_value', tdee);
  }

  // ── Day lock ──────────────────────────────────────────────────────────────

  Future<bool> getLockState(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final todayStr =
        DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);
    final isPast = dateStr.compareTo(todayStr) < 0;
    return prefs.getBool('locked_$dateStr') ?? isPast;
  }

  Future<void> setLockState(DateTime date, bool locked) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final todayStr =
        DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);
    final naturalDefault = dateStr.compareTo(todayStr) < 0;
    if (locked == naturalDefault) {
      await prefs.remove('locked_$dateStr');
    } else {
      await prefs.setBool('locked_$dateStr', locked);
    }
  }
}
