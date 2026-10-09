// ==========================================================
//  ЭЙНШТЕЙН — Модель ЗАКРЫТОЙ сделки (история)
//  Файл: lib/data/models/closed_trade.dart
//  Нужна для расчёта винрейта, суммарного PnL, коэффициента
//  Прибыль/Убыток на экране статистики.
// ==========================================================
/// Запись о полностью закрытой сделке.
class ClosedTrade {
  /// Тикер.
  final String symbol;
  /// Цена входа.
  final double entryPrice;
  /// Цена выхода (по которой реально закрыли).
  final double closePrice;
  /// Причина закрытия: "Stop Loss", "Безубыток", "Trailing Stop 15%" и т.д.
  final String reason;
  /// Итоговый чистый PnL по сделке в процентах (с учётом
  /// частичных фиксаций на TP1/TP2 и остатка на трейлинге).
  final double finalNetPnlPct;
  /// Время закрытия в формате "YYYY-MM-DD HH:MM:SS" (МСК).
  final String closedAt;
  /// Абсолютный PnL в USDT (для расчёта баланса демо-режима).
  /// Может быть 0, если сделка велась без привязки к размеру позиции.
  final double pnlUsdt;
  /// Режим торговли на момент сделки: "paper" или "real".
  final String tradingMode;
  /// Имя паттерна входа — для статистики «какой паттерн прибыльнее».
  final String patternName;
  const ClosedTrade({
    required this.symbol,
    required this.entryPrice,
    required this.closePrice,
    required this.reason,
    required this.finalNetPnlPct,
    required this.closedAt,
    this.pnlUsdt = 0.0,
    this.tradingMode = 'paper',
    this.patternName = '',
  });
  // ==========================================================
  // 📦 TO / FROM MAP
  // ==========================================================
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'entryPrice': entryPrice,
      'closePrice': closePrice,
      'reason': reason,
      'finalNetPnlPct': finalNetPnlPct,
      'closedAt': closedAt,
      'pnlUsdt': pnlUsdt,
      'tradingMode': tradingMode,
      'patternName': patternName,
    };
  }
  factory ClosedTrade.fromMap(Map<dynamic, dynamic> map) {
    return ClosedTrade(
      symbol: (map['symbol'] ?? '').toString(),
      entryPrice: _toDouble(map['entryPrice']),
      closePrice: _toDouble(map['closePrice']),
      reason: (map['reason'] ?? '').toString(),
      finalNetPnlPct: _toDouble(map['finalNetPnlPct']),
      closedAt: (map['closedAt'] ?? '').toString(),
      pnlUsdt: _toDouble(map['pnlUsdt']),
      tradingMode: (map['tradingMode'] ?? 'paper').toString(),
      patternName: (map['patternName'] ?? '').toString(),
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
  /// Сделка считается прибыльной, если итог > 0.
  bool get isWin => finalNetPnlPct > 0;
  @override
  String toString() =>
      'ClosedTrade($symbol ${finalNetPnlPct.toStringAsFixed(2)}% "$reason")';
}
