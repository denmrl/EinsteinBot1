// ==========================================================
//  ЭЙНШТЕЙН — Глобальный Rate Limiter
//  Файл: lib/core/utils/rate_limiter.dart
//  Аналог Python-класса GlobalRateLimiter.
//  Гарантирует паузу 1.6 сек между ВСЕМИ запросами к Bybit.
// ==========================================================
import 'dart:async';
/// Синглтон, который пропускает через себя все запросы к Bybit.
/// Прежде чем отправить запрос, код обязан вызвать `await RateLimiter.instance.wait()`.
class RateLimiter {
  // ---------- Синглтон ----------
  RateLimiter._internal() {
    _lastCallMs = 0;
  }
  static final RateLimiter instance = RateLimiter._internal();
  /// Задержка между запросами (мс). 1.6 сек × 60 = 96 req/min — ниже лимита 120.
  static const int _delayMs = 1600;
  /// Момент последнего запроса (мс, Unix Epoch).
  int _lastCallMs = 0;
  /// Очередь ожидающих запросов — формируется автоматически,
  /// потому что все вызовы идут через один `await`.
  Future<void> _tail = Future.value();
  /// Основной метод — ждём, если нужно, и обновляем метку.
  ///
  /// Работает последовательно: пока один поток внутри `wait()`,
  /// остальные ждут своей очереди. Это ключ к потокобезопасности.
  Future<void> wait() {
    // Прицепляемся к «хвосту» очереди и выполняемся после предыдущего.
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - _lastCallMs;
      if (elapsed < _delayMs) {
        // Ещё рано — спим остаток времени.
        await Future.delayed(Duration(milliseconds: _delayMs - elapsed));
      }
      _lastCallMs = DateTime.now().millisecondsSinceEpoch;
      completer.complete();
    });
    return completer.future;
  }
  /// Текущая задержка в миллисекундах (для отладки/тестов).
  int get delayMs => _delayMs;
}
