// ==========================================================
//  ЭЙНШТЕЙН — Движок мониторинга выходов
//  Файл: lib/domain/exit_monitor_engine.dart
//  Порт shitcoin_exit_monitor_thread: раз в 25 сек проверяет
//  активные сделки по текущей цене и дергает PositionManager.
// ==========================================================
import 'dart:async';
import 'package:logger/logger.dart';
import '../data/repositories/trades_repository.dart';
import '../data/sources/bybit_api.dart';
import 'position_manager.dart';

class ExitMonitorEngine {
  ExitMonitorEngine._internal();
  static final ExitMonitorEngine instance = ExitMonitorEngine._internal();
  final _api = BybitApi.instance;
  final _trades = TradesRepository();
  final _pm = PositionManager.instance;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  Timer? _timer;
  bool _running = false;

  void start() {
    if (_timer != null) return;
    _log.i('🛡 ExitMonitorEngine запущен');
    _timer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _tick(),
    );
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _log.i('⏹ ExitMonitorEngine остановлен');
  }

  // ==========================================================
  // 🔄 ОДИН ПРОХОД
  // ==========================================================
  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      await _runMonitor();
    } catch (e, st) {
      _log.e('⚠ Ошибка exit-монитора: $e', error: e, stackTrace: st);
    } finally {
      _running = false;
    }
  }

  Future<void> _runMonitor() async {
    final actives = _trades.loadActiveTrades();
    if (actives.isEmpty) return;

    // ---------- Получаем все тикеры одним запросом ----------
    final tickers = await _api.getTickers();
    final prices = <String, double>{};
    for (final t in tickers) {
      final sym = (t['symbol'] ?? '').toString();
      final lp = _d(t['lastPrice']);
      if (sym.isNotEmpty && lp > 0) prices[sym] = lp;
    }

    // ---------- Проверяем каждую сделку ----------
    for (final coin in actives) {
      final curr = prices[coin.symbol];
      if (curr == null || curr <= 0) continue;
      try {
        await _pm.checkExit(coin, curr);
      } catch (e) {
        _log.w('⚠ Ошибка проверки ${coin.symbol}: $e');
      }
    }
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
