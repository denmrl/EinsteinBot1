import 'dart:async';

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

/// Если что-то падает в main — здесь будет текст ошибки.
String? _fatalError;
String? _fatalStack;

Future<void> main() async {
  // Ловим все ошибки до runApp.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    originalOnError?.call(details);
    _fatalError ??= details.exceptionAsString();
    _fatalStack ??= details.stack?.toString();
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Красивый показ ошибок в виджетах.
  ErrorWidget.builder = (details) {
    return Container(
      color: const Color(0xFF7F1D1D),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Text(
          'ОШИБКА ВИДЖЕТА:\n\n${details.exception}\n\n${details.stack}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  };

  // Пробуем всё по шагам, каждую ошибку перехватываем.
  await _step('SetOrientation', () async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  });

  await _step('Hive', _initHive);
  await _step('Timezone', _initTimezone);
  await _step('Localization', _initLocalization);
  await _step('Notifications', () async {
    await NotificationService.instance.init();
  });
  await _step('ForegroundTask', () async {
    _initForegroundTask();
  });

  // Запускаем приложение.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TradesProvider()),
        ChangeNotifierProvider(create: (_) => BotStatusProvider()),
      ],
      child: _fatalError == null
          ? const EinsteinApp()
          : FatalErrorScreen(error: _fatalError!, stack: _fatalStack ?? ''),
    ),
  );
}

/// Обёртка: если шаг упал — сохраняем текст ошибки и не продолжаем.
Future<void> _step(String name, Future<void> Function() action) async {
  if (_fatalError != null) return;
  try {
    await action();
    debugPrint('✅ $name OK');
  } catch (e, st) {
    _fatalError = '[$name] $e';
    _fatalStack = st.toString();
    debugPrint('❌ $name FAILED: $e');
  }
}

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
}

Future<void> _initTimezone() async {
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(AppConstants.TIMEZONE_MSK));
}

Future<void> _initLocalization() async {
  await initializeDateFormatting('ru_RU', null);
}

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
}

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

/// Экран, который покажет ошибку краша — большой, читаемый.
class FatalErrorScreen extends StatelessWidget {
  final String error;
  final String stack;
  const FatalErrorScreen({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A0000),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ ОШИБКА ЗАПУСКА',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Скопируй текст ниже и пришли в чат:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Стек:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    stack,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}