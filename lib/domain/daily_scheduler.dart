// ==========================================================
//  ЭЙНШТЕЙН — Планировщик ежедневного отчёта (22:00 МСК)
//  Файл: lib/domain/daily_scheduler.dart
//  Каждые 60 сек проверяет время: если наступило 22:00 МСК
//  и отчёт за сегодня ещё не отправляли — запускает ReportBuilder.
// ==========================================================
import 'dart:async';
import 'package:logger/logger.dart';
import '../core/constants/app_constants.dart';
import 'report_builder.dart';

class DailyScheduler {
  DailyScheduler._internal();
  static final DailyScheduler instance = DailyScheduler._internal();
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  Timer? _timer;
  /// Ключ для отметки «последний день отправки» в формате YYYY-MM-DD.
  String? _lastSentDate;

  // ==========================================================
  // 🚀 СТАРТ / СТОП
  // ==========================================================
  void start() {
    if (_timer != null) return;
    _log.i('⏰ DailyScheduler запущен (отчёт в '
        '${AppConstants.DAILY_REPORT_HOUR}:'
        '${_two(AppConstants.DAILY_REPORT_MINUTE)} МСК)');
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _tick(),
    );
    _tick(); // сразу проверим — вдруг сейчас ровно 22:00
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _log.i('⏹ DailyScheduler остановлен');
  }

  // ==========================================================
  // 🔄 ПРОВЕРКА РАЗ В МИНУТУ
  // ==========================================================
  Future<void> _tick() async {
    try {
      final nowMsk = _nowMsk();
      final todayStr =
          '${nowMsk.year}-${_two(nowMsk.month)}-${_two(nowMsk.day)}';
      
      // Уже отправляли сегодня? Ничего не делаем.
      if (_lastSentDate == todayStr) return;
      
      final targetHour = AppConstants.DAILY_REPORT_HOUR;
      final targetMin = AppConstants.DAILY_REPORT_MINUTE;
      
      // Время уже пришло?
      final isTime =
          nowMsk.hour > targetHour ||
          (nowMsk.hour == targetHour && nowMsk.minute >= targetMin);
          
      if (!isTime) return;
      
      // Отправляем отчёт и запоминаем день.
      _log.i('📤 Пора отправлять отчёт за $todayStr');
      await ReportBuilder.instance.buildAndSend();
      _lastSentDate = todayStr;
    } catch (e, st) {
      _log.e('⚠ Ошибка DailyScheduler: $e', error: e, stackTrace: st);
    }
  }

  // ---------- Время МСК ----------
  DateTime _nowMsk() =>
      DateTime.now().toUtc().add(const Duration(hours: 3));
      
  String _two(int v) => v.toString().padLeft(2, '0');
}
