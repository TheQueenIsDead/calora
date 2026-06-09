import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../services/user_preferences.dart';

class DiaryProvider extends ChangeNotifier {
  List<DiaryEntry> _entries = [];
  DateTime _selectedDate = DateTime.now();
  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, DiaryEntry> _deletedEntries = {};
  int _dailyGoal = 2000;
  bool _loading = false;
  bool _isLocked = false;
  int _waterMl = 0;
  int _changeToken = 0;

  List<DiaryEntry> get entries => _entries;
  DateTime get selectedDate => _selectedDate;
  int get changeToken => _changeToken;
  int get dailyGoal => _dailyGoal;
  bool get loading => _loading;
  bool get isLocked => _isLocked;
  int get waterMl => _waterMl;

  double get totalCalories => _entries.fold(0, (sum, e) => sum + e.calories);
  double get totalFat => _entries.fold(0, (sum, e) => sum + e.fat);
  double get totalCarbs => _entries.fold(0, (sum, e) => sum + e.carbs);
  double get totalProtein => _entries.fold(0, (sum, e) => sum + e.protein);
  double get remainingCalories => _dailyGoal - totalCalories;
  double get progress =>
      (_dailyGoal > 0 ? totalCalories / _dailyGoal : 0.0).clamp(0.0, 1.0);

  List<DiaryEntry> entriesForMeal(Meal meal) =>
      _entries.where((e) => e.meal == meal).toList();

  bool _wasViewingToday = true;

  Future<void> init() async {
    await loadDay(_selectedDate);
  }

  Future<void> refreshCurrentDay() => loadDay(_selectedDate);

  /// Called when the app returns to the foreground. If the user was on
  /// "today" when they backgrounded and the date has since rolled over,
  /// advances to the new today automatically.
  Future<void> handleAppResume() async {
    if (_wasViewingToday) await loadDay(DateTime.now());
  }

  Future<void> loadDay(DateTime date) async {
    _loading = true;
    notifyListeners();
    _selectedDate = date;
    final now = DateTime.now();
    _wasViewingToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    _entries = await DatabaseService.instance.getEntriesForDate(date);
    final prefs = UserPreferences.instance;
    _waterMl = await prefs.getWaterMlForDate(date);
    _dailyGoal = await DatabaseService.instance.getEffectiveGoal(date) ??
        await UserPreferences.instance.getDailyGoal();
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
