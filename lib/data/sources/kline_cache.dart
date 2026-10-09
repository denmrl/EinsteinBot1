// ==========================================================
//  ЭЙНШТЕЙН — Кэш свечей с TTL
//  Файл: lib/data/sources/kline_cache.dart
//  Аналог Python-словаря kline_cache в скрипте.
//  Не даёт спамить Bybit одинаковыми запросами свечей.
// ==========================================================
import '../../core/constants/app_constants.dart';
import '../models/candle.dart';
/// Запись в кэше: время сохранения + сами свечи.
class _CacheEntry {
  final DateTime savedAt;
  final List<Candle> candles;
  _CacheEntry(this.savedAt, this.candles);
  /// Проверяет, не устарела ли запись с учётом TTL (в секундах).
  bool isFresh(int ttlSec) {
    return DateTime.now().difference(savedAt).inSeconds < ttlSec;
  }
}
/// Синглтон кэша свечей. Ключ — "SYMBOL_INTERVAL" (например, "AIUSDT_15").
class KlineCache {
  KlineCache._internal();
  static final KlineCache instance = KlineCache._internal();
  final Map<String, _CacheEntry> _store = {};
  // ==========================================================
  // 📥 ЧТЕНИЕ ИЗ КЭША
  // ==========================================================
  /// Возвращает свечи, если они есть и ещё «живы», иначе null.
  List<Candle>? get(String symbol, String interval) {
    final key = _key(symbol, interval);
    final entry = _store[key];
    if (entry == null) return null;
    final ttl = ttlForInterval(interval);
    if (ttl <= 0 || !entry.isFresh(ttl)) {
      _store.remove(key); // Запись устарела — сразу чистим.
      return null;
    }
    return entry.candles;
  }
  // ==========================================================
  // 📤 ЗАПИСЬ В КЭШ
  // ==========================================================
  /// Кладём свечи в кэш с текущим временем.
  void put(String symbol, String interval, List<Candle> candles) {
    _store[_key(symbol, interval)] = _CacheEntry(DateTime.now(), candles);
  }
  /// Очистка одной записи или всего кэша.
  void invalidate(String symbol, String interval) {
    _store.remove(_key(symbol, interval));
  }
  void clearAll() => _store.clear();
  // ==========================================================
  // 🛠 TTL ПО ТАЙМФРЕЙМУ
  // ==========================================================
  /// Секундная «жизнь» для каждого интервала.
  /// Значения соответствуют Python: 5m=30s, 15m=60s, 1h=300s, 1d=3600s.
  static int ttlForInterval(String interval) {
    switch (interval) {
      case '5':
        return AppConstants.KLINE_TTL_5M;
      case '15':
        return AppConstants.KLINE_TTL_15M;
      case '60':
      case '1':
        return AppConstants.KLINE_TTL_1H;
      case 'D':
      case '1D':
        return AppConstants.KLINE_TTL_1D;
      default:
        return 60;
    }
  }
  /// Формирование ключа кэша. Приводим интервал к строке —
  /// чтобы 5 и '5' давали один и тот же ключ.
  String _key(String symbol, String interval) =>
      '${symbol.toUpperCase()}_$interval';
}
