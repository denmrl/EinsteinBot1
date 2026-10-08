// ==========================================================
//  ЭЙНШТЕЙН — Сервис безопасной торговли на Bybit V5
//  Файл: lib/data/sources/bybit_trading_service.dart
//  Обёртка над BybitApi для реальной торговли:
//    • расчёт qty по риску (учитывая qtyStep и minOrderQty);
//    • переключение mainnet/testnet;
//    • установка плеча;
//    • безопасное открытие/закрытие позиций.
// ==========================================================
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import 'bybit_api.dart';

/// Спецификация инструмента — минимум, шаг количества, шаг цены.
class InstrumentSpec {
  final double minOrderQty;   // минимальный лот
  final double qtyStep;       // шаг количества
  final double tickSize;      // шаг цены
  final double minNotional;   // минимальный номинал ($)
  InstrumentSpec({
    required this.minOrderQty,
    required this.qtyStep,
    required this.tickSize,
    required this.minNotional,
  });
}

/// Результат открытия позиции.
class OpenPositionResult {
  final String symbol;
  final String orderId;
  final double qty;
  final double entryPrice;
  const OpenPositionResult({
    required this.symbol,
    required this.orderId,
    required this.qty,
    required this.entryPrice,
  });
}

class BybitTradingService {
  BybitTradingService._internal();
  static final BybitTradingService instance = BybitTradingService._internal();
  final _api = BybitApi.instance;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  // Кэш спецификаций инструментов, чтобы не дёргать биржу каждый раз.
  final Map<String, InstrumentSpec> _specs = {};

  // ==========================================================
  // 🌐 ПЕРЕКЛЮЧЕНИЕ КОНТУРА (mainnet / testnet)
  // ==========================================================
  void switchToMainnet() {
    _api.setBaseUrl('https://bybit.com');
    _specs.clear();
    _log.i('🌐 Bybit: mainnet');
  }

  void switchToTestnet() {
    _api.setBaseUrl('https://bybit.com');
    _specs.clear();
    _log.i('🌐 Bybit: testnet');
  }

  // ==========================================================
  // 📐 СПЕЦИФИКАЦИЯ ИНСТРУМЕНТА
  // ==========================================================
  Future<InstrumentSpec> _getSpec(String symbol) async {
    if (_specs.containsKey(symbol)) return _specs[symbol]!;
    final info = await _api.getInstrumentInfo(symbol);
    if (info == null) {
      throw BybitApiException('Нет данных по инструменту $symbol');
    }
    final lot = (info['lotSizeFilter'] as Map?) ?? const {};
    final priceFilter = (info['priceFilter'] as Map?) ?? const {};
    final spec = InstrumentSpec(
      minOrderQty: _toD(lot['minOrderQty'], fallback: 1.0),
      qtyStep:     _toD(lot['qtyStep'],     fallback: 1.0),
      tickSize:    _toD(priceFilter['tickSize'], fallback: 0.0001),
      minNotional: _toD(lot['minNotionalValue'], fallback: 5.0),
    );
    _specs[symbol] = spec;
    return spec;
  }

  // ==========================================================
  // 💰 РАСЧЁТ QTY ПО РИСКУ
  // ==========================================================
  /// Считает размер позиции так, чтобы при срабатывании стопа
  /// мы потеряли не более riskPct% от баланса.
  Future<double> computeQtyFromRisk({
    required String symbol,
    required double balanceUsdt,
    required double riskPct,
    required double entryPrice,
    required double stopLoss,
    required int leverage,
  }) async {
    if (balanceUsdt <= 0) {
      throw BybitApiException('Пустой баланс для расчёта риска');
    }
    final riskPerUnit = (entryPrice - stopLoss).abs();
    if (riskPerUnit <= 0) {
      throw BybitApiException('Стоп равен входу — риск не рассчитывается');
    }
    final riskAmount = balanceUsdt * riskPct / 100.0;
    var qty = riskAmount / riskPerUnit;
    final spec = await _getSpec(symbol);
    // Округляем вниз по шагу.
    qty = (qty / spec.qtyStep).floorToDouble() * spec.qtyStep;
    // Проверки лимитов биржи.
    if (qty < spec.minOrderQty) {
      throw BybitApiException(
        'Рассчитанный qty ($qty) меньше minOrderQty (${spec.minOrderQty})',
      );
    }
    final notional = qty * entryPrice;
    if (notional < spec.minNotional) {
      throw BybitApiException(
        'Номинал позиции \$${notional.toStringAsFixed(2)} '
        'меньше минимума \$${spec.minNotional}',
      );
    }
    // Проверка, что требуемая маржа не превышает баланс с учётом плеча.
    final requiredMargin = notional / leverage;
    if (requiredMargin > balanceUsdt) {
      throw BybitApiException(
        'Недостаточно маржи: нужно \$${requiredMargin.toStringAsFixed(2)}, '
        'доступно \$${balanceUsdt.toStringAsFixed(2)}',
      );
    }
    _log.i('📐 $symbol qty=$qty (риск \$${riskAmount.toStringAsFixed(2)}, '
        'плечо x$leverage)');
    return qty;
  }

  // ==========================================================
  // 🚀 ОТКРЫТИЕ ЛОНГА
  // ==========================================================
  Future<OpenPositionResult> openLong({
    required String symbol,
    required double qty,
    required int leverage,
    required double stopLoss,
  }) async {
    // 1) Плечо. В hedge-режиме Bybit требует buy и sell отдельно.
    await _api.setLeverage(symbol: symbol, leverage: leverage);
    // 2) Округляем SL по шагу цены инструмента.
    final spec = await _getSpec(symbol);
    final sl = BybitApi.roundToTick(stopLoss, spec.tickSize);
    // 3) Рыночный ордер Buy.
    final orderId = await _api.placeMarketOrder(
      symbol: symbol,
      side: 'Buy',
      qty: qty,
      positionIdx: 0, // one-way
      stopLoss: sl.toString(),
    );
    // 4) Читаем фактическую позицию, чтобы узнать среднюю цену входа.
    await Future.delayed(const Duration(milliseconds: 800));
    final pos = await _api.getPosition(symbol);
    final avgPrice = _toD(pos?['avgPrice'], fallback: 0.0);
    final realQty  = _toD(pos?['size'], fallback: qty);
    _log.i('🟢 Реально открыт лонг $symbol qty=$realQty @ $avgPrice');
    return OpenPositionResult(
      symbol: symbol,
      orderId: orderId,
      qty: realQty > 0 ? realQty : qty,
      entryPrice: avgPrice > 0 ? avgPrice : 0.0,
    );
  }

  // ==========================================================
  // 🛑 ЗАКРЫТИЕ ПОЗИЦИИ ПО РЫНКУ
  // ==========================================================
  Future<void> closeLong({
    required String symbol,
    required double qty,
  }) async {
    final orderId = await _api.closeMarketPosition(
      symbol: symbol,
      positionIdx: 0,
      qty: qty,
      currentSide: 'Buy', // закрываем лонг → отправляем Sell
    );
    _log.i('🔴 Закрыт лонг $symbol qty=$qty (orderId=$orderId)');
  }

  // ==========================================================
  // 🔄 ОБНОВЛЕНИЕ SL/TP НА БИРЖЕ
  // ==========================================================
  Future<void> updateStopLoss({
    required String symbol,
    required double newStopLoss,
    double? takeProfit,
  }) async {
    final spec = await _getSpec(symbol);
    final sl = BybitApi.roundToTick(newStopLoss, spec.tickSize);
    final tp = takeProfit != null
        ? BybitApi.roundToTick(takeProfit, spec.tickSize)
        : null;
    await _api.setTradingStop(
      symbol: symbol,
      positionIdx: 0,
      stopLoss: sl.toString(),
      takeProfit: tp?.toString(),
    );
    _log.i('🔄 $symbol SL обновлён на $sl');
  }

  // ==========================================================
  // 💼 БАЛАНС КОШЕЛЬКА
  // ==========================================================
  Future<double> getWalletBalanceUsdt() => _api.getWalletBalanceUsdt();

  // ==========================================================
  // 🛠 ХЕЛПЕР
  // ==========================================================
  double _toD(dynamic v, {required double fallback}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
}
