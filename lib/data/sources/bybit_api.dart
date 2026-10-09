// ==========================================================
//  ЭЙНШТЕЙН — HTTP-клиент Bybit V5 (ЧАСТЬ 1)
//  Файл: lib/data/sources/bybit_api.dart
// ==========================================================
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/candle.dart';

class BybitApiException implements Exception {
  final String message;
  final int? retCode;
  BybitApiException(this.message, {this.retCode});
  @override
  String toString() => 'BybitApiException($retCode): $message';
}

class BybitApi {
  BybitApi._internal() {
    _dio = _buildDio();
  }
  static final BybitApi instance = BybitApi._internal();

  String? _apiKey;
  String? _apiSecret;

  void setCredentials({String? apiKey, String? apiSecret}) {
    _apiKey = apiKey;
    _apiSecret = apiSecret;
  }

  bool get hasCredentials =>
      _apiKey != null && _apiKey!.isNotEmpty &&
      _apiSecret != null && _apiSecret!.isNotEmpty;

  late final Dio _dio;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static const int _maxAttempts = 5;
  static const int _rateLimitPauseMs = 15000;

  Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.BYBIT_BASE_URL,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: Duration(seconds: AppConstants.BYBIT_TIMEOUT_SEC),
      sendTimeout: Duration(seconds: AppConstants.BYBIT_TIMEOUT_SEC),
      validateStatus: (status) => status != null && status < 600,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _log.d('→ ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _log.d('← ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        _log.w('⚠ Ошибка: ${error.message} ${error.requestOptions.path}');
        handler.next(error);
      },
    ));
    return dio;
  }

  Map<String, String> _signHeaders({
    required int timestamp,
    String? queryString,
    String? jsonBody,
  }) {
    if (!hasCredentials) {
      throw BybitApiException('API-ключи не заданы. Установите их в настройках.');
    }
    final payload = StringBuffer()
      ..write(timestamp)
      ..write(_apiKey)
      ..write(AppConstants.BYBIT_RECV_WINDOW)
      ..write(queryString ?? jsonBody ?? '');
    final signature = Hmac(sha256, utf8.encode(_apiSecret!))
        .convert(utf8.encode(payload.toString()))
        .toString();
    return {
      'X-BAPI-API-KEY': _apiKey!,
      'X-BAPI-TIMESTAMP': timestamp.toString(),
      'X-BAPI-RECV-WINDOW': AppConstants.BYBIT_RECV_WINDOW.toString(),
      'X-BAPI-SIGN': signature,
    };
  }

  Future<Map<String, dynamic>> _safeCall({
    required String method,
    required String path,
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool isPrivate = false,
  }) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      await RateLimiter.instance.wait();
      try {
        Map<String, String>? headers;
        if (isPrivate) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          if (method == 'GET') {
            headers = _signHeaders(
              timestamp: timestamp,
              queryString: query != null ? _encodeQuery(query) : null,
            );
          } else {
            final json = body != null ? jsonEncode(body) : '';
            headers = _signHeaders(timestamp: timestamp, jsonBody: json);
          }
        }
        final response = await _dio.request(
          path,
          data: method == 'POST' ? body : null,
          queryParameters: method == 'GET' ? query : null,
          options: Options(method: method, headers: headers),
        );
        final data = response.data;
        if (data is! Map) {
          throw BybitApiException('Неверный формат ответа: $data');
        }
        final map = Map<String, dynamic>.from(data);
        final retCode = map['retCode'];
        if (retCode == 0) {
          return map;
        }
        if (retCode == 10002 || retCode == 10006 || retCode == 429) {
          _log.w('🕐 Bybit rate limit ($retCode), ждём ${_rateLimitPauseMs / 1000} сек');
          await Future.delayed(Duration(milliseconds: _rateLimitPauseMs));
          continue;
        }
        final msg = map['retMsg'] ?? 'Неизвестная ошибка';
        if (attempt == _maxAttempts) {
          throw BybitApiException(msg.toString(), retCode: retCode);
        }
        _log.w('⚠ Bybit $retCode: $msg. Попытка $attempt/$_maxAttempts');
        await Future.delayed(const Duration(seconds: 2));
      } on DioException catch (e) {
        final errStr = e.message?.toLowerCase() ?? '';
        final isRate = errStr.contains('429') || errStr.contains('too many requests') || errStr.contains('rate limit');
        final isNetwork = errStr.contains('timeout') || errStr.contains('connection') || errStr.contains('socket') || errStr.contains('network');
        if (isRate) {
          _log.w('🕐 Сетевое rate limit, ждём 15 сек');
          await Future.delayed(Duration(milliseconds: _rateLimitPauseMs));
          continue;
        }
        if (isNetwork) {
          final waitSec = 3 * attempt;
          _log.w('⚠ Сетевой сбой: ${e.message}. Повтор через $waitSec сек');
          await Future.delayed(Duration(seconds: waitSec));
          continue;
        }
        if (attempt == _maxAttempts) {
          throw BybitApiException('HTTP ошибка: ${e.message}');
        }
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        if (attempt == _maxAttempts) {
          throw BybitApiException('Неизвестная ошибка: $e');
        }
        _log.w('⚠ Исключение: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw BybitApiException('Не удалось выполнить запрос после $_maxAttempts попыток: $path');
  }

    String _encodeQuery(Map<String, dynamic> query) {
    final pairs = query.entries
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return pairs.join('&');
  }

  // ==========================================================
  // 📊 ПУБЛИЧНЫЕ МЕТОДЫ РЫНКА
  // ==========================================================
  Future<List<Map<String, dynamic>>> getTickers() async {
    final res = await _safeCall(
      method: 'GET',
      path: '/v5/market/tickers',
      query: {'category': AppConstants.BYBIT_CATEGORY},
    );
    final list = (res['result']?['list'] ?? []) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Candle>> getKline({
    required String symbol,
    required String interval,
    int limit = AppConstants.KLINE_LIMIT,
  }) async {
    final res = await _safeCall(
      method: 'GET',
      path: '/v5/market/kline',
      query: {
        'category': AppConstants.BYBIT_CATEGORY,
        'symbol': symbol,
        'interval': interval,
        'limit': limit,
      },
    );
    final raw = (res['result']?['list'] ?? []) as List;
    final candles = raw
        .map((e) => Candle.fromBybitList(e as List))
        .toList()
        .reversed
        .toList();
    return candles;
  }

  // ==========================================================
  // 💼 ПРИВАТНЫЕ МЕТОДЫ (реальная торговля, Вариант C)
  // ==========================================================
  Future<Map<String, dynamic>?> getPosition(String symbol) async {
    final res = await _safeCall(
      method: 'GET',
      path: '/v5/position/list',
      query: {
        'category': AppConstants.BYBIT_CATEGORY,
        'symbol': symbol,
      },
      isPrivate: true,
    );
    final list = (res['result']?['list'] ?? []) as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  Future<double> getWalletBalanceUsdt() async {
    final res = await _safeCall(
      method: 'GET',
      path: '/v5/account/wallet-balance',
      query: {'accountType': 'UNIFIED'},
      isPrivate: true,
    );
    final list = (res['result']?['list'] ?? []) as List;
    if (list.isEmpty) return 0.0;
    final coins = (list.first['coin'] ?? []) as List;
    for (final c in coins) {
      if (c['coin'] == 'USDT') {
        return double.tryParse((c['walletBalance'] ?? '0').toString()) ?? 0.0;
      }
    }
    return 0.0;
  }

  Future<void> setLeverage({
    required String symbol,
    required int leverage,
    int? buyLeverage,
    int? sellLeverage,
  }) async {
    final q = <String, dynamic>{
      'category': AppConstants.BYBIT_CATEGORY,
      'symbol': symbol,
      'buyLeverage': (buyLeverage ?? leverage).toString(),
      'sellLeverage': (sellLeverage ?? leverage).toString(),
    };
    await _safeCall(
      method: 'POST',
      path: '/v5/position/set-leverage',
      body: q,
      isPrivate: true,
    );
  }

  Future<String> placeMarketOrder({
    required String symbol,
    required String side,
    required double qty,
    int positionIdx = 0,
    bool reduceOnly = false,
    String? takeProfit,
    String? stopLoss,
  }) async {
    final body = <String, dynamic>{
      'category': AppConstants.BYBIT_CATEGORY,
      'symbol': symbol,
      'side': side,
      'orderType': 'Market',
      'qty': qty.toString(),
      'positionIdx': positionIdx,
      'timeInForce': 'IOC',
      if (reduceOnly) 'reduceOnly': true,
      if (takeProfit != null) 'takeProfit': takeProfit,
      if (stopLoss != null) 'stopLoss': stopLoss,
    };
    final res = await _safeCall(
      method: 'POST',
      path: '/v5/order/create',
      body: body,
      isPrivate: true,
    );
    final orderId = res['result']?['orderId']?.toString() ?? '';
    if (orderId.isEmpty) {
      throw BybitApiException('Bybit не вернул orderId');
    }
    return orderId;
  }

  Future<void> setTradingStop({
    required String symbol,
    required int positionIdx,
    required String stopLoss,
    String? takeProfit,
    String? trailingStop,
  }) async {
    final body = <String, dynamic>{
      'category': AppConstants.BYBIT_CATEGORY,
      'symbol': symbol,
      'positionIdx': positionIdx,
      'stopLoss': stopLoss,
      'tpslMode': 'Full',
      if (takeProfit != null) 'takeProfit': takeProfit,
      if (trailingStop != null) 'trailingStop': trailingStop,
    };
    await _safeCall(
      method: 'POST',
      path: '/v5/position/trading-stop',
      body: body,
      isPrivate: true,
    );
  }

  Future<String> closeMarketPosition({
    required String symbol,
    required int positionIdx,
    required double qty,
    required String currentSide,
  }) async {
    final closeSide = currentSide == 'Buy' ? 'Sell' : 'Buy';
    return placeMarketOrder(
      symbol: symbol,
      side: closeSide,
      qty: qty,
      positionIdx: positionIdx,
      reduceOnly: true,
    );
  }

  Future<Map<String, dynamic>?> getInstrumentInfo(String symbol) async {
    final res = await _safeCall(
      method: 'GET',
      path: '/v5/market/instruments-info',
      query: {
        'category': AppConstants.BYBIT_CATEGORY,
        'symbol': symbol,
      },
    );
    final list = (res['result']?['list'] ?? []) as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  // ==========================================================
  // 🧮 ХЕЛПЕРЫ И ПАТЧИ
  // ==========================================================
  static double roundToTick(double value, double tickSize) {
    if (tickSize <= 0) return value;
    final steps = (value / tickSize).round();
    return steps * tickSize;
  }

  static double roundToStep(double value, double qtyStep) {
    if (qtyStep <= 0) return value;
    final steps = (value / qtyStep).floorToDouble();
    return steps * qtyStep;
  }

  static String generateClientOrderId() {
    final rand = Random().nextInt(0x7FFFFFFF);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'EIN$ts$rand';
  }

  /// Переключить базовый URL (mainnet / testnet).
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }
}
