// ==========================================================
//  ЭЙНШТЕЙН — Foreground Service (совместимо с 8.17.0)
//  Файл: lib/background/foreground_service.dart
// ==========================================================

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import 'bot_task_handler.dart';

class ForegroundServiceManager {
  ForegroundServiceManager._internal();
  static final ForegroundServiceManager instance =
      ForegroundServiceManager._internal();

  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  // ==========================================================
  // 🚀 СТАРТ
  // ==========================================================
  Future<bool> start() async {
    // В 8.17.0 checkNotificationPermission возвращает NotificationPermission.
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

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
        eventAction: ForegroundTaskEventAction.repeat(15 * 60 * 1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    await NotificationService.instance.init();

    final result = await FlutterForegroundTask.startService(
      serviceId: 100,
      notificationTitle: 'Эйнштейн — запуск бота…',
      notificationText: 'Подключаюсь к Bybit…',
      callback: startCallback,
    );

    _log.i('🚀 Foreground Service start result: $result');
    return result is ServiceRequestSuccess;
  }

  // ==========================================================
  // ⏹ СТОП
  // ==========================================================
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _log.i('⏹ Foreground Service остановлен');
  }

  // ==========================================================
  // 📡 ПОДПИСКА НА СОБЫТИЯ
  // ==========================================================
  void subscribe({
    void Function()? onStarted,
    void Function()? onStopped,
    void Function(dynamic data)? onData,
  }) {
    FlutterForegroundTask.addTaskDataCallback((data) {
      onData?.call(data);
    });
  }

  void unsubscribe() {
    FlutterForegroundTask.removeTaskDataCallback((_) {});
  }
}