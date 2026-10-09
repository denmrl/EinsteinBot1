// ==========================================================
//  ЭЙНШТЕЙН — Точка входа изолята Foreground Service
//  Файл: lib/background/bot_task_handler.dart
//  Без Firebase. Совместимо с flutter_foreground_task 8.17.0.
// ==========================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../domain/daily_scheduler.dart';
import '../domain/exit_monitor_engine.dart';
import '../domain/searcher_engine.dart';

@pragma('vm:entry-point')
void startCallback() {
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(EinsteinTaskHandler());
}

class EinsteinTaskHandler extends TaskHandler {
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  Timer? _uiTimer;
  bool _started = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _log.i('🔧 Foreground Service изолят запущен ($starter)');

    try {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
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

      await NotificationService.instance.init();

      SearcherEngine.instance.start();
      ExitMonitorEngine.instance.start();
      DailyScheduler.instance.start();
      _started = true;

      _uiTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshNotification(),
      );
      await _refreshNotification();
    } catch (e, st) {
      _log.e('❌ Ошибка старта FGS: $e', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _log.i('⏹ Foreground Service останавливается…');
    _uiTimer?.cancel();
    _uiTimer = null;

    if (_started) {
      SearcherEngine.instance.stop();
      ExitMonitorEngine.instance.stop();
      DailyScheduler.instance.stop();
    }
    _started = false;
  }

  // 8.17.0: параметр Object (не RemoteMessage).
  @override
  void onReceiveData(Object data) {
    _log.i('📩 FGS → UI: $data');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _refreshNotification();
  }

  Future<void> _refreshNotification() async {
    int activeCount = 0;
    int watchedCount = 0;
    try {
      if (Hive.isBoxOpen(AppConstants.BOX_ACTIVE_TRADES)) {
        activeCount = Hive.box(AppConstants.BOX_ACTIVE_TRADES).length;
      }
      if (Hive.isBoxOpen(AppConstants.BOX_WATCHED_SETUPS)) {
        watchedCount = Hive.box(AppConstants.BOX_WATCHED_SETUPS).length;
      }
    } catch (_) {}

    final text = 'Сделок: $activeCount | Наблюдаю: $watchedCount | '
        '${_nowMskStr()} МСК';

    await FlutterForegroundTask.updateService(
      notificationTitle: 'Эйнштейн — бот работает',
      notificationText: text,
    );
  }

  String _nowMskStr() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return '${_two(now.hour)}:${_two(now.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}