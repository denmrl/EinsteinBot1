// ==========================================================
//  ЭЙНШТЕЙН — Распознавание графических паттернов
//  Файл: lib/domain/pattern_detector.dart
//  Порт detect_chart_patterns:
//    1. 🚩 Бычий Флаг / Канал консолидации
//    2. 📐 Восходящий Треугольник (поджатие)
//    3. ⚡️ V-Образный Разворот (бычий откуп)
//    4. 📦 Накопление в боковике с поджатием
// ==========================================================
import '../data/models/candle.dart';
/// Результат распознавания паттерна.
class PatternResult {
  /// Найден ли паттерн.
  final bool found;
  /// Название паттерна (со смайлом, как в Python), либо null.
  final String? name;
  /// Локальный минимум паттерна — основа для расчёта стоп-лосса.
  final double patternLow;
  const PatternResult({
    required this.found,
    this.name,
    required this.patternLow,
  });
  /// Удобный конструктор «ничего не найдено».
  const PatternResult.empty(this.patternLow)
      : found = false,
        name = null;
  @override
  String toString() =>
      found ? '✅ $name (low=$patternLow)' : '❌ Нет паттерна (low=$patternLow)';
}
class PatternDetector {
  PatternDetector._();
  // ==========================================================
  // 🎯 ГЛАВНЫЙ МЕТОД
  // ==========================================================
  /// [candles15m] — свечи 15m (приоритет).
  /// [candles5m]  — свечи 5m (fallback, если 15m мало).
  ///
  /// Возвращает PatternResult (без исключений).
  static PatternResult detect({
    required List<Candle> candles15m,
    required List<Candle> candles5m,
  }) {
    // ---------- 0. Выбираем источник свечей ----------
    // В Python: c_list = candles_15m if len(candles_15m) >= 30 else candles_5m
    final cList = candles15m.length >= 30 ? candles15m : candles5m;
    if (cList.length < 30) {
      return const PatternResult.empty(0.0);
    }
    // ---------- 1. Разбираем свечи на массивы ----------
    final closes = cList.map((c) => c.close).toList();
    final highs = cList.map((c) => c.high).toList();
    final lows = cList.map((c) => c.low).toList();
    final vols = cList.map((c) => c.volume).toList();
    final currPrice = closes.last;
    // ---------- 2. Диапазон последних 30 свечей ----------
    // Python: highs[-30:], lows[-30:]
    final last30Highs = highs.sublist(highs.length - 30);
    final last30Lows = lows.sublist(lows.length - 30);
    final maxHigh30 = last30Highs.reduce((a, b) => a > b ? a : b);
    final minLow30 = last30Lows.reduce((a, b) => a < b ? a : b);
    final range30 =
        maxHigh30 > minLow30 ? (maxHigh30 - minLow30) : 1.0;
    // ---------- 3. Срез lows[-30:-20] — «ранние» лоу ----------
    // В Dart: sublist(len-30, len-20)
    final lowSlice = lows.sublist(lows.length - 30, lows.length - 20);
    final minLowSlice =
        lowSlice.isEmpty ? minLow30 : lowSlice.reduce((a, b) => a < b ? a : b);
    // ---------- 4. Импульс роста (max на [-25:-10] / minLowSlice) ----------
    // Python: (max(highs[-25:-10]) - min_low_slice) / min_low_slice
    final impulseHighs = highs.sublist(highs.length - 25, highs.length - 10);
    final impulseMax = impulseHighs.reduce((a, b) => a > b ? a : b);
    final impulse = minLowSlice > 0
        ? (impulseMax - minLowSlice) / minLowSlice
        : 0.0;
    // ---------- 5. Сжатие диапазона за последние 10 свечей ----------
    // Python: (max(highs[-10:]) - min(lows[-10:])) / range_30
    final recentHighs = highs.sublist(highs.length - 10);
    final recentLows = lows.sublist(lows.length - 10);
    final recentMaxH = recentHighs.reduce((a, b) => a > b ? a : b);
    final recentMinL = recentLows.reduce((a, b) => a < b ? a : b);
    final recentRange = (recentMaxH - recentMinL) / range30;
    // ==========================================================
    // 🚩 ПАТТЕРН 1: Бычий Флаг / Канал консолидации
    // ==========================================================
    // Условия:
    //   • импульс роста ≥ 8%
    //   • сжатие диапазона в консолидации ≤ 45%
    //   • цена в верхних 40% от общего диапазона
    if (impulse >= 0.08 &&
        recentRange <= 0.45 &&
        currPrice >= (minLow30 + range30 * 0.60)) {
      return PatternResult(
        found: true,
        name: '🚩 Бычий Флаг / Канал консолидации',
        patternLow: minLow30,
      );
    }
    // ==========================================================
    // 📐 ПАТТЕРН 2: Восходящий Треугольник (поджатие)
    // ==========================================================
    // Три последовательных локальных минимума:
    //   low_1 = min(lows[-25:-15])
    //   low_2 = min(lows[-15:-5])
    //   low_3 = min(lows[-5:])
    // Условие: low_1 < low_2 ≤ low_3 * 1.015 (лоу поджимаются к верху)
    // И цена близка к хаю диапазона (не дальше 2%).
    final low1 = lows
        .sublist(lows.length - 25, lows.length - 15)
        .reduce((a, b) => a < b ? a : b);
    final low2 = lows
        .sublist(lows.length - 15, lows.length - 5)
        .reduce((a, b) => a < b ? a : b);
    final low3 = lows
        .sublist(lows.length - 5)
        .reduce((a, b) => a < b ? a : b);
    if (low1 < low2 &&
        low2 <= low3 * 1.015 &&
        ((maxHigh30 - currPrice) / currPrice) <= 0.02) {
      return PatternResult(
        found: true,
        name: '📐 Восходящий Треугольник (Поджатие)',
        patternLow: minLow30,
      );
    }
    // ==========================================================
    // ⚡️ ПАТТЕРН 3: V-Образный Разворот (бычий откуп)
    // ==========================================================
    // Свеча закрылась красной, но с очень длинной нижней тенью,
    // и на повышенном объёме — значит кто-то выкупал с рынка.
    final lastOpen = cList.last.open;
    final lastClose = closes.last;
    final lastLow = lows.last;
    final lastBody = (lastClose - lastOpen).abs();
    final lastLowerWick =
        (lastClose < lastOpen ? lastClose : lastOpen) - lastLow;
    // Средний объём предыдущих 9 свечей (без последней).
    final prevVols = vols.sublist(vols.length - 10, vols.length - 1);
    final avgVolPrev =
        prevVols.isEmpty ? 1.0 : prevVols.reduce((a, b) => a + b) / prevVols.length;
    if (lastLowerWick >= lastBody * 1.6 &&
        vols.last >= avgVolPrev * 1.8) {
      return PatternResult(
        found: true,
        name: '⚡️ V-Образный Разворот (Бычий откуп)',
        patternLow: lastLow,
      );
    }
    // ==========================================================
    // 📦 ПАТТЕРН 4: Накопление в боковике с поджатием
    // ==========================================================
    // Цена стоит у верхней границы диапазона,
    // и текущее закрытие выше закрытия 5 свечей назад.
    if (currPrice >= maxHigh30 * 0.985 && closes.last > closes[closes.length - 5]) {
      return PatternResult(
        found: true,
        name: '📦 Накопление в боковике с поджатием',
        patternLow: minLow30,
      );
    }
    // ---------- Ничего не нашли ----------
    return PatternResult.empty(minLow30);
  }
}
