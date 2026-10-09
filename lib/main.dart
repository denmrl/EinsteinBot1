// ==========================================================
//  ЭЙНШТЕЙН — Точка входа (совместимо с flutter_foreground_task 8.17.0)
//  Файл: lib/main.dart
// ==========================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/constants/app_constants.dart';
import 'core/providers/bot_status_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/trades_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await _initHive();
  await _initTimezone();
  await _initLocalization();
  await NotificationService.instance.init();
  _initForegroundTask();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TradesProvider()),
        ChangeNotifierProvider(create: (_) => BotStatusProvider()),
      ],
      child: const EinsteinApp(),
    ),
  );
}

// ==========================================================
// 💾 HIVE
// ==========================================================
Future<void> _initHive() async {
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(AppConstants.BOX_ACTIVE_TRADES),
    Hive.openBox(AppConstants.BOX_WATCHED_SETUPS),
    Hive.openBox(AppConstants.BOX_TRADE_HISTORY),
    Hive.openBox(AppConstants.BOX_SETTINGS),
    Hive.openBox(AppConstants.BOX_BALANCE_HISTORY),
    Hive.openBox(AppConstants.BOX_EVENT_LOG),
  ]);
  debugPrint('✅ [Hive] Все боксы открыты');
}

// ==========================================================
// 🌍 TIMEZONE
// ==========================================================
Future<void> _initTimezone() async {
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(AppConstants.TIMEZONE_MSK));
  debugPrint('✅ [TZ] ${tz.local.name}');
}

// ==========================================================
// 🌐 i18n
// ==========================================================
Future<void> _initLocalization() async {
  await initializeDateFormatting('ru_RU', null);
  debugPrint('✅ [i18n] ru_RU загружено');
}

// ==========================================================
// 🔔 FOREGROUND TASK (init)
// 8.17.0: без serviceTypes, без NotificationIconData.
// ==========================================================
void _initForegroundTask() {
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
  debugPrint('✅ [FGS] Foreground Task инициализирован');
}

// ==========================================================
// 🎨 КОРНЕВОЙ WIDGET
// ==========================================================
class EinsteinApp extends StatelessWidget {
  const EinsteinApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: AppConstants.APP_NAME,
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