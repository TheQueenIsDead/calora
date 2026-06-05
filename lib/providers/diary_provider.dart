import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';

class DiaryProvider extends ChangeNotifier {
  List<DiaryEntry> _entries = [];
  DateTime _selectedDate = DateTime.now();
  int _currentGoal = 2000;  // most recently set goal — used in settings
  int _dailyGoal = 2000;    // effective goal for _selectedDate — used in diary
  int _waterTarget = 8;
  bool _loading = false;
  int _waterCups = 0;

  List<DiaryEntry> get entries => _entries;
DateTime get selectedDate => _selectedDate;
  int get currentGoal => _currentGoal;
  int get dailyGoal => _dailyGoal;
  int get waterTarget => _waterTarget;
  bool get loading => _loading;
  int get waterCups => _waterCups;

  double get totalCalories => _entries.fold(0, (sum, e) => sum + e.calories);
  double get totalFat      => _entries.fold(0, (sum, e) => sum + e.fat);
  double get totalCarbs    => _entries.fold(0, (sum, e) => sum + e.carbs);
  double get totalProtein  => _entries.fold(0, (sum, e) => sum + e.protein);
  double get remainingCalories => _dailyGoal - totalCalories;
  double get progress => (_dailyGoal > 0 ? totalCalories / _dailyGoal : 0.0).clamp(0.0, 1.0);

  List<DiaryEntry> entriesForMeal(Meal meal) =>
      _entries.where((e) => e.meal == meal).toList();

  String _waterKey(DateTime date) => 'water_${date.toIso8601String().substring(0, 10)}';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentGoal = prefs.getInt('daily_goal') ?? 2000;
    _waterTarget = prefs.getInt('water_target') ?? 8;
    await loadDay(_selectedDate);
  }

  Future<void> loadDay(DateTime date) async {
    _loading = true;
    notifyListeners();
    _selectedDate = date;
    _entries = await DatabaseService.instance.getEntriesForDate(date);
    final prefs = await SharedPreferences.getInstance();
    _waterCups = prefs.getInt(_waterKey(date)) ?? 0;
    // Use recorded goal for this date; fall back to the current setting
    _dailyGoal =
        await DatabaseService.instance.getEffectiveGoal(date) ?? _currentGoal;
    _loading = false;
    notifyListeners();
  }

  Future<void> setWaterCups(int cups) async {
    _waterCups = cups.clamp(0, 99);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterKey(_selectedDate), _waterCups);
  }

  Future<void> addEntry(DiaryEntry entry) async {
    await DatabaseService.instance.addDiaryEntry(entry);
    await loadDay(_selectedDate);
  }

  Future<void> deleteEntry(String id) async {
    await DatabaseService.instance.deleteDiaryEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> moveEntry(String entryId, Meal newMeal) async {
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

  Future<void> setWaterTarget(int cups) async {
    _waterTarget = cups.clamp(1, 30);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_target', _waterTarget);
  }
}
