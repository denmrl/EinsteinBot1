// ==========================================================
//  ЭЙНШТЕЙН — Макро-фильтр «Укат и дно» (порт analyze_shitcoin_macro)
//  Файл: lib/domain/macro_analyzer.dart
//  Проверяет три условия для монеты, прежде чем искать паттерн:
//    1. ATR% на 1H ≥ 0.25% (иначе — «мёртвый флэт»)
//    2. Цена не выше, чем +38% от абсолютного исторического дна
//    3. Монета укатана от недельного максимума не меньше чем на 30%
// ==========================================================
import '../core/utils/indicators.dart';
import '../data/models/candle.dart';
/// Результат работы макро-анализа.
/// `ok` — прошла ли монета фильтр.
/// `reason` — человекочитаемое описание (для UI и логов).
/// `historicalLow` — абсолютный минимум, найденный по всем данным.
class MacroResult {
  final bool ok;
  final String reason;
  final double historicalLow;
  const MacroResult({
    required this.ok,
    required this.reason,
    required this.historicalLow,
  });
  /// Удобный сокращённый конструктор для случая «не прошла».
  const MacroResult.fail(this.reason)
      : ok = false,
        historicalLow = 0.0;
  @override
  String toString() => ok ? '✅ Macro OK: reason' : '❌ Macro: reason';
}
class MacroAnalyzer {
  MacroAnalyzer._();
  /// Главный метод.
  ///
  /// [dCandles]   — дневные свечи (interval = "D").
  /// [h1Candles]  — часовые свечи (interval = "60").
  /// [wCandles]   — недельные свечи (может быть null — тогда используем дневные).
  /// [mCandles]   — месячные свечи (может быть null — учитываем, если есть).
  static MacroResult analyze({
    required List<Candle> dCandles,
    required List<Candle> h1Candles,
    List<Candle>? wCandles,
    List<Candle>? mCandles,
  }) {
    // ---------- 0. Проверка минимального объёма данных ----------
    if (dCandles.length < 10 || h1Candles.length < 20) {
      return const MacroResult.fail('Мало данных');
    }
    // ---------- 1. Цена и ATR% на 1H ----------
    final currPrice = h1Candles.last.close;
    final atr1h = Indicators.atr(h1Candles, period: 14);
    final atrPct = currPrice > 0 ? (atr1h / currPrice) * 100 : 0.0;
    // Мёртвый флэт — торговать нечего.
    if (atrPct < 0.25) {
      return MacroResult.fail(
        'Мертвый флэт (ATR \${atrPct.toStringAsFixed(2)}% < 0.25%)',
      );
    }
    // ---------- 2. Абсолютный исторический минимум ----------
    // Собираем все лоу с дневных свечей, добавляем месячные (если есть).
    final allLows = <double>[
      ...dCandles.map((c) => c.low),
      if (mCandles != null) ...mCandles.map((c) => c.low),
    ];
    final absoluteHistoricalLow = allLows.reduce((a, b) => a < b ? a : b);
    // Насколько цена отскочила от дна (в %).
    final priceFromBottomPct =
        ((currPrice - absoluteHistoricalLow) / absoluteHistoricalLow) * 100;
    // Если цена уже далеко ушла от дна — поздний вход, пропускаем.
    if (priceFromBottomPct > 38.0) {
      return MacroResult(
        ok: false,
        reason: 'Далеко от дна (+\${priceFromBottomPct.toStringAsFixed(1)}%)',
        historicalLow: absoluteHistoricalLow,
      );
    }
    // ---------- 3. Глубина «уката» от недельного максимума ----------
    // Если недельных свечей нет — берём дневные (как в Python).
    final wSource = (wCandles != null && wCandles.isNotEmpty)
        ? wCandles
        : dCandles;
    // Максимум за последние 30 свечей источника.
    final wTail = wSource.length >= 5
        ? wSource.sublist(wSource.length - 30)
        : wSource;
    final maxWPrice = wTail.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    // Просадка от максимума до текущей цены (в %).
    final dumpDepthPct =
        maxWPrice > 0 ? ((maxWPrice - currPrice) / maxWPrice) * 100 : 0.0;
    // Маленький укат — не наш сетап.
    if (dumpDepthPct < 30.0) {
      return MacroResult(
        ok: false,
        reason: 'Маленький укат (-\${dumpDepthPct.toStringAsFixed(1)}%)',
        historicalLow: absoluteHistoricalLow,
      );
    }
    // ---------- 4. Всё ок — монета прошла макро-фильтр ----------
    return MacroResult(
      ok: true,
      reason: 'Укат: -\${dumpDepthPct.toStringAsFixed(1)}% | '
          'От дна: +\${priceFromBottomPct.toStringAsFixed(1)}%',
      historicalLow: absoluteHistoricalLow,
    );
  }
}
