import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/rate_limiter.dart';
import '../models/candle.dart';
import '../repositories/system_repository.dart';

class BybitApiException implements Exception {
  final String message;
  final int? retCode;
  BybitApiException(this.message, {this.retCode});
  @override
  String toString() => 'BybitApiException($retCode): $message';
}

class BybitApi {
  BybitApi._internal();
  static final BybitApi instance = BybitApi._internal();

  String? _apiKey;
  String? _apiSecret;

  void setCredentials({String? apiKey, String? apiSecret}) {
    _apiKey = apiKey;
    _apiSecret = apiSecret;
  }

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  bool get hasCredentials =>
      _apiKey != null && _apiKey!.isNotEmpty &&
      _apiSecret != null && _apiSecret!.isNotEmpty;

  late final Dio _dio = _buildDio();
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static const int _maxAttempts = 5;
  static const int _rateLimitPauseMs = 15000;

  Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.BYBIT_BASE_URL,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 600,
      persistentConnection: false,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));

    // Настройка нативного HttpClient
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        client.connectionTimeout = const Duration(seconds: 30);
        // Форсируем IPv4 и отключаем HTTP/2 (частая причина таймаутов на Android)
        client.findProxy = (uri) => 'DIRECT';
        return client;
      },
    );

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
      throw BybitApiException('API-ключи не заданы.');
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
      final sw = Stopwatch()..start();
      await RateLimiter.instance.wait();

      try {
        Map<String, String>? headers;
        if (isPrivate || hasCredentials) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          if (method == 'GET') {
            headers = _signHeaders(timestamp: timestamp, queryString: query != null ? _encodeQuery(query) : null);
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
          sw.stop();
          SystemRepository.instance.logApiCall('Bybit', false, sw.elapsedMilliseconds, errorMsg: 'Не Map. Ответ: ${data.toString().substring(0, min(50, data.toString().length))}...');
          throw BybitApiException('Неверный формат ответа');
        }
        final map = Map<String, dynamic>.from(data);

        final retCode = map['retCode'];
        if (retCode == null) {
          sw.stop();
          SystemRepository.instance.logApiCall('Bybit', false, sw.elapsedMilliseconds, errorMsg: 'Пустой JSON: ${map.toString()}');
          throw BybitApiException('Нет retCode в ответе');
        }
        if (retCode == null) {
          sw.stop();
          SystemRepository.instance.logApiCall('Bybit', false, sw.elapsedMilliseconds, errorMsg: 'Нет retCode. Ответ: ${map.toString()}');
          throw BybitApiException('Неизвестный ответ: ${map.toString()}');
        }
        if (retCode == 0) {
          sw.stop();
          SystemRepository.instance.logApiCall('Bybit', true, sw.elapsedMilliseconds);
          return map;
        }

        sw.stop();
        final msg = map['retMsg'] ?? 'Неизвестная ошибка';
        SystemRepository.instance.logApiCall('Bybit', false, sw.elapsedMilliseconds, errorMsg: 'Code $retCode: $msg');

        if (retCode == 10002 || retCode == 10006 || retCode == 429) {
          await Future.delayed(Duration(milliseconds: _rateLimitPauseMs));
          continue;
        }

        if (attempt == _maxAttempts) throw BybitApiException(msg.toString(), retCode: retCode);
        await Future.delayed(const Duration(seconds: 2));
      } on DioException catch (e) {
        sw.stop();
        // Правильный вывод ошибки без литералов
        final errorText = e.toString();
        SystemRepository.instance.logApiCall('Bybit', false, sw.elapsedMilliseconds, errorMsg: 'NetError: $errorText');

        final errStr = e.message?.toLowerCase() ?? '';
        final isRate = errStr.contains('429') || errStr.contains('too many requests') || errStr.contains('rate limit');
        final isNetwork = errStr.contains('timeout') || errStr.contains('connection') || errStr.contains('socket') || errStr.contains('network');

        if (isRate) {
          await Future.delayed(Duration(milliseconds: _rateLimitPauseMs));
          continue;
        }
        if (isNetwork) {
          await Future.delayed(Duration(seconds: 3 * attempt));
          continue;
        }
        if (attempt == _maxAttempts) throw BybitApiException('HTTP ошибка: ${e.message}');
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        sw.stop();
        SystemRepository.instance.logApiCall('Bybit', false, sw.elapsedMilliseconds, errorMsg: e.toString());
        if (attempt == _maxAttempts) throw BybitApiException('Неизвестная ошибка: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    throw BybitApiException('Не удалось выполнить запрос после $_maxAttempts попыток: $path');
  }

  String _encodeQuery(Map<String, dynamic> query) {
    final pairs = query.entries.map((e) => '${e.key}=${e.value}').toList();
    return pairs.join('&');
  }

  Future<List<Map<String, dynamic>>> getTickers() async {
    final res = await _safeCall(method: 'GET', path: '/v5/market/tickers', query: {'category': AppConstants.BYBIT_CATEGORY});
    final list = (res['result']?['list'] ?? []) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Candle>> getKline({required String symbol, required String interval, int limit = AppConstants.KLINE_LIMIT}) async {
    final res = await _safeCall(
      method: 'GET', path: '/v5/market/kline',
      query: {'category': AppConstants.BYBIT_CATEGORY, 'symbol': symbol, 'interval': interval, 'limit': limit},
    );
    final raw = (res['result']?['list'] ?? []) as List;
    return raw.map((e) => Candle.fromBybitList(e as List)).toList().reversed.toList();
  }

  Future<Map<String, dynamic>?> getPosition(String symbol) async {
    final res = await _safeCall(method: 'GET', path: '/v5/position/list', query: {'category': AppConstants.BYBIT_CATEGORY, 'symbol': symbol}, isPrivate: true);
    final list = (res['result']?['list'] ?? []) as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  Future<double> getWalletBalanceUsdt() async {
    final res = await _safeCall(method: 'GET', path: '/v5/account/wallet-balance', query: {'accountType': 'UNIFIED'}, isPrivate: true);
    final list = (res['result']?['list'] ?? []) as List;
    if (list.isEmpty) return 0.0;
    final coins = (list.first['coin'] ?? []) as List;
    for (final c in coins) {
      if (c['coin'] == 'USDT') return double.tryParse((c['walletBalance'] ?? '0').toString()) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> setLeverage({required String symbol, required int leverage}) async {
    await _safeCall(method: 'POST', path: '/v5/position/set-leverage', body: {
      'category': AppConstants.BYBIT_CATEGORY, 'symbol': symbol,
      'buyLeverage': leverage.toString(), 'sellLeverage': leverage.toString(),
    }, isPrivate: true);
  }

  Future<String> placeMarketOrder({
    required String symbol, required String side, required double qty,
    int positionIdx = 0, bool reduceOnly = false, String? takeProfit, String? stopLoss,
  }) async {
    final body = <String, dynamic>{
      'category': AppConstants.BYBIT_CATEGORY, 'symbol': symbol, 'side': side,
      'orderType': 'Market', 'qty': qty.toString(), 'positionIdx': positionIdx, 'timeInForce': 'IOC',
      if (reduceOnly) 'reduceOnly': true,
      if (takeProfit != null) 'takeProfit': takeProfit,
      if (stopLoss != null) 'stopLoss': stopLoss,
    };
    final res = await _safeCall(method: 'POST', path: '/v5/order/create', body: body, isPrivate: true);
    return res['result']?['orderId']?.toString() ?? '';
  }

  Future<void> setTradingStop({required String symbol, required int positionIdx, required String stopLoss, String? takeProfit}) async {
    await _safeCall(method: 'POST', path: '/v5/position/trading-stop', body: {
      'category': AppConstants.BYBIT_CATEGORY, 'symbol': symbol, 'positionIdx': positionIdx,
      'stopLoss': stopLoss, 'tpslMode': 'Full',
      if (takeProfit != null) 'takeProfit': takeProfit,
    }, isPrivate: true);
  }

  Future<String> closeMarketPosition({required String symbol, required int positionIdx, required double qty, required String currentSide}) async {
    return placeMarketOrder(symbol: symbol, side: currentSide == 'Buy' ? 'Sell' : 'Buy', qty: qty, positionIdx: positionIdx, reduceOnly: true);
  }

  Future<Map<String, dynamic>?> getInstrumentInfo(String symbol) async {
    final res = await _safeCall(method: 'GET', path: '/v5/market/instruments-info', query: {'category': AppConstants.BYBIT_CATEGORY, 'symbol': symbol});
    final list = (res['result']?['list'] ?? []) as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  static double roundToTick(double value, double tickSize) => tickSize <= 0 ? value : (value / tickSize).round() * tickSize;
  static double roundToStep(double value, double qtyStep) => qtyStep <= 0 ? value : (value / qtyStep).floorToDouble() * qtyStep;
  static String generateClientOrderId() => 'EIN${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(0x7FFFFFFF)}';
}
