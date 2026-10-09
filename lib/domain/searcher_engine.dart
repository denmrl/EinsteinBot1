import 'dart:async';

import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../core/utils/formatters.dart';
import '../core/utils/indicators.dart';
import '../data/models/candle.dart';
import '../data/models/watched_setup.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/trades_repository.dart';
import '../data/sources/bybit_api.dart';
import '../data/sources/kline_cache.dart';
import 'macro_analyzer.dart';
import 'pattern_detector.dart';
import 'position_manager.dart';

class SearcherEngine {
  SearcherEngine._internal();
  static final SearcherEngine instance = SearcherEngine._internal();

  final _api = BybitApi.instance;
  final _cache = KlineCache.instance;
  final _trades = TradesRepository();
  final _settings = SettingsRepository.instance;
  final _notif = NotificationService.instance;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  Timer? _timer;
  bool _running = false;

  void start() {
    if (_timer != null) return;
    _log.i('SearcherEngine запущен');
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _log.i('SearcherEngine остановлен');
  }

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      await _runScan();
    } catch (e, st) {
      _log.e('Ошибка сканера: $e', error: e, stackTrace: st);
    } finally {
      _running = false;
    }
  }

  Future<void> _runScan() async {
    final settings = await _settings.load();
    final activeSymbols = _trades.activeSymbols();
    final watchedSymbols = _trades.watchedSymbols();

    final tickers = await _api.getTickers();
    if (tickers.isEmpty) return;

    final valid = <Map<String, dynamic>>[];
    for (final t in tickers) {
      final sym = (t['symbol'] ?? '').toString();
      if (!sym.endsWith('USDT')) continue;
      if (AppConstants.EXCLUDE_SYMBOLS.contains(sym)) continue;

      final turnover = _d(t['turnover24h']);
      final oi = _d(t['openInterestValue']);
      final p24 = _d(t['price24hPcnt']).abs() * 100.0;
      final estCap = turnover * settings.capMultiplier;

      if (turnover < settings.minTurnover24h ||
          turnover > settings.maxTurnover24h) continue;
      if (oi < settings.minOpenInterest) continue;
      if (estCap < settings.minEstimatedCap ||
          estCap > settings.maxEstimatedCap) continue;
      if (p24 < 1.5 && !watchedSymbols.contains(sym)) continue;

      valid.add(t);
    }

    final watched = _trades.loadWatchedSetups();
    for (final w in watched) {
      if (activeSymbols.contains(w.symbol)) continue;
      await _checkWatched(w);
    }

    valid.sort(
        (a, b) => _d(b['turnover24h']).compareTo(_d(a['turnover24h'])));
    final batch = valid.take(30).toList();

    for (final t in batch) {
      final sym = (t['symbol'] ?? '').toString();
      if (activeSymbols.contains(sym) || watchedSymbols.contains(sym)) {
        continue;
      }
      await _scanNewCandidate(sym, _d(t['lastPrice']));
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _checkWatched(WatchedSetup w) async {
    final sym = w.symbol;
    final c5 = await _fetchKline(sym, '5');
    final c15 = await _fetchKline(sym, '15');
    final c1h = await _fetchKline(sym, '60');
    if (c5.isEmpty || c15.isEmpty || c1h.isEmpty) return;

    final m5Close = c5.last.close;
    final check1h = c1h.length >= 2 ? c1h[c1h.length - 2] : c1h.last;

    if (Indicators.isStrongHistoricalLowBreakout(check1h, w.historicalLow)) {
      await _trades.removeWatchedTrade(sym);
      await _notif.signal(
        title: 'Отмена: $sym',
        body: 'Пробой исторического дна на 1H',
      );
      return;
    }

    final closes15 = c15.map((c) => c.close).toList();
    final ema9 = Indicators.ema(closes15, AppConstants.EMA_FAST).last;
    final ema20 = Indicators.ema(closes15, AppConstants.EMA_SLOW).last;
    final rsi15 = Indicators.rsi(closes15, period: AppConstants.RSI_PERIOD);

    final prevVols = c15
        .sublist(c15.length - 10, c15.length - 1)
        .map((c) => c.volume)
        .toList();
    final avgVol = prevVols.isEmpty
        ? 1.0
        : prevVols.reduce((a, b) => a + b) / prevVols.length;
    final volSpike = avgVol > 0 ? c15.last.volume / avgVol : 1.0;

    final confirmed =
        (volSpike >= AppConstants.ENTRY_VOLUME_SPIKE ||
                m5Close >= w.triggerPrice) &&
            ema9 > ema20 &&
            rsi15 <= AppConstants.RSI_MAX_ENTRY;

    if (!confirmed) return;

    final entryP = m5Close;
    final stopLoss = w.patternLow > 0
        ? w.patternLow * AppConstants.SL_PATTERN_LOW_MULTIPLIER
        : entryP * AppConstants.SL_FALLBACK_MULTIPLIER;

    await PositionManager.instance.openPosition(
      symbol: sym,
      entryPrice: entryP,
      stopLoss: stopLoss,
      patternName: w.patternName,
    );
  }

  Future<void> _scanNewCandidate(String symbol, double lastPrice) async {
    final c1d = await _fetchKline(symbol, 'D');
    final c1h = await _fetchKline(symbol, '60');
    if (c1d.isEmpty || c1h.isEmpty) return;

    final macro = MacroAnalyzer.analyze(dCandles: c1d, h1Candles: c1h);
    if (!macro.ok) return;

    final c15 = await _fetchKline(symbol, '15');
    final c5 = await _fetchKline(symbol, '5');
    final pat = PatternDetector.detect(candles15m: c15, candles5m: c5);
    if (!pat.found) return;

    final trigP = lastPrice * AppConstants.TRIGGER_MULTIPLIER;
    final setup = WatchedSetup(
      symbol: symbol,
      patternName: pat.name ?? 'Паттерн',
      detectedPrice: lastPrice,
      triggerPrice: trigP,
      patternLow: pat.patternLow,
      historicalLow: macro.historicalLow,
      detectedAt: _nowHm(),
      macroReason: macro.reason,
    );
    await _trades.saveWatchedSetup(setup);

    await _notif.signal(
      title: 'Наблюдение: $symbol',
      body: '${pat.name}\n'
          'Цена: ${Formatters.price(lastPrice)} | '
          'Триггер: ${Formatters.price(trigP)}\n'
          '${macro.reason}',
    );
  }

  Future<List<Candle>> _fetchKline(String symbol, String interval) async {
    final cached = _cache.get(symbol, interval);
    if (cached != null) return cached;

    final list = await _api.getKline(symbol: symbol, interval: interval);
    _cache.put(symbol, interval, list);
    return list;
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _nowHm() {
    final utc = DateTime.now().toUtc();
    final msk = utc.add(const Duration(hours: 3));
    return '${_two(msk.hour)}:${_two(msk.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}