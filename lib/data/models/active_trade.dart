// ==========================================================
//  ЭЙНШТЕЙН — Модель АКТИВНОЙ (открытой) сделки (ОБНОВЛЕННАЯ)
//  Файл: lib/data/models/active_trade.dart
//  Хранит всю информацию о позиции и статус сопровождения
//  по этапам TP1 → TP2 → TP3 → Trailing Stop.
// ==========================================================
/// Одна открытая позиция. Обновляется на каждом цикле
/// монитора выходов (exit monitor).
class ActiveTrade {
  // ---------- Идентификация ----------
  /// Тикер (например, "AIUSDT").
  final String symbol;
  /// Реальный размер позиции (0 для Paper).
  final double qty;
  /// Цена входа в позицию.
  final double entryPrice;
  // ---------- Уровни ----------
  /// Текущий стоп-лосс. Меняется по мере роста: SL → BE → TP1.
  double stopLoss;
  /// Уровень TP1 (+15% от входа).
  final double tp1;
  /// Уровень TP2 (+35% от входа).
  final double tp2;
  /// Уровень TP3 (+75% от входа, после него — трейлинг).
  final double tp3;
  // ---------- Состояние сопровождения ----------
  /// Оставшийся «вес» позиции (1.0 = 100%).
  /// После TP1 = 0.70, после TP2 = 0.40.
  double remainingWeight;
  /// Уже зафиксированный PnL в процентах (накапливается).
  double realizedPnlPct;
  /// Взят ли уже TP1.
  bool tp1Done;
  /// Взят ли уже TP2.
  bool tp2Done;
  /// Активирован ли Trailing Stop (после достижения TP3).
  bool tp3TrailingActive;
  /// Максимальная цена после активации трейлинга.
  /// Нужна для расчёта уровня трейлинг-стопа.
  double maxPriceAfterTp3;
  // ---------- Мета ----------
  /// Имя паттерна, по которому был вход («🚩 Бычий Флаг» и т.д.).
  final String patternName;
  /// Время входа в формате "YYYY-MM-DD HH:MM" (МСК).
  final String entryTime;
  /// Режим торговли в момент входа: "paper" или "real".
  /// Нужно, чтобы понимать, какой баланс обновлять при закрытии.
  final String tradingMode;

  ActiveTrade({
    required this.symbol,
    this.qty = 0.0, // Патч для Варианта C
    required this.entryPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.tp3,
    this.remainingWeight = 1.0,
    this.realizedPnlPct = 0.0,
    this.tp1Done = false,
    this.tp2Done = false,
    this.tp3TrailingActive = false,
    this.maxPriceAfterTp3 = 0.0,
    this.patternName = '',
    required this.entryTime,
    this.tradingMode = 'paper',
  });

  // ==========================================================
  // 📦 TO / FROM MAP
  // ==========================================================
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'qty': qty, // Патч для Варианта C
      'entryPrice': entryPrice,
      'stopLoss': stopLoss,
      'tp1': tp1,
      'tp2': tp2,
      'tp3': tp3,
      'remainingWeight': remainingWeight,
      'realizedPnlPct': realizedPnlPct,
      'tp1Done': tp1Done,
      'tp2Done': tp2Done,
      'tp3TrailingActive': tp3TrailingActive,
      'maxPriceAfterTp3': maxPriceAfterTp3,
      'patternName': patternName,
      'entryTime': entryTime,
      'tradingMode': tradingMode,
    };
  }

  factory ActiveTrade.fromMap(Map<dynamic, dynamic> map) {
    return ActiveTrade(
      symbol: (map['symbol'] ?? '').toString(),
      qty: _toDouble(map['qty']), // Патч для Варианта C
      entryPrice: _toDouble(map['entryPrice']),
      stopLoss: _toDouble(map['stopLoss']),
      tp1: _toDouble(map['tp1']),
      tp2: _toDouble(map['tp2']),
      tp3: _toDouble(map['tp3']),
      remainingWeight: _toDouble(map['remainingWeight'], fallback: 1.0),
      realizedPnlPct: _toDouble(map['realizedPnlPct']),
      tp1Done: _toBool(map['tp1Done']),
      tp2Done: _toBool(map['tp2Done']),
      tp3TrailingActive: _toBool(map['tp3TrailingActive']),
      maxPriceAfterTp3: _toDouble(map['maxPriceAfterTp3']),
      patternName: (map['patternName'] ?? '').toString(),
      entryTime: (map['entryTime'] ?? '').toString(),
      tradingMode: (map['tradingMode'] ?? 'paper').toString(),
    );
  }

  // ==========================================================
  // 🧬 КОПИРОВАНИЕ С ИЗМЕНЕНИЯМИ
  // ==========================================================
  ActiveTrade copyWith({
    double? stopLoss,
    double? qty, // Патч для Варианта C
    double? remainingWeight,
    double? realizedPnlPct,
    bool? tp1Done,
    bool? tp2Done,
    bool? tp3TrailingActive,
    double? maxPriceAfterTp3,
  }) {
    return ActiveTrade(
      symbol: symbol,
      qty: qty ?? this.qty, // Патч для Варианта C
      entryPrice: entryPrice,
      stopLoss: stopLoss ?? this.stopLoss,
      tp1: tp1,
      tp2: tp2,
      tp3: tp3,
      remainingWeight: remainingWeight ?? this.remainingWeight,
      realizedPnlPct: realizedPnlPct ?? this.realizedPnlPct,
      tp1Done: tp1Done ?? this.tp1Done,
      tp2Done: tp2Done ?? this.tp2Done,
      tp3TrailingActive: tp3TrailingActive ?? this.tp3TrailingActive,
      maxPriceAfterTp3: maxPriceAfterTp3 ?? this.maxPriceAfterTp3,
      patternName: patternName,
      entryTime: entryTime,
      tradingMode: tradingMode,
    );
  }

  // ==========================================================
  // 🛠 ВСПОМОГАТЕЛЬНЫЕ
  // ==========================================================
  static double _toDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    return v.toString().toLowerCase() == 'true';
  }

  @override
  String toString() =>
      'ActiveTrade($symbol qty=$qty entry=$entryPrice SL=$stopLoss '
      'TP1=$tp1/${tp1Done} TP2=$tp2/${tp2Done} trail=${tp3TrailingActive})';
}
