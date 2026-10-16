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
import 'presentation/screens/trades_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚨 ЛОВУШКА ОШИБОК: если что-то падает в build — покажем на экране.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: Colors.red.shade900,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ ОШИБКА В UI',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SelectableText(
              '${details.exception}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SelectableText(
              '${details.stack}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🚨 FLUTTER ERROR: ${details.exception}');
    debugPrint('🚨 STACK: ${details.stack}');
  };

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
      child: const EinsteinApp(),
    ),
  );
}

class EinsteinApp extends StatelessWidget {
  const EinsteinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Эйнштейн',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      home: const TradesScreen(),
    );
  }
}
