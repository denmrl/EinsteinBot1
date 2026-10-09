// ==========================================================
//  ЭЙНШТЕЙН — Сборщик ежедневного отчёта (аналог Python 22:00 МСК)
//  Файл: lib/domain/report_builder.dart
//  Формирует:
//    • список активных сделок с текущим PnL;
//    • список наблюдаемых монет;
//    • винрейт и коэффициент Прибыль/Убыток;
//    • сумму профита/убытка в % и в USDT/RUB.
// ==========================================================
import 'package:logger/logger.dart';
import '../core/services/notification_service.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/balance_repository.dart';
import '../data/repositories/trades_repository.dart';
import '../data/sources/bybit_api.dart';

class ReportBuilder {
  ReportBuilder._internal();
  static final ReportBuilder instance = ReportBuilder._internal();
  final _trades = TradesRepository();
  final _balance = BalanceRepository.instance;
  final _notif = NotificationService.instance;
  final _api = BybitApi.instance;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  // ==========================================================
  // 📊 СБОРКА И ОТПРАВКА
  // ==========================================================
  /// Собрать и отправить отчёт. Вызывается из DailyScheduler.
  Future<void> buildAndSend() async {
    final now = _nowMsk();
    final dateStr = '${_two(now.day)}.${_two(now.month)}.${now.year}';
    
    final active = _trades.loadActiveTrades();
    final watched = _trades.loadWatchedSetups();
    final history = _trades.loadHistory();
    
    final prices = <String, double>{};
    if (active.isNotEmpty) {
      try {
        final tickers = await _api.getTickers();
        for (final t in tickers) {
          final sym = (t['symbol'] ?? '').toString();
          final lp = _d(t['lastPrice']);
          if (sym.isNotEmpty && lp > 0) prices[sym] = lp;
        }
      } catch (e) {
        _log.w('⚠ Не удалось получить цены для отчёта: $e');
      }
    }
    
    final paperBalance = _balance.getPaperBalance();
    final rate = await _balance.getUsdRubRate();
    final balanceRub = paperBalance * rate;
    
    final totalTrades = history.length;
    final wins = history.where((t) => t.isWin).toList();
    final losses = history.where((t) => !t.isWin).toList();
    final winRate = totalTrades > 0 ? (wins.length / totalTrades) * 100 : 0.0;
    final totalGainPct = wins.fold<double>(0.0, (s, t) => s + t.finalNetPnlPct);
    final totalLossPct = losses.fold<double>(0.0, (s, t) => s + t.finalNetPnlPct.abs());
    final ratioStr = totalLossPct > 0 ? (totalGainPct / totalLossPct).toStringAsFixed(2) : '∞';
    
    final totalPnlUsdt = history.fold<double>(0.0, (s, t) => s + t.pnlUsdt);
    final totalPnlRub = totalPnlUsdt * rate;
    
    final buf = StringBuffer();
    buf.writeln('📊 ЕЖЕДНЕВНЫЙ ОТЧЁТ ($dateStr)');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('💼 Баланс: ${Formatters.usdt(paperBalance)} / ${Formatters.rub(balanceRub)}');
    buf.writeln('');
    
    buf.writeln('1️⃣ АКТИВНЫЕ СДЕЛКИ (${active.length}):');
    if (active.isEmpty) {
      buf.writeln('   нет открытых позиций');
    } else {
      for (final c in active) {
        final curr = prices[c.symbol] ?? c.entryPrice;
        final pnl = ((curr - c.entryPrice) / c.entryPrice) * 100.0;
        buf.writeln('   • ${c.symbol}: ${Formatters.price(c.entryPrice)} → ${Formatters.price(curr)} (${Formatters.percentSigned(pnl)})');
      }
    }
    buf.writeln('');
    
    buf.writeln('2️⃣ НАБЛЮДЕНИЕ (${watched.length}):');
    if (watched.isEmpty) {
      buf.writeln('   лист наблюдений пуст');
    } else {
      for (final w in watched) {
        buf.writeln('   • ${w.symbol}: ${w.patternName} (триггер ${Formatters.price(w.triggerPrice)})');
      }
    }
    buf.writeln('');
    
    buf.writeln('3️⃣ ВИНРЕЙТ: ${winRate.toStringAsFixed(1)}% (Побед: ${wins.length} / Сделок: $totalTrades)');
    buf.writeln('');
    buf.writeln('4️⃣ ЧИСТОЕ ДВИЖЕНИЕ (%):');
    buf.writeln('   🟢 Профит: +${totalGainPct.toStringAsFixed(2)}%');
    buf.writeln('   🔴 Убыток: -${totalLossPct.toStringAsFixed(2)}%');
    buf.writeln('   ⚖️  Коэфф. Прибыль/Убыток: $ratioStr');
    buf.writeln('');
    buf.writeln('5️⃣ PnL ЗА ВСЁ ВРЕМЯ:');
    buf.writeln('   ${Formatters.percentSigned(totalPnlUsdt > 0 ? (totalPnlUsdt / 1000.0) * 100 : 0)} | ${Formatters.usdt(totalPnlUsdt)} | ${Formatters.rub(totalPnlRub)}');
    
    final body = buf.toString();
    await _notif.report(
      title: '📊 Отчёт за $dateStr (22:00 МСК)',
      body: body,
    );
    _log.i('✅ Ежедневный отчёт отправлен ($dateStr)');
  }

  DateTime _nowMsk() => DateTime.now().toUtc().add(const Duration(hours: 3));
  String _two(int v) => v.toString().padLeft(2, '0');
  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
