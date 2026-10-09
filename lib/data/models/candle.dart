// ==========================================================
//  ЭЙНШТЕЙН — Модель японской свечи (OHLCV)
//  Файл: lib/data/models/candle.dart
//  Используется для расчёта EMA/RSI/ATR и поиска паттернов.
// ==========================================================
/// Одна свеча с таймфрейма (5m / 15m / 1h / 1d).
/// Все поля — double, потому что Bybit отдаёт цены строками,
/// а мы их сразу парсим при создании объекта.
class Candle {
  /// Цена открытия.
  final double open;
  /// Максимум за период.
  final double high;
  /// Минимум за период.
  final double low;
  /// Цена закрытия.
  final double close;
  /// Объём в USDT (для linear-контрактов Bybit).
  final double volume;
  /// Время открытия свечи (миллисекунды Unix Epoch UTC).
  /// Может пригодиться для графиков и сортировки.
  final int openTimeMs;
  const Candle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.openTimeMs = 0,
  });
  // ==========================================================
  // 📦 ПРЕОБРАЗОВАНИЕ В MAP / ИЗ MAP
  // ==========================================================
  /// Превращаем свечу в Map для сохранения в Hive или кэш.
  Map<String, dynamic> toMap() {
    return {
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'openTimeMs': openTimeMs,
    };
  }
  /// Восстанавливаем свечу из Map (читаем из Hive / кэша).
  /// Используем безопасное приведение чисел — Hive может вернуть int,
  /// если значение целое (например, volume=100.0 иногда сохранится как 100).
  factory Candle.fromMap(Map<dynamic, dynamic> map) {
    return Candle(
      open: _toDouble(map['open']),
      high: _toDouble(map['high']),
      low: _toDouble(map['low']),
      close: _toDouble(map['close']),
      volume: _toDouble(map['volume']),
      openTimeMs: _toInt(map['openTimeMs']),
    );
  }
  /// Парсим свечу напрямую из ответа Bybit V5 `get_kline`.
  /// Формат массива Bybit: [start, open, high, low, close, volume, turnover]
  factory Candle.fromBybitList(List<dynamic> arr) {
    return Candle(
      openTimeMs: int.tryParse(arr[0].toString()) ?? 0,
      open: double.tryParse(arr[1].toString()) ?? 0.0,
      high: double.tryParse(arr[2].toString()) ?? 0.0,
      low: double.tryParse(arr[3].toString()) ?? 0.0,
      close: double.tryParse(arr[4].toString()) ?? 0.0,
      volume: double.tryParse(arr[5].toString()) ?? 0.0,
    );
  }
  // ==========================================================
  // 🛠 ВСПОМОГАТЕЛЬНЫЕ
  // ==========================================================
  /// Универсальное приведение динамического значения к double.
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
  /// Универсальное приведение динамического значения к int.
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
  /// Краткая копия для отладки (в логах будет компактно).
  @override
  String toString() =>
      'Candle(O:\$open H:high L:low C:close V:volume)';
}
