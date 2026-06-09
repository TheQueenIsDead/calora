import 'package:flutter/foundation.dart';
import '../models/water_vessel.dart';
import '../services/database_service.dart';
import '../services/user_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final VoidCallback? _onGoalChanged;

  SettingsProvider({VoidCallback? onGoalChanged}) : _onGoalChanged = onGoalChanged; // ignore: prefer_initializing_formals

  int _currentGoal = 2000;
  int _waterTargetMl = 2000;
  List<WaterVessel> _vessels = [];
  int _bmr = 0;
  int _tdee = 0;
  List<Map<String, dynamic>> _recipes = [];

  int get currentGoal => _currentGoal;
  int get waterTargetMl => _waterTargetMl;
  List<WaterVessel> get vessels => _vessels;
  int get bmr => _bmr;
  int get tdee => _tdee;
  List<Map<String, dynamic>> get recipes => _recipes;

  Future<void> init() async {
    final prefs = UserPreferences.instance;
    _currentGoal = await prefs.getDailyGoal();
    _waterTargetMl = await prefs.getWaterTargetMl();
    _vessels = await prefs.getVessels();
    _bmr = await prefs.getBmr();
    _tdee = await prefs.getTdee();
    _recipes = await DatabaseService.instance.getRecipes();
    notifyListeners();
  }

  Future<void> setDailyGoal(int calories) async {
    _currentGoal = calories;
    notifyListeners();
    await UserPreferences.instance.setDailyGoal(calories);
    await DatabaseService.instance.saveGoal(DateTime.now(), calories);
    _onGoalChanged?.call();
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

  Future<void> loadRecipes() async {
    _recipes = await DatabaseService.instance.getRecipes();
    notifyListeners();
  }
}