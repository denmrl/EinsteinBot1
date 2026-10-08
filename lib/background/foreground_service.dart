// ==========================================================
//  ЭЙНШТЕЙН — Менеджер Foreground Service для UI
//  Файл: lib/background/foreground_service.dart
//  Содержит start() / stop() / isRunning().
//  Привязывается к тумблеру «Запустить бота» в UI.
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

  // ==========================================================
  // 📥 ПРОВЕРКА СТАТУСА
  // ==========================================================
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  // ==========================================================
  // 🚀 СТАРТ СЕРВИСА
  // ==========================================================
  /// Запуск. Возвращает true, если сервис стартовал.
  Future<bool> start() async {
    final notifOk = await FlutterForegroundTask.checkNotificationPermission();
    if (!notifOk) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.NOTIF_CHANNEL_SERVICE_ID,
        channelName: AppConstants.NOTIF_CHANNEL_SERVICE_NAME,
        channelDescription: AppConstants.NOTIF_CHANNEL_SERVICE_DESC,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.drawable,
          resPrefix: ResourcePrefix.ic,
          name: 'stat_einstein',
        ),
        buttons: const [
          NotificationButton(id: 'stop', text: 'Остановить'),
        ],
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
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Эйнштейн — запуск бота…',
      notificationText: 'Подключаюсь к Bybit…',
      callback: startCallback, 
    );
    _log.i('🚀 Foreground Service start result: $result');
    return result is ServiceRequestSuccess;
  }

  // ==========================================================
  // ⏹ ОСТАНОВКА СЕРВИСА
  // ==========================================================
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _log.i('⏹ Foreground Service остановлен');
  }

  // ==========================================================
  // 🎛 СЛУШАТЕЛЬ СОБЫТИЙ
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
