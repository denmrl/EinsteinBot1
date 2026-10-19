class ActiveTrade {
  final String symbol;
  final double entryPrice;
  double stopLoss;
  final double tp1;
  final double tp2;
  final double tp3;
  final double tp4;
  final double tp5;
  final int tpCount;
  final bool enableTrailing;
  
  double remainingWeight;
  double realizedPnlPct;
  bool tp1Done;
  bool tp2Done;
  bool tp3TrailingActive;
  bool tp4Done;
  bool tp5Done;
  double maxPriceAfterTp3;
  
  final String patternName;
  final String entryTime;
  final String tradingMode;
  final double qty;

  ActiveTrade({
    required this.symbol,
    required this.entryPrice,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.tp3,
    this.tp4 = 0.0,
    this.tp5 = 0.0,
    this.tpCount = 3,
    this.enableTrailing = true,
    this.remainingWeight = 1.0,
    this.realizedPnlPct = 0.0,
    this.tp1Done = false,
    this.tp2Done = false,
    this.tp3TrailingActive = false,
    this.tp4Done = false,
    this.tp5Done = false,
    this.maxPriceAfterTp3 = 0.0,
    this.patternName = '',
    required this.entryTime,
    this.tradingMode = 'paper',
    this.qty = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'symbol': symbol,
    'entryPrice': entryPrice,
    'stopLoss': stopLoss,
    'tp1': tp1, 'tp2': tp2, 'tp3': tp3, 'tp4': tp4, 'tp5': tp5,
    'tpCount': tpCount, 'enableTrailing': enableTrailing,
    'remainingWeight': remainingWeight, 'realizedPnlPct': realizedPnlPct,
    'tp1Done': tp1Done, 'tp2Done': tp2Done, 'tp3TrailingActive': tp3TrailingActive,
    'tp4Done': tp4Done, 'tp5Done': tp5Done,
    'maxPriceAfterTp3': maxPriceAfterTp3, 'patternName': patternName,
    'entryTime': entryTime, 'tradingMode': tradingMode, 'qty': qty,
  };

  factory ActiveTrade.fromMap(Map<dynamic, dynamic> map) {
    return ActiveTrade(
      symbol: (map['symbol'] ?? '').toString(),
      entryPrice: _toD(map['entryPrice']), stopLoss: _toD(map['stopLoss']),
      tp1: _toD(map['tp1']), tp2: _toD(map['tp2']), tp3: _toD(map['tp3']),
      tp4: _toD(map['tp4']), tp5: _toD(map['tp5']),
      tpCount: map['tpCount'] ?? 3, enableTrailing: map['enableTrailing'] ?? true,
      remainingWeight: _toD(map['remainingWeight'], fallback: 1.0),
      realizedPnlPct: _toD(map['realizedPnlPct']),
      tp1Done: _toB(map['tp1Done']), tp2Done: _toB(map['tp2Done']),
      tp3TrailingActive: _toB(map['tp3TrailingActive']),
      tp4Done: _toB(map['tp4Done']), tp5Done: _toB(map['tp5Done']),
      maxPriceAfterTp3: _toD(map['maxPriceAfterTp3']),
      patternName: (map['patternName'] ?? '').toString(),
      entryTime: (map['entryTime'] ?? '').toString(),
      tradingMode: (map['tradingMode'] ?? 'paper').toString(),
      qty: _toD(map['qty']),
    );
  }

  ActiveTrade copyWith({
    double? stopLoss, double? remainingWeight, double? realizedPnlPct,
    bool? tp1Done, bool? tp2Done, bool? tp3TrailingActive,
    bool? tp4Done, bool? tp5Done, double? maxPriceAfterTp3,
  }) {
    return ActiveTrade(
      symbol: symbol, entryPrice: entryPrice, stopLoss: stopLoss ?? this.stopLoss,
      tp1: tp1, tp2: tp2, tp3: tp3, tp4: tp4, tp5: tp5,
      tpCount: tpCount, enableTrailing: enableTrailing,
      remainingWeight: remainingWeight ?? this.remainingWeight,
      realizedPnlPct: realizedPnlPct ?? this.realizedPnlPct,
      tp1Done: tp1Done ?? this.tp1Done, tp2Done: tp2Done ?? this.tp2Done,
      tp3TrailingActive: tp3TrailingActive ?? this.tp3TrailingActive,
      tp4Done: tp4Done ?? this.tp4Done, tp5Done: tp5Done ?? this.tp5Done,
      maxPriceAfterTp3: maxPriceAfterTp3 ?? this.maxPriceAfterTp3,
      patternName: patternName, entryTime: entryTime,
      tradingMode: tradingMode, qty: qty,
    );
  }

  static double _toD(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
  static bool _toB(dynamic v) => v == true || v == 1 || v == 'true';
}
