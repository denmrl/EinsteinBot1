// ==========================================================
//  ЭЙНШТЕЙН — Математические индикаторы (порт из Python 1:1)
//  Файл: lib/core/utils/indicators.dart
//  Все формулы соответствуют функциям из старого скрипта:
//    • calculate_ema
//    • calculate_rsi  (Wilder-сглаживание)
//    • calculate_atr  (по True Range)
//    • is_strong_historical_low_breakout
//    • fmt_p          (форматирование цены)
// ==========================================================
import '../../data/models/candle.dart';
/// Класс-контейнер индикаторов. Все методы — статические
/// (создавать экземпляр не нужно).
class Indicators {
  Indicators._(); // приватный конструктор — только статика
  // ==========================================================
  // 📈 EMA — Экспоненциальное скользящее среднее
  // ==========================================================
  /// Возвращает список EMA той же длины, что и входной список цен.
  ///
  /// Python-логика:
  ///   k = 2 / (period + 1)
  ///   ema = [prices[0]]
  ///   for price in prices[1:]:
  ///       ema.append(price * k + ema[-1] * (1 - k))
  ///   если len(prices) < period — вернуть [prices[-1]] * len(prices)
  static List<double> ema(List<double> prices, int period) {
    if (prices.isEmpty) return const [];
    // Защита «слабых данных» — как в Python.
    if (prices.length < period) {
      return List<double>.filled(prices.length, prices.last);
    }
    final k = 2.0 / (period + 1);
    // Начинаем с первой цены — так делает Python.
    final result = <double>[prices.first];
    for (var i = 1; i < prices.length; i++) {
      result.add(prices[i] * k + result[i - 1] * (1 - k));
    }
    return result;
  }
  // ==========================================================
  // 📉 RSI — Индекс относительной силы (Wilder-сглаживание)
  // ==========================================================
  /// Возвращает ОДНО значение — RSI для последней свечи.
  ///
  /// Python-логика:
  ///   если мало данных — вернуть 50.0 (нейтрально)
  ///   считаем gains/losses по разностям closes
  ///   avg_gain / avg_loss — сглаживаем по формуле Wilder
  ///   RSI = 100 - 100/(1+rs); если avg_loss=0 → 100.
  static double rsi(List<double> closes, {int period = 14}) {
    // Мало данных для корректного расчёта — возвращаем нейтраль.
    if (closes.length < period + 1) return 50.0;
    // Считаем приросты и убытки по каждой паре свечей.
    final gains = <double>[];
    final losses = <double>[];
    for (var i = 1; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff >= 0) {
        gains.add(diff);
        losses.add(0.0);
      } else {
        gains.add(0.0);
        losses.add(diff.abs());
      }
    }
    // Первое среднее — простое арифметическое за первые `period` значений.
    var avgGain =
        gains.sublist(0, period).reduce((a, b) => a + b) / period;
    var avgLoss =
        losses.sublist(0, period).reduce((a, b) => a + b) / period;
    // Сглаживание Wilder для остальных значений.
    for (var i = period; i < gains.length; i++) {
      avgGain = (avgGain * (period - 1) + gains[i]) / period;
      avgLoss = (avgLoss * (period - 1) + losses[i]) / period;
    }
    // Защита от деления на ноль — сильный бычий тренд.
    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }
  // ==========================================================
  // 🌊 ATR — Средний истинный диапазон
  // ==========================================================
  /// Возвращает ATR последнего периода (одно число).
  ///
  /// Python-логика:
  ///   TR = max(h-l, |h-cp|, |l-cp|) для каждой свечи, начиная со 2-й
  ///   ATR = среднее последних `period` значений TR
  ///   если данных меньше period+1 — вернуть 0.0
  static double atr(List<Candle> candles, {int period = 14}) {
    // Мало данных — нет смысла считать.
    if (candles.length < period + 1) return 0.0;
    final trList = <double>[];
    for (var i = 1; i < candles.length; i++) {
      final h = candles[i].high;
      final l = candles[i].low;
      final cp = candles[i - 1].close;
      // True Range = максимум из трёх величин.
      final tr = [
        h - l,
        (h - cp).abs(),
        (l - cp).abs(),
      ].reduce((a, b) => a > b ? a : b);
      trList.add(tr);
    }
    // Берём последние `period` значений TR и считаем среднее.
    final tail = trList.sublist(trList.length - period);
    return tail.reduce((a, b) => a + b) / period;
  }
  // ==========================================================
  // 🛑 Проверка «сильного» пробоя исторического дна на 1H
  // ==========================================================
  /// Возвращает true, если 1H-свеча СИЛЬНО пробила исторический минимум
  /// вниз — то есть это медвежий пробой, и наблюдение нужно отменить.
  ///
  /// Python-логика:
  ///   • low или close свечи НЕ должны быть выше historical_low;
  ///   • свеча должна быть красной (close < open);
  ///   • нижняя тень должна быть НЕ БОЛЬШЕ 5% от диапазона
  ///     (значит свеча закрылась почти на минимуме — сильное давление продавцов).
  static bool isStrongHistoricalLowBreakout(
    Candle candle1h,
    double historicalLow, {
    double maxShadowPct = 0.05,
  }) {
    // Если пробоя нет — сразу выход.
    if (candle1h.low >= historicalLow || candle1h.close >= historicalLow) {
      return false;
    }
    // Свеча должна быть красной.
    if (candle1h.close >= candle1h.open) return false;
    final range = candle1h.high - candle1h.low;
    if (range <= 0) return false; // защита от вырожденной свечи
    // Доля нижней тени от диапазона.
    final lowerShadow = candle1h.close - candle1h.low;
    return (lowerShadow / range) <= maxShadowPct;
  }
  // ==========================================================
  // 💵 Форматирование цены (аналог Python fmt_p)
  // ==========================================================
  /// Динамическая точность:
  ///   • ≥ 1.0     → 4 знака после точки (например, 12.3456)
  ///   • ≥ 0.001   → 6 знаков (например, 0.012345)
  ///   • < 0.001   → 8 знаков (например, 0.00001234)
  /// Также используется в UI-карточках и уведомлениях.
  static String fmtP(double? val) {
    if (val == null || val <= 0) return '0.00';
    if (val >= 1.0) return val.toStringAsFixed(4);
    if (val >= 0.001) return val.toStringAsFixed(6);
    return val.toStringAsFixed(8);
  }
}
