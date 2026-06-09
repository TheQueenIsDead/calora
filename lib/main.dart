import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/diary_provider.dart';
import 'screens/home_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DiaryProvider()..init(),
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

class _RootScaffoldState extends State<_RootScaffold> {
  int _index = 0;

  static const _screens = [HomeScreen(), TrendsScreen(), SettingsScreen()];

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
