import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/bot_status_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/trades_provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(AppConstants.BOX_ACTIVE_TRADES),
    Hive.openBox(AppConstants.BOX_WATCHED_SETUPS),
    Hive.openBox(AppConstants.BOX_TRADE_HISTORY),
    Hive.openBox(AppConstants.BOX_SETTINGS),
    Hive.openBox(AppConstants.BOX_BALANCE_HISTORY),
    Hive.openBox(AppConstants.BOX_EVENT_LOG),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TradesProvider()),
        ChangeNotifierProvider(create: (_) => BotStatusProvider()),
      ],
      child: const TestApp(),
    ),
  );
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Эйнштейн',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
