// ==========================================================
//  ЭЙНШТЕЙН — Менеджер позиций (TP1/TP2/TP3/Trailing/BE)
//  Файл: lib/domain/position_manager.dart
//  • Решает, куда открывать сделку: Paper или Real.
//  • Сопровождает позицию по TP-этапам.
//  • Фиксирует закрытие в истории и обновляет баланс.
// ==========================================================

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

/// Что произошло по позиции за один проход exit-монитора.
enum ExitEvent { tp1, tp2, tp3, trailingClosed, stopLoss, none }

class PositionManager {
  PositionManager._internal();
  static final PositionManager instance = PositionManager._internal();

  final _trades = TradesRepository();
  final _balance = BalanceRepository.instance;
  final _settings = SettingsRepository.instance;
  final _trading = BybitTradingService.instance;
  final _notif = NotificationService.instance;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  // ==========================================================
  // 🟢 ОТКРЫТИЕ ПОЗИЦИИ
  // ==========================================================
  /// Открывает позицию в зависимости от текущего режима.
  /// Возвращает созданный ActiveTrade или null, если что-то пошло не так.
  Future<ActiveTrade?> openPosition({
    required String symbol,
    required double entryPrice,
    required double stopLoss,
    required String patternName,
  }) async {
    final settings = await _settings.load();
    final isReal = settings.tradingMode == TradingMode.real;

    // ---------- Расчёт уровней TP ----------
    final tp1 = entryPrice * settings.tp1Multiplier;
    final tp2 = entryPrice * settings.tp2Multiplier;
    final tp3 = entryPrice * settings.tp3Multiplier;

    // ---------- Подготовка записи ----------
    final entryTime = _nowMskStr();
    double qty = 0.0;

    if (isReal) {
      // ---------- Реальный режим ----------
      try {
        final creds = await _settings.loadBybitCredentials();
        if (creds == null) {
          _log.w('⚠ Нет API-ключей — вход отменён');
          return null;
        }
        _trading.switchToMainnet(); // TODO: вернуть переключение по env
        // Получаем баланс и считаем qty по риску.
        final bal = await _trading.getWalletBalanceUsdt();
        qty = await _trading.computeQtyFromRisk(
          symbol: symbol,
          balanceUsdt: bal,
          riskPct: settings.riskPerTradePct,
          entryPrice: entryPrice,
          stopLoss: stopLoss,
          leverage: settings.leverage,
        );
        // Отправляем ордер и получаем фактическую цену входа.
        final res = await _trading.openLong(
          symbol: symbol,
          qty: qty,
          leverage: settings.leverage,
          stopLoss: stopLoss,
        );
        qty = res.qty;
        // Обновляем entryPrice фактической ценой исполнения.
        final realEntry = res.entryPrice > 0 ? res.entryPrice : entryPrice;
        return await _persistNewTrade(
          symbol: symbol,
          entryPrice: realEntry,
          stopLoss: stopLoss,
          tp1: realEntry * settings.tp1Multiplier,
          tp2: realEntry * settings.tp2Multiplier,
          tp3: realEntry * settings.tp3Multiplier,
          patternName: patternName,
          entryTime: entryTime,
          mode: 'real',
          qty: qty,
        );
      } catch (e) {
        _log.e('❌ Ошибка реального входа: $e');
        await _notif.signal(
          title: '❌ Не удалось открыть $symbol',
          body: '$e',
        );
        return null;
      }
    }

    // ---------- Paper-режим ----------
    return await _persistNewTrade(
      symbol: symbol,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      tp3: tp3,
      patternName: patternName,
      entryTime: entryTime,
      mode: 'paper',
      qty: 0.0,
    );
  }

  Future<ActiveTrade> _persistNewTrade({
    required String symbol,
    required double entryPrice,
    required double stopLoss,
    required double tp1,
    required double tp2,
    required double tp3,
    required String patternName,
    required String entryTime,
    required String mode,
    required double qty,
  }) async {
    final trade = ActiveTrade(
      symbol: symbol,
      entryPrice: entryPrice,
      stopLoss: stopLoss,
      tp1: tp1,
      tp2: tp2,
      tp3: tp3,
      patternName: patternName,
      entryTime: entryTime,
      tradingMode: mode,
      qty: qty, // ⚠️ требует патча модели (см. шапку)
    );
    await _trades.saveActiveTrade(trade);

    await _notif.trade(
      id: AppConstants.NOTIF_ID_SIGNAL,
      title: '🌱 ВХОД: $symbol (${mode == 'real' ? 'REAL' : 'PAPER'})',
      body: '$patternName\n'
          'Вход: ${Formatters.price(entryPrice)} | '
          'Стоп: ${Formatters.price(stopLoss)}',
    );
    _log.i('🟢 Открыт $symbol @ $entryPrice (${mode})');
    return trade;
  }

  // ==========================================================
  // 🔄 ПРОВЕРКА ВЫХОДА ПО ТЕКУЩЕЙ ЦЕНЕ
  // ==========================================================
  /// Возвращает событие, которое произошло, или ExitEvent.none.
  /// Может закрыть позицию внутри себя (тогда запись удаляется из Hive).
  Future<ExitEvent> checkExit(ActiveTrade coin, double currPrice) async {
    final symbol = coin.symbol;
    final entry = coin.entryPrice;
    final sl = coin.stopLoss;
    final tp1 = coin.tp1;
    final tp2 = coin.tp2;
    final tp3 = coin.tp3;
    final remWeight = coin.remainingWeight;
    final realizedPct = coin.realizedPnlPct;
    final trailingActive = coin.tp3TrailingActive;
    var maxAfterTp3 = coin.maxPriceAfterTp3;

    // ---------- 1. TP1 (+15%) ----------
    if (!coin.tp1Done && currPrice >= tp1) {
      const gain = 15.0 * AppConstants.TP1_CLOSE_SHARE;
      final updated = coin.copyWith(
        tp1Done: true,
        stopLoss: entry,                                        // в БУ
        remainingWeight: (remWeight - AppConstants.TP1_CLOSE_SHARE),
        realizedPnlPct: realizedPct + gain,
      );
      await _trades.saveActiveTrade(updated);
      await _updateExchangeSL(updated, tp1: true);

      await _notif.trade(
        id: AppConstants.NOTIF_ID_TP,
        title: '🎯 TP1: $symbol',
        body: 'Зафиксировано 30% | Стоп в БУ (${Formatters.price(entry)})',
      );
      _log.i('🎯 $symbol TP1 — фикс 30%');
      return ExitEvent.tp1;
    }

    // ---------- 2. TP2 (+35%) ----------
    if (coin.tp1Done && !coin.tp2Done && currPrice >= tp2) {
      const gain = 35.0 * AppConstants.TP2_CLOSE_SHARE;
      final updated = coin.copyWith(
        tp2Done: true,
        stopLoss: tp1,                                          // SL на TP1
        remainingWeight: (remWeight - AppConstants.TP2_CLOSE_SHARE),
        realizedPnlPct: realizedPct + gain,
      );
      await _trades.saveActiveTrade(updated);
      await _updateExchangeSL(updated, tp2: true);

      await _notif.trade(
        id: AppConstants.NOTIF_ID_TP,
        title: '🚀 TP2: $symbol',
        body: 'Зафиксировано ещё 30% | SL → TP1 (${Formatters.price(tp1)})',
      );
      _log.i('🚀 $symbol TP2 — фикс ещё 30%');
      return ExitEvent.tp2;
    }

    // ---------- 3. TP3 (+75%) → активация трейлинга ----------
    if (!trailingActive && currPrice >= tp3) {
      final activated = coin.copyWith(
        tp3TrailingActive: true,
        maxPriceAfterTp3: currPrice,
      );
      await _trades.saveActiveTrade(activated);

      await _notif.trade(
        id: AppConstants.NOTIF_ID_TP,
        title: '🔥 ВЗЯТ TP3: $symbol',
        body: 'Трейлинг-стоп 15% активирован',
      );
      _log.i('🔥 $symbol TP3 — трейлинг активирован');
      return ExitEvent.tp3;
    }

    // ---------- 4. Трейлинг-стоп ----------
    if (trailingActive) {
      if (currPrice > maxAfterTp3) {
        maxAfterTp3 = currPrice;
        final updated = coin.copyWith(maxPriceAfterTp3: maxAfterTp3);
        await _trades.saveActiveTrade(updated);
      }
      final trailingStopPrice =
          maxAfterTp3 * (1.0 - AppConstants.TRAILING_PERCENT);

      if (currPrice <= trailingStopPrice) {
        final movePct = ((currPrice - entry) / entry) * 100.0;
        final totalNet = realizedPct + (movePct * remWeight);
        await _closePosition(coin, currPrice, 'Trailing Stop 15%', totalNet);
        return ExitEvent.trailingClosed;
      }
      return ExitEvent.none; // пока живём
    }

    // ---------- 5. Стоп-лосс / БУ ----------
    if (currPrice <= sl) {
      final movePct = ((currPrice - entry) / entry) * 100.0;
      final totalNet = realizedPct + (movePct * remWeight);
      final reason = !coin.tp1Done
          ? 'Stop Loss'
          : (coin.tp2Done ? 'SL на TP1' : 'Безубыток');
      await _closePosition(coin, currPrice, reason, totalNet);
      return ExitEvent.stopLoss;
    }

    return ExitEvent.none;
  }

  // ==========================================================
  // 🛑 ЗАКРЫТИЕ ПОЗИЦИИ
  // ==========================================================
  Future<void> _closePosition(
    ActiveTrade coin,
    double closePrice,
    String reason,
    double finalPnlPct,
  ) async {
    final symbol = coin.symbol;
    final isReal = coin.tradingMode == 'real';

    // ---------- Paper: обновляем виртуальный баланс ----------
    // ---------- Real : закрываем ордер на бирже и читаем фактический баланс ----------
    double pnlUsdt = 0.0;
    if (isReal) {
      try {
        await _trading.closeLong(symbol: symbol, qty: coin.qty);
        // Небольшая пауза, чтобы биржа обновила баланс.
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        _log.e('❌ Ошибка закрытия на бирже: $e');
      }
    } else {
      // В Paper считаем PnL в USDT от текущего баланса.
      final currentBalance = _balance.getPaperBalance();
      final positionUsdt = currentBalance * (1.0); // условный размер = 100% баланса
      pnlUsdt = positionUsdt * (finalPnlPct / 100.0);
      await _balance.applyPnl(
        pnlUsdt,
        note: '$reason $symbol (${finalPnlPct.toStringAsFixed(2)}%)',
      );
    }

    // ---------- Запись в историю ----------
    final closed = ClosedTrade(
      symbol: symbol,
      entryPrice: coin.entryPrice,
      closePrice: closePrice,
      reason: reason,
      finalNetPnlPct: finalPnlPct,
      closedAt: _nowMskFullStr(),
      pnlUsdt: pnlUsdt,
      tradingMode: coin.tradingMode,
      patternName: coin.patternName,
    );
    await _trades.recordClosedTrade(closed);

    // ---------- Пуш ----------
    await _notif.trade(
      id: AppConstants.NOTIF_ID_SL,
      title: '🏁 ЗАКРЫТО: $symbol',
      body: '$reason | Итог: ${Formatters.percentSigned(finalPnlPct)}',
    );
    _log.i('🏁 $symbol закрыт ($reason) → ${finalPnlPct.toStringAsFixed(2)}%');
  }

  // ==========================================================
  // 🔄 СИНХРОНИЗАЦИЯ SL С БИРЖЕЙ (только для real)
  // ==========================================================
  Future<void> _updateExchangeSL(
    ActiveTrade coin, {
    bool tp1 = false,
    bool tp2 = false,
  }) async {
    if (coin.tradingMode != 'real') return;
    try {
      await _trading.updateStopLoss(
        symbol: coin.symbol,
        newStopLoss: coin.stopLoss,
        takeProfit: tp2 ? coin.tp2 : (tp1 ? coin.tp1 : null),
      );
    } catch (e) {
      _log.w('⚠ Не удалось обновить SL на бирже: $e');
    }
  }

  // ==========================================================
  // 🕒 ВРЕМЯ
  // ==========================================================
  String _nowMskStr() {
    // МСК = UTC+3. Универсальный формат — без tz-конвертаций.
    final nowUtc = DateTime.now().toUtc();
    final msk = nowUtc.add(const Duration(hours: 3));
    return '${msk.year}-${_two(msk.month)}-${_two(msk.day)} '
        '${_two(msk.hour)}:${_two(msk.minute)}';
  }

  String _nowMskFullStr() {
    final nowUtc = DateTime.now().toUtc();
    final msk = nowUtc.add(const Duration(hours: 3));
    return '${msk.year}-${_two(msk.month)}-${_two(msk.day)} '
        '${_two(msk.hour)}:${_two(msk.minute)}:${_two(msk.second)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}