import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/diary_entry.dart';
import '../models/water_vessel.dart';
import '../services/database_service.dart';

class DiaryProvider extends ChangeNotifier {
  List<DiaryEntry> _entries = [];
  DateTime _selectedDate = DateTime.now();
  int _currentGoal = 2000;  // most recently set goal — used in settings
  int _dailyGoal = 2000;    // effective goal for _selectedDate — used in diary
  int _waterTargetMl = 2000;
  bool _loading = false;
  bool _isLocked = false;
  int _waterMl = 0;
  int _bmr = 0;
  int _tdee = 0;
  List<WaterVessel> _vessels = [];

  List<DiaryEntry> get entries => _entries;
  DateTime get selectedDate => _selectedDate;
  int get currentGoal => _currentGoal;
  int get dailyGoal => _dailyGoal;
  int get waterTargetMl => _waterTargetMl;
  bool get loading => _loading;
  bool get isLocked => _isLocked;
  int get waterMl => _waterMl;
  int get bmr => _bmr;
  int get tdee => _tdee;
  List<WaterVessel> get vessels => _vessels;
  double get waterProgress => _waterTargetMl > 0 ? (_waterMl / _waterTargetMl).clamp(0.0, 1.0) : 0.0;

  double get totalCalories => _entries.fold(0, (sum, e) => sum + e.calories);
  double get totalFat      => _entries.fold(0, (sum, e) => sum + e.fat);
  double get totalCarbs    => _entries.fold(0, (sum, e) => sum + e.carbs);
  double get totalProtein  => _entries.fold(0, (sum, e) => sum + e.protein);
  double get remainingCalories => _dailyGoal - totalCalories;
  double get progress => (_dailyGoal > 0 ? totalCalories / _dailyGoal : 0.0).clamp(0.0, 1.0);

  List<DiaryEntry> entriesForMeal(Meal meal) =>
      _entries.where((e) => e.meal == meal).toList();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentGoal = prefs.getInt('daily_goal') ?? 2000;
    // Migrate water target from cups to ml
    final oldTarget = prefs.getInt('water_target');
    if (oldTarget != null) {
      _waterTargetMl = oldTarget * 250;
      await prefs.setInt('water_target_ml', _waterTargetMl);
      await prefs.remove('water_target');
    } else {
      _waterTargetMl = prefs.getInt('water_target_ml') ?? 2000;
    }
    // Load vessels
    final vesselsJson = prefs.getString('water_vessels');
    if (vesselsJson != null) {
      final list = (jsonDecode(vesselsJson) as List);
      _vessels = list.map((j) => WaterVessel.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      _vessels = WaterVessel.defaults;
    }
    _bmr = prefs.getInt('bmr_value') ?? 0;
    _tdee = prefs.getInt('tdee_value') ?? 0;
    await loadDay(_selectedDate);
  }

  Future<void> loadDay(DateTime date) async {
    _loading = true;
    notifyListeners();
    _selectedDate = date;
    _entries = await DatabaseService.instance.getEntriesForDate(date);
    final prefs = await SharedPreferences.getInstance();
    // Migrate old cups-based water data
    final oldCups = prefs.getInt('water_${date.toIso8601String().substring(0, 10)}');
    if (oldCups != null && oldCups > 0) {
      _waterMl = oldCups * 250;
      await prefs.setInt('water_ml_${date.toIso8601String().substring(0, 10)}', _waterMl);
      await prefs.remove('water_${date.toIso8601String().substring(0, 10)}');
    } else {
      _waterMl = prefs.getInt('water_ml_${date.toIso8601String().substring(0, 10)}') ?? 0;
    }
    // Use recorded goal for this date; fall back to the current setting
    _dailyGoal =
        await DatabaseService.instance.getEffectiveGoal(date) ?? _currentGoal;
    // Lock state: past days locked by default; user override stored per day
    final dateStr = date.toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .substring(0, 10);
    final isPast = dateStr.compareTo(todayStr) < 0;
    _isLocked = prefs.getBool('locked_$dateStr') ?? isPast;
    _loading = false;
    notifyListeners();
  }

  Future<void> toggleLock() async {
    _isLocked = !_isLocked;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .substring(0, 10);
    final naturalDefault = dateStr.compareTo(todayStr) < 0;
    // Only persist when the user has overridden the natural default
    if (_isLocked == naturalDefault) {
      await prefs.remove('locked_$dateStr');
    } else {
      await prefs.setBool('locked_$dateStr', _isLocked);
    }
  }

  Future<void> addEntry(DiaryEntry entry) async {
    if (_isLocked) return;
    await DatabaseService.instance.addDiaryEntry(entry);
    await loadDay(_selectedDate);
  }

  Future<void> deleteEntry(String id) async {
    if (_isLocked) return;
    await DatabaseService.instance.deleteDiaryEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> moveEntry(String entryId, Meal newMeal) async {
    if (_isLocked) return;
    await DatabaseService.instance.updateEntryMeal(entryId, newMeal);
    await loadDay(_selectedDate);
  }

  Future<void> setDailyGoal(int calories) async {
    _currentGoal = calories;
    _dailyGoal = calories;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_goal', calories);
    await DatabaseService.instance.saveGoal(DateTime.now(), calories);
  }

  Future<void> setBmr(int bmr) async {
    _bmr = bmr;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bmr_value', bmr);
  }

  Future<void> setTdee(int tdee) async {
    _tdee = tdee;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tdee_value', tdee);
  }

  Future<void> addWaterMl(int ml) async {
    if (_isLocked) return;
    _waterMl = (_waterMl + ml).clamp(0, 99999);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_ml_${_selectedDate.toIso8601String().substring(0, 10)}', _waterMl);
  }

  Future<void> removeWaterMl(int ml) async {
    if (_isLocked) return;
    _waterMl = (_waterMl - ml).clamp(0, 99999);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_ml_${_selectedDate.toIso8601String().substring(0, 10)}', _waterMl);
  }

  Future<void> setWaterTargetMl(int ml) async {
    _waterTargetMl = ml.clamp(1, 99999);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_target_ml', _waterTargetMl);
  }

  Future<void> setVessels(List<WaterVessel> vessels) async {
    _vessels = vessels;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('water_vessels', jsonEncode(vessels.map((v) => v.toJson()).toList()));
  }

  Future<void> createRecipeFromMeal(Meal meal, String name) async {
    final mealEntries = entriesForMeal(meal);
    if (mealEntries.isEmpty) return;
    final recipeId = await DatabaseService.instance.saveRecipe(name, null);
    for (final entry in mealEntries) {
      await DatabaseService.instance.saveFood(entry.food);
      await DatabaseService.instance.addRecipeItem(recipeId, entry.food.id, entry.grams);
    }
    final recipeFood = await DatabaseService.instance.getRecipeAsFood(recipeId);
    if (recipeFood == null) return;
    for (final entry in mealEntries) {
      await DatabaseService.instance.deleteDiaryEntry(entry.id);
    }
    final newEntry = DiaryEntry(
      id: const Uuid().v4(),
      food: recipeFood,
      grams: recipeFood.servingGrams ?? 100,
      date: _selectedDate,
      meal: meal,
    );
    await DatabaseService.instance.addDiaryEntry(newEntry);
    await loadDay(_selectedDate);
  }
}
