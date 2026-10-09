import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/constants/app_constants.dart';
import 'core/providers/bot_status_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/trades_provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(AppConstants.BOX_ACTIVE_TRADES),
    Hive.openBox(AppConstants.BOX_WATCHED_SETUPS),
    Hive.openBox(AppConstants.BOX_TRADE_HISTORY),
    Hive.openBox(AppConstants.BOX_SETTINGS),
    Hive.openBox(AppConstants.BOX_BALANCE_HISTORY),
    Hive.openBox(AppConstants.BOX_EVENT_LOG),
  ]);

  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(AppConstants.TIMEZONE_MSK));
  await initializeDateFormatting('ru_RU', null);

  // 🚀 ЭТАП 3: инициализация Foreground Task
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: AppConstants.NOTIF_CHANNEL_SERVICE_ID,
      channelName: AppConstants.NOTIF_CHANNEL_SERVICE_NAME,
      channelDescription: AppConstants.NOTIF_CHANNEL_SERVICE_DESC,
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      home: const HomeShell(),
    );
  }
}

class Stage2Screen extends StatelessWidget {
  const Stage2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final trades = context.watch<TradesProvider>();

    return Scaffold(
      backgroundColor: Colors.indigo,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ЭТАП 3 ОК',
                    style: TextStyle(color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const Text('FGS init без краша',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Text('Тема: ${settings.themeMode.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text('Активных: ${trades.active.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text('Наблюдаю: ${trades.watched.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text('История: ${trades.history.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                Text('Курс: ${settings.usdRubRate?.toStringAsFixed(2) ?? "—"}',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
