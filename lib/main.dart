import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/diary_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trends_screen.dart';
import 'services/database_service.dart';
import 'services/calorie_widget_service.dart';
import 'services/water_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final diary = DiaryProvider();
  final settings = SettingsProvider(onGoalChanged: diary.refreshCurrentDay);
  // Snapshot widget water value BEFORE diary.init() loads SQLite,
  // so a previous _push() can't overwrite the widget's newer value.
  final widgetWaterMl = await WaterWidgetService.snapshotWidgetWater();
  await settings.init();
  await diary.init();
  await WaterWidgetService.instance.initialize(diary, settings, widgetWaterMl);
  await CalorieWidgetService.instance.initialize(diary, settings);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: diary),
      ],
      child: const CaloraApp(),
    ),
  );
}

class CaloraApp extends StatelessWidget {
  const CaloraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42C750),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42C750),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 0),
      ),
      home: const _RootScaffold(),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [HomeScreen(), TrendsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }

  Future<void> _onResumed() async {
    // Snapshot widget water BEFORE handleAppResume() reloads from SQLite
    // so the listener can't overwrite the widget's value mid-sync.
    final widgetMl = await WaterWidgetService.snapshotWidgetWater();
    if (!mounted) return;
    final diary = context.read<DiaryProvider>();
    await diary.handleAppResume();
    if (!mounted) return;
    if (widgetMl != null && widgetMl > diary.waterMl) {
      await DatabaseService.instance.setWaterMlForDate(
        DateTime.now(),
        widgetMl,
      );
      await diary.refreshCurrentDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
