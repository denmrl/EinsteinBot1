import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../core/utils/formatters.dart';
import '../data/models/active_trade.dart';
import '../data/models/closed_trade.dart';
import '../data/repositories/balance_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/trades_repository.dart';
import '../data/sources/bybit_trading_service.dart';

enum ExitEvent { tp1, tp2, tp3, tp4, tp5, trailingClosed, stopLoss, none }

class PositionManager {
  PositionManager._internal();
  static final PositionManager instance = PositionManager._internal();

  final _trades = TradesRepository();
  final _balance = BalanceRepository.instance;
  final _settings = SettingsRepository.instance;
  final _trading = BybitTradingService.instance;
  final _notif = NotificationService.instance;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<ActiveTrade?> openPosition({
    required String symbol,
    required double entryPrice,
    required double stopLoss,
    required String patternName,
  }) async {
    final settings = await _settings.load();
    final isReal = settings.tradingMode == TradingMode.real;

    final tp1 = entryPrice * settings.tp1Multiplier;
    final tp2 = entryPrice * settings.tp2Multiplier;
    final tp3 = entryPrice * settings.tp3Multiplier;
    final tp4 = entryPrice * settings.tp4Multiplier;
    final tp5 = entryPrice * settings.tp5Multiplier;

    final entryTime = _nowMskStr();
    double qty = 0.0;

    if (isReal) {
      try {
        final creds = await _settings.loadBybitCredentials();
        if (creds == null) return null;
        
        _trading.switchToMainnet(); // TODO: env switch
        final bal = await _trading.getWalletBalanceUsdt();
        qty = await _trading.computeQtyFromRisk(
          symbol: symbol,
          balanceUsdt: bal,
          riskPct: settings.riskPerTradePct,
          entryPrice: entryPrice,
          stopLoss: stopLoss,
          leverage: settings.leverage,
        );
        final res = await _trading.openLong(
          symbol: symbol,
          qty: qty,
          leverage: settings.leverage,
          stopLoss: stopLoss,
        );
        qty = res.qty;
        final realEntry = res.entryPrice > 0 ? res.entryPrice : entryPrice;
        return await _persistNewTrade(
          symbol: symbol, entryPrice: realEntry, stopLoss: stopLoss,
          tp1: realEntry * settings.tp1Multiplier, tp2: realEntry * settings.tp2Multiplier,
          tp3: realEntry * settings.tp3Multiplier, tp4: realEntry * settings.tp4Multiplier,
          tp5: realEntry * settings.tp5Multiplier, patternName: patternName,
          entryTime: entryTime, mode: 'real', qty: qty,
          tpCount: settings.tpCount, enableTrailing: settings.enableTrailing,
        );
      } catch (e) {
        _log.e('❌ Ошибка реального входа: $e');
        return null;
      }
    }

    return await _persistNewTrade(
      symbol: symbol, entryPrice: entryPrice, stopLoss: stopLoss,
      tp1: tp1, tp2: tp2, tp3: tp3, tp4: tp4, tp5: tp5,
      patternName: patternName, entryTime: entryTime, mode: 'paper', qty: 0.0,
      tpCount: settings.tpCount, enableTrailing: settings.enableTrailing,
    );
  }

  Future<ActiveTrade> _persistNewTrade({
    required String symbol, required double entryPrice, required double stopLoss,
    required double tp1, required double tp2, required double tp3,
    required double tp4, required double tp5, required String patternName,
    required String entryTime, required String mode, required double qty,
    required int tpCount, required bool enableTrailing,
  }) async {
    final trade = ActiveTrade(
      symbol: symbol, entryPrice: entryPrice, stopLoss: stopLoss,
      tp1: tp1, tp2: tp2, tp3: tp3, tp4: tp4, tp5: tp5,
      patternName: patternName, entryTime: entryTime, tradingMode: mode, qty: qty,
      tpCount: tpCount, enableTrailing: enableTrailing,
    );
    await _trades.saveActiveTrade(trade);
    await _notif.trade(
      id: AppConstants.NOTIF_ID_SIGNAL,
      title: '🌱 ВХОД: $symbol (${mode == 'real' ? 'REAL' : 'PAPER'})',
      body: '$patternName\nВход: ${Formatters.price(entryPrice)} | Стоп: ${Formatters.price(stopLoss)}',
    );
    return trade;
  }

  Future<ExitEvent> checkExit(ActiveTrade coin, double currPrice) async {
    final symbol = coin.symbol;
    final entry = coin.entryPrice;
    final sl = coin.stopLoss;
    final remWeight = coin.remainingWeight;
    final realizedPct = coin.realizedPnlPct;
    final trailingActive = coin.tp3TrailingActive;
    var maxAfterTp3 = coin.maxPriceAfterTp3;

    double weightPerTp = 1.0 / coin.tpCount;
    if (coin.tpCount == 3) weightPerTp = 0.3; // Старая логика для 3 TP (30%, 30%, остаток 40%)
    else if (coin.tpCount == 1) weightPerTp = 1.0;
    else weightPerTp = 1.0 / coin.tpCount; // Для остальных делим равномерно

    // 1. TP1
    if (coin.tpCount >= 1 && !coin.tp1Done && currPrice >= coin.tp1) {
      final updated = coin.copyWith(
        tp1Done: true, stopLoss: entry,
        remainingWeight: remWeight - weightPerTp,
        realizedPnlPct: realizedPct + (15.0 * weightPerTp),
      );
      await _trades.saveActiveTrade(updated);
      await _updateExchangeSL(updated, tp1: true);
      await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🎯 TP1: $symbol', body: 'Зафиксировано | Стоп в БУ');
      return ExitEvent.tp1;
    }

    // 2. TP2
    if (coin.tpCount >= 2 && coin.tp1Done && !coin.tp2Done && currPrice >= coin.tp2) {
      final updated = coin.copyWith(
        tp2Done: true, stopLoss: coin.tp1,
        remainingWeight: remWeight - weightPerTp,
        realizedPnlPct: realizedPct + (35.0 * weightPerTp),
      );
      await _trades.saveActiveTrade(updated);
      await _updateExchangeSL(updated, tp2: true);
      await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🚀 TP2: $symbol', body: 'Зафиксировано | SL → TP1');
      return ExitEvent.tp2;
    }

    // 3. TP3
    if (coin.tpCount >= 3 && coin.tp2Done && !coin.tp3TrailingActive && currPrice >= coin.tp3) {
      // Если это последний TP и трейлинг включен — активируем его. Иначе просто фиксируем.
      final isLastTp = coin.tpCount == 3;
      if (isLastTp && coin.enableTrailing) {
        final activated = coin.copyWith(tp3TrailingActive: true, maxPriceAfterTp3: currPrice);
        await _trades.saveActiveTrade(activated);
        await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🔥 TP3 + Трейлинг: $symbol', body: 'Трейлинг активирован');
        return ExitEvent.tp3;
      } else {
        final updated = coin.copyWith(
          tp3TrailingActive: true, stopLoss: coin.tp2,
          remainingWeight: remWeight - weightPerTp,
          realizedPnlPct: realizedPct + (75.0 * weightPerTp),
        );
        await _trades.saveActiveTrade(updated);
        await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🔥 TP3: $symbol', body: 'Зафиксировано | SL → TP2');
        return ExitEvent.tp3;
      }
    }

    // 4. TP4
    if (coin.tpCount >= 4 && coin.tp3TrailingActive && !coin.tp4Done && currPrice >= coin.tp4) {
      final isLastTp = coin.tpCount == 4;
      if (isLastTp && coin.enableTrailing) {
        final activated = coin.copyWith(tp4Done: true, maxPriceAfterTp3: currPrice);
        await _trades.saveActiveTrade(activated);
        await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🔥 TP4 + Трейлинг: $symbol', body: 'Трейлинг активирован');
        return ExitEvent.tp4;
      } else {
        final updated = coin.copyWith(
          tp4Done: true, stopLoss: coin.tp3,
          remainingWeight: remWeight - weightPerTp,
          realizedPnlPct: realizedPct + (100.0 * weightPerTp),
        );
        await _trades.saveActiveTrade(updated);
        await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🔥 TP4: $symbol', body: 'Зафиксировано | SL → TP3');
        return ExitEvent.tp4;
      }
    }

    // 5. TP5
    if (coin.tpCount >= 5 && coin.tp4Done && !coin.tp5Done && currPrice >= coin.tp5) {
      final isLastTp = coin.tpCount == 5;
      if (isLastTp && coin.enableTrailing) {
        final activated = coin.copyWith(tp5Done: true, maxPriceAfterTp3: currPrice);
        await _trades.saveActiveTrade(activated);
        await _notif.trade(id: AppConstants.NOTIF_ID_TP, title: '🔥 TP5 + Трейлинг: $symbol', body: 'Трейлинг активирован');
        return ExitEvent.tp5;
      }
    }

    // Трейлинг (если активен)
    if (trailingActive) {
      if (currPrice > maxAfterTp3) {
        maxAfterTp3 = currPrice;
        await _trades.saveActiveTrade(coin.copyWith(maxPriceAfterTp3: maxAfterTp3));
      }
      final trailingStopPrice = maxAfterTp3 * (1.0 - AppConstants.TRAILING_PERCENT);
      if (currPrice <= trailingStopPrice) {
        final movePct = ((currPrice - entry) / entry) * 100.0;
        final totalNet = realizedPct + (movePct * remWeight);
        await _closePosition(coin, currPrice, 'Trailing Stop', totalNet);
        return ExitEvent.trailingClosed;
      }
    }

    // Стоп-лосс
    if (currPrice <= sl) {
      final movePct = ((currPrice - entry) / entry) * 100.0;
      final totalNet = realizedPct + (movePct * remWeight);
      final reason = !coin.tp1Done ? 'Stop Loss' : (coin.tp2Done ? 'SL в плюс' : 'Безубыток');
      await _closePosition(coin, currPrice, reason, totalNet);
      return ExitEvent.stopLoss;
    }

    return ExitEvent.none;
  }

  Future<void> _closePosition(ActiveTrade coin, double closePrice, String reason, double finalPnlPct) async {
    final isReal = coin.tradingMode == 'real';
    double pnlUsdt = 0.0;
    if (isReal) {
      try { await _trading.closeLong(symbol: coin.symbol, qty: coin.qty); } catch (_) {}
    } else {
      final currentBalance = _balance.getPaperBalance();
      pnlUsdt = currentBalance * (finalPnlPct / 100.0);
      await _balance.applyPnl(pnlUsdt, note: '$reason ${coin.symbol}');
    }
    final closed = ClosedTrade(
      symbol: coin.symbol, entryPrice: coin.entryPrice, closePrice: closePrice,
      reason: reason, finalNetPnlPct: finalPnlPct, closedAt: _nowMskFullStr(),
      pnlUsdt: pnlUsdt, tradingMode: coin.tradingMode, patternName: coin.patternName,
    );
    await _trades.recordClosedTrade(closed);
    await _notif.trade(id: AppConstants.NOTIF_ID_SL, title: '🏁 ЗАКРЫТО: ${coin.symbol}', body: '$reason | Итог: ${Formatters.percentSigned(finalPnlPct)}');
  }

  Future<void> _updateExchangeSL(ActiveTrade coin, {bool tp1 = false, bool tp2 = false}) async {
    if (coin.tradingMode != 'real') return;
    try {
      await _trading.updateStopLoss(
        symbol: coin.symbol, newStopLoss: coin.stopLoss,
        takeProfit: tp2 ? coin.tp2 : (tp1 ? coin.tp1 : null),
      );
    } catch (_) {}
  }

  String _nowMskStr() => DateTime.now().toUtc().add(const Duration(hours: 3)).toString().substring(0, 16);
  String _nowMskFullStr() => DateTime.now().toUtc().add(const Duration(hours: 3)).toString().substring(0, 19);
}
