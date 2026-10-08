// ==========================================================
//  ЭЙНШТЕЙН — Локальные пуши (замена ntfy.sh)
//  Файл: lib/core/services/notification_service.dart
//  Показывает уведомления в шторке Android без интернета.
// ==========================================================
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Инициализация — вызывается один раз при старте приложения.
  Future<void> init() async {
    if (_initialized) return;
    // ---------- Android-канал по умолчанию ----------
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    // ---------- Каналы (важно: они должны существовать ДО показа) ----------
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.NOTIF_CHANNEL_SIGNALS_ID,
      AppConstants.NOTIF_CHANNEL_SIGNALS_NAME,
      description: AppConstants.NOTIF_CHANNEL_SIGNALS_DESC,
      importance: Importance.high,
    ));
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.NOTIF_CHANNEL_TRADES_ID,
      AppConstants.NOTIF_CHANNEL_TRADES_NAME,
      description: AppConstants.NOTIF_CHANNEL_TRADES_DESC,
      importance: Importance.high,
    ));
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      AppConstants.NOTIF_CHANNEL_REPORTS_ID,
      AppConstants.NOTIF_CHANNEL_REPORTS_NAME,
      description: AppConstants.NOTIF_CHANNEL_REPORTS_DESC,
      importance: Importance.defaultImportance,
    ));
    _initialized = true;
  }

  /// Запрос разрешения на уведомления (Android 13+).
  Future<bool> requestPermission() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return (await impl?.requestNotificationsPermission()) ?? false;
  }

  /// Базовый показ уведомления.
  Future<void> show({
    required int id,
    required String channelId,
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == AppConstants.NOTIF_CHANNEL_SIGNALS_ID
            ? AppConstants.NOTIF_CHANNEL_SIGNALS_NAME
            : channelId == AppConstants.NOTIF_CHANNEL_TRADES_ID
                ? AppConstants.NOTIF_CHANNEL_TRADES_NAME
                : AppConstants.NOTIF_CHANNEL_REPORTS_NAME,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  // ---------- Обёртки под конкретные типы событий ----------
  Future<void> signal({required String title, required String body}) => show(
        id: AppConstants.NOTIF_ID_SIGNAL,
        channelId: AppConstants.NOTIF_CHANNEL_SIGNALS_ID,
        title: title,
        body: body,
      );

  Future<void> trade({required int id, required String title, required String body}) =>
      show(
        id: id,
        channelId: AppConstants.NOTIF_CHANNEL_TRADES_ID,
        title: title,
        body: body,
      );

  Future<void> report({required String title, required String body}) => show(
        id: AppConstants.NOTIF_ID_REPORT,
        channelId: AppConstants.NOTIF_CHANNEL_REPORTS_ID,
        title: title,
        body: body,
      );
}
