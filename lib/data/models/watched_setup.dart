// ==========================================================
//  ЭЙНШТЕЙН — Модель монеты на НАБЛЮДЕНИИ (watched setup)
//  Файл: lib/data/models/watched_setup.dart
//  Монета найдена поисковиком, паттерн распознан, но вход
//  ещё не подтверждён — ждём пробоя триггерной цены.
// ==========================================================
/// Сетап, который ждёт подтверждения входа.
class WatchedSetup {
  /// Тикер.
  final String symbol;
  /// Название распознанного паттерна (например, "📐 Восходящий Треугольник").
  final String patternName;
  /// Цена в момент обнаружения паттерна.
  final double detectedPrice;
  /// Цена триггера (пробой этой цены = вход, если EMA/RSI подтвердят).
  /// По Python-логике: detected_price * 1.012.
  final double triggerPrice;
  /// Минимум паттерна — используется для расчёта стопа.
  final double patternLow;
  /// Абсолютный исторический минимум монеты.
  /// Если 1H-свеча его «пробьёт» — сетап отменяется.
  final double historicalLow;
  /// Время обнаружения в формате "HH:MM" (МСК).
  final String detectedAt;
  /// Причина попадания в наблюдение (макро-описание уката).
  /// Например: "Укат: -42.3% | От дна: +18.7%".
  final String macroReason;
  const WatchedSetup({
    required this.symbol,
    required this.patternName,
    required this.detectedPrice,
    required this.triggerPrice,
    required this.patternLow,
    required this.historicalLow,
    required this.detectedAt,
    this.macroReason = '',
  });
  // ==========================================================
  // 📦 TO / FROM MAP
  // ==========================================================
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'patternName': patternName,
      'detectedPrice': detectedPrice,
      'triggerPrice': triggerPrice,
      'patternLow': patternLow,
      'historicalLow': historicalLow,
      'detectedAt': detectedAt,
      'macroReason': macroReason,
    };
  }
  factory WatchedSetup.fromMap(Map<dynamic, dynamic> map) {
    return WatchedSetup(
      symbol: (map['symbol'] ?? '').toString(),
      patternName: (map['patternName'] ?? '').toString(),
      detectedPrice: _toDouble(map['detectedPrice']),
      triggerPrice: _toDouble(map['triggerPrice']),
      patternLow: _toDouble(map['patternLow']),
      historicalLow: _toDouble(map['historicalLow']),
      detectedAt: (map['detectedAt'] ?? '').toString(),
      macroReason: (map['macroReason'] ?? '').toString(),
    );
  }
  // ==========================================================
  // 🛠 ВСПОМОГАТЕЛЬНЫЕ
  // ==========================================================
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
  @override
  String toString() =>
      'WatchedSetup($symbol "$patternName" trigger=$triggerPrice)';
}
