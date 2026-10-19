import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class ExternalApi {
  ExternalApi._internal();
  static final ExternalApi instance = ExternalApi._internal();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  final Map<String, ({double cap, DateTime time})> _capCache = {};
  final Map<String, ({bool hasUnlock, DateTime time})> _unlockCache = {};

  Future<double?> getMarketCap(String symbol) async {
    final ticker = symbol.replaceAll('USDT', '').toLowerCase();
    final now = DateTime.now();

    if (_capCache.containsKey(ticker)) {
      final cached = _capCache[ticker]!;
      if (now.difference(cached.time).inHours < 24) return cached.cap;
    }

    try {
      final res = await _dio.get(
        'https://api.coingecko.com/api/v3/coins/markets',
        queryParameters: {'vs_currency': 'usd', 'symbols': ticker},
      );
      if (res.data != null && (res.data as List).isNotEmpty) {
        final cap = (res.data[0]['market_cap'] as num?)?.toDouble() ?? 0.0;
        _capCache[ticker] = (cap: cap, time: now);
        return cap;
      }
    } catch (e) {
      _log.w('⚠ CoinGecko error for $ticker: $e');
    }
    return null;
  }

  Future<bool> hasUpcomingUnlock(String symbol) async {
    final ticker = symbol.replaceAll('USDT', '').toUpperCase();
    final now = DateTime.now();

    if (_unlockCache.containsKey(ticker)) {
      final cached = _unlockCache[ticker]!;
      if (now.difference(cached.time).inHours < 12) return cached.hasUnlock;
    }

    // Заглушка (когда получишь ключ DropsTab, раскомментируешь реальный запрос)
    bool hasUnlock = false;
    _unlockCache[ticker] = (hasUnlock: hasUnlock, time: now);
    return hasUnlock;
  }
}
