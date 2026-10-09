// ==========================================================
//  ЭЙНШТЕЙН — Общая навигационная оболочка приложения
//  Файл: lib/presentation/screens/home_shell.dart
//  Создает удобную нижнюю панель из 4 вкладок.
// ==========================================================
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'trades_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'trading_mode_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  
  // Список всех четырех экранов нашего терминала
  final _screens = const [
    TradesScreen(),
    StatisticsScreen(),
    SettingsScreen(),
    TradingModeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.accentGreen.withAlpha((0.15 * 255).toInt()),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt, color: AppColors.accentGreen),
            label: 'Сделки',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.accentGreen),
            label: 'Статистика',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune, color: AppColors.accentGreen),
            label: 'Настройки',
          ),
          NavigationDestination(
            icon: Icon(Icons.power_settings_new_outlined),
            selectedIcon: Icon(Icons.power_settings_new, color: AppColors.accentGreen),
            label: 'Режим',
          ),
        ],
      ),
    );
  }
}
