// ==========================================================
//  ЭЙНШТЕЙН — Утилиты форматирования для UI
//  Файл: lib/core/utils/formatters.dart
//  Красивое отображение баланса, PnL, курса валют и времени.
// ==========================================================
import 'package:intl/intl.dart';
class Formatters {
  Formatters._();
  // ==========================================================
  // 💵 ВАЛЮТА
  // ==========================================================
  /// Форматирует USDT с разделителями тысяч, 2 знака после точки.
  /// Пример: 1234.56 → "$1,234.56"
  static String usdt(double value, {int decimals = 2}) {
    final f = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '\$',
      decimalDigits: decimals,
    );
    return f.format(value);
  }
  /// Форматирует рубли, 2 знака после точки.
  /// Пример: 118000.0 → "118 000,00 ₽"
  static String rub(double value, {int decimals = 2}) {
    final f = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: decimals,
    );
    return f.format(value);
  }
  /// Универсальный формат для баланса (USDT / USD / RUB) в зависимости
  /// от выбранного режима отображения.
  static String balance(double value, String currency) {
    switch (currency) {
      case 'RUB':
        return rub(value);
      case 'USD':
      case 'USDT':
      default:
        return usdt(value);
    }
  }
  // ==========================================================
  // 📊 ПРОЦЕНТЫ И PnL
  // ==========================================================
  /// Формат процентов со знаком: "+15.30%" или "-4.75%".
  static String percentSigned(double value, {int decimals = 2}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}%';
  }
  /// Формат процентов без знака: "15.30%".
  static String percent(double value, {int decimals = 2}) {
    return '${value.toStringAsFixed(decimals)}%';
  }
  /// Значок тренда рядом с PnL: 📈 / 📉 / ➖.
  static String trendIcon(double value, {double threshold = 0.01}) {
    if (value > threshold) return '📈';
    if (value < -threshold) return '📉';
    return '➖';
  }
  // ==========================================================
  // 💱 КУРС ВАЛЮТ
  // ==========================================================
  /// Применяет курс USD→RUB к сумму в долларах.
  static double usdToRub(double usd, double rate) {
    return usd * rate;
  }
  /// Красивый курс: "1 $ = 92.45 ₽".
  static String rateUsdRub(double rate) {
    return '1 \$ = ${rate.toStringAsFixed(2)} ₽';
  }
  // ==========================================================
  // 🕒 ВРЕМЯ
  // ==========================================================
  /// Текущее время МСК в формате "HH:mm".
  static String nowHmMsk(DateTime mskNow) {
    final h = mskNow.hour.toString().padLeft(2, '0');
    final m = mskNow.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  /// Полное МСК-время: "08.10.2026 22:00:00".
  static String fullMsk(DateTime msk) {
    return DateFormat('dd.MM.yyyy HH:mm:ss').format(msk);
  }
  /// Дата МСК: "08.10.2026".
  static String dateMsk(DateTime msk) {
    return DateFormat('dd.MM.yyyy').format(msk);
  }
  // ==========================================================
  // 📉 ЦЕНА МОНЕТЫ (короткий формат)
  // ==========================================================
  /// Цена монеты с динамической точностью:
  /// ≥ 1.0 → "1.2345", ≥ 0.001 → "0.012345", меньше → "0.00001234".
  static String price(double val) {
    if (val <= 0) return '0.00';
    if (val >= 1.0) return val.toStringAsFixed(4);
    if (val >= 0.001) return val.toStringAsFixed(6);
    return val.toStringAsFixed(8);
  }
  /// Компактные обороты: 1 234 567 → "1.23M", 45 678 → "45.7K".
  static String compactNumber(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
