import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/diary_entry.dart';
import '../models/water_vessel.dart';
import '../services/database_service.dart';
import '../services/user_preferences.dart';

class DiaryProvider extends ChangeNotifier {
  List<DiaryEntry> _entries = [];
  DateTime _selectedDate = DateTime.now();
  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, DiaryEntry> _deletedEntries = {};
  int _currentGoal = 2000;
  int _dailyGoal = 2000;
  int _waterTargetMl = 2000;
  bool _loading = false;
  bool _isLocked = false;
  int _waterMl = 0;
  int _bmr = 0;
  int _tdee = 0;
  List<WaterVessel> _vessels = [];
  int _changeToken = 0;

  List<DiaryEntry> get entries => _entries;
  DateTime get selectedDate => _selectedDate;
  int get changeToken => _changeToken;
  int get currentGoal => _currentGoal;
  int get dailyGoal => _dailyGoal;
  int get waterTargetMl => _waterTargetMl;
  bool get loading => _loading;
  bool get isLocked => _isLocked;
  int get waterMl => _waterMl;
  int get bmr => _bmr;
  int get tdee => _tdee;
  List<WaterVessel> get vessels => _vessels;
  double get waterProgress =>
      _waterTargetMl > 0 ? (_waterMl / _waterTargetMl).clamp(0.0, 1.0) : 0.0;

  double get totalCalories => _entries.fold(0, (sum, e) => sum + e.calories);
  double get totalFat => _entries.fold(0, (sum, e) => sum + e.fat);
  double get totalCarbs => _entries.fold(0, (sum, e) => sum + e.carbs);
  double get totalProtein => _entries.fold(0, (sum, e) => sum + e.protein);
  double get remainingCalories => _dailyGoal - totalCalories;
  double get progress =>
      (_dailyGoal > 0 ? totalCalories / _dailyGoal : 0.0).clamp(0.0, 1.0);

  List<DiaryEntry> entriesForMeal(Meal meal) =>
      _entries.where((e) => e.meal == meal).toList();

  Future<void> init() async {
    final prefs = UserPreferences.instance;
    _currentGoal = await prefs.getDailyGoal();
    _waterTargetMl = await prefs.getWaterTargetMl();
    _vessels = await prefs.getVessels();
    _bmr = await prefs.getBmr();
    _tdee = await prefs.getTdee();
    await loadDay(_selectedDate);
  }

  Future<void> loadDay(DateTime date) async {
    _loading = true;
    notifyListeners();
    _selectedDate = date;
    _entries = await DatabaseService.instance.getEntriesForDate(date);
    final prefs = UserPreferences.instance;
    _waterMl = await prefs.getWaterMlForDate(date);
    _dailyGoal =
        await DatabaseService.instance.getEffectiveGoal(date) ?? _currentGoal;
    _isLocked = await prefs.getLockState(date);
    _loading = false;
    notifyListeners();
  }

  Future<void> toggleLock() async {
    _isLocked = !_isLocked;
    notifyListeners();
    await UserPreferences.instance.setLockState(_selectedDate, _isLocked);
  }

  Future<void> addEntry(DiaryEntry entry) async {
    if (_isLocked) return;
    await DatabaseService.instance.addDiaryEntry(entry);
    _changeToken++;
    await loadDay(_selectedDate);
  }

  Future<void> updateEntryGrams(String id, double grams) async {
    if (_isLocked) return;
    await DatabaseService.instance.updateDiaryEntryGrams(id, grams);
    _changeToken++;
    await loadDay(_selectedDate);
  }

  Future<void> deleteEntry(String id) async {
    if (_isLocked) return;
    await DatabaseService.instance.deleteDiaryEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<DiaryEntry?> softDeleteEntry(String id) async {
    if (_isLocked) return null;
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final entry = _entries.removeAt(idx);
    _deletedEntries[id] = entry;
    _pendingDeletes[id]?.cancel();
    _pendingDeletes[id] = Timer(
      const Duration(seconds: 5),
      () => _commitDelete(id),
    );
    _changeToken++;
    notifyListeners();
    return entry;
  }

  void undoDelete(String id) {
    _pendingDeletes[id]?.cancel();
    _pendingDeletes.remove(id);
    final entry = _deletedEntries.remove(id);
    if (entry == null) return;
    _entries.add(entry);
    _changeToken++;
    notifyListeners();
  }

  Future<void> _commitDelete(String id) async {
    _deletedEntries.remove(id);
    _pendingDeletes.remove(id);
    await DatabaseService.instance.deleteDiaryEntry(id);
  }

  @override
  void dispose() {
    for (final t in _pendingDeletes.values) {
      t.cancel();
    }
    _pendingDeletes.clear();
    super.dispose();
  }

  Future<void> moveEntry(String entryId, Meal newMeal) async {
    if (_isLocked) return;
    await DatabaseService.instance.updateEntryMeal(entryId, newMeal);
    _changeToken++;
    await loadDay(_selectedDate);
  }

  Future<void> setDailyGoal(int calories) async {
    _currentGoal = calories;
    _dailyGoal = calories;
    notifyListeners();
    await UserPreferences.instance.setDailyGoal(calories);
    await DatabaseService.instance.saveGoal(DateTime.now(), calories);
  }

  Future<void> setBmr(int bmr) async {
    _bmr = bmr;
    notifyListeners();
    await UserPreferences.instance.setBmr(bmr);
  }

  Future<void> setTdee(int tdee) async {
    _tdee = tdee;
    notifyListeners();
    await UserPreferences.instance.setTdee(tdee);
  }

  Future<void> addWaterMl(int ml) async {
    if (_isLocked) return;
    _waterMl = (_waterMl + ml).clamp(0, 99999);
    notifyListeners();
    await UserPreferences.instance.setWaterMlForDate(_selectedDate, _waterMl);
  }

  Future<void> removeWaterMl(int ml) async {
    if (_isLocked) return;
    _waterMl = (_waterMl - ml).clamp(0, 99999);
    notifyListeners();
    await UserPreferences.instance.setWaterMlForDate(_selectedDate, _waterMl);
  }

  Future<void> setWaterTargetMl(int ml) async {
    _waterTargetMl = ml.clamp(1, 99999);
    notifyListeners();
    await UserPreferences.instance.setWaterTargetMl(_waterTargetMl);
  }

  Future<void> setVessels(List<WaterVessel> vessels) async {
    _vessels = vessels;
    notifyListeners();
    await UserPreferences.instance.setVessels(vessels);
  }

  Future<void> createRecipeFromMeal(Meal meal, String name) async {
    final mealEntries = entriesForMeal(meal);
    if (mealEntries.isEmpty) return;
    for (final entry in mealEntries) {
      await DatabaseService.instance.saveFood(entry.food);
    }
    final recipeId = await DatabaseService.instance.saveRecipeWithItems(
      name,
      null,
      mealEntries.map((e) => (foodId: e.food.id, grams: e.grams)).toList(),
    );
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
    _changeToken++;
    await loadDay(_selectedDate);
  }
}
