// ==========================================================
//  ЭЙНШТЕЙН — Репозиторий демо-баланса и курса USD/RUB
//  Файл: lib/data/repositories/balance_repository.dart
//  • Виртуальный баланс для Paper Trading (старт: 1000 USDT).
//  • История изменения баланса — для графика в статистике.
//  • Курс USD/RUB — скачиваем из ЦБ РФ раз в 24 часа и кэшируем.
// ==========================================================
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import '../../core/constants/app_constants.dart';
/// Точка на графике баланса.
/// Храним в Hive как Map<String, dynamic>.
class BalancePoint {
  final DateTime timestamp;   // когда зафиксировали
  final double balance;       // баланс в USDT
  final String note;          // например, "TP1 AIUSDT", "SL BTCUSDT"
  const BalancePoint({
    required this.timestamp,
    required this.balance,
    this.note = '',
  });
  Map<String, dynamic> toMap() => {
        'ts': timestamp.millisecondsSinceEpoch,
        'balance': balance,
        'note': note,
      };
  factory BalancePoint.fromMap(Map<dynamic, dynamic> m) => BalancePoint(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (m['ts'] as num?)?.toInt() ?? 0),
        balance: ((m['balance'] as num?)?.toDouble()) ?? 0.0,
        note: (m['note'] ?? '').toString(),
      );
}
/// Репозиторий баланса и курса. Синглтон.
class BalanceRepository {
  BalanceRepository._internal();
  static final BalanceRepository instance = BalanceRepository._internal();
  // ---------- Ключи внутри Hive-бокса SETTINGS ----------
  static const _kPaperBalance        = 'balance.paper_usdt';
  static const _kUsdRubRate          = 'balance.usd_rub';
  static const _kUsdRubFetchedAtMs   = 'balance.usd_rub_fetched_ms';
  /// Срок жизни курса — 24 часа.
  static const _rateTtlHours = 24;
  /// Начальный баланс для демо (1000 USDT).
  static const double _paperStartBalance = AppConstants.PAPER_START_BALANCE_USDT;
  final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
  Box get _settingsBox => Hive.box(AppConstants.BOX_SETTINGS);
  Box get _balanceHistoryBox => Hive.box(AppConstants.BOX_BALANCE_HISTORY);
  // ==========================================================
  // 💰 ДЕМО-БАЛАНС (Paper Trading)
  // ==========================================================
  /// Текущий демо-баланс в USDT.
  /// Если ещё ничего не сохраняли — считаем, что это 1000.
  double getPaperBalance() {
    final v = _settingsBox.get(_kPaperBalance);
    if (v == null) return _paperStartBalance;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? _paperStartBalance;
  }
  /// Установить новый демо-баланс и записать точку в историю графика.
  /// [note] — короткая метка, например "Закрытие AIUSDT +12.5%".
  Future<void> setPaperBalance(double newBalance, {String note = ''}) async {
    await _settingsBox.put(_kPaperBalance, newBalance);
    // Пишем точку в историю баланса (с автоинкрементным ключом).
    final history = _balanceHistoryBox;
    final nextKey = history.isEmpty
        ? 1
        : (history.keys
                    .whereType<int>()
                    .fold<int>(0, (a, b) => a > b ? a : b)) +
            1;
    final point = BalancePoint(
      timestamp: DateTime.now(),
      balance: newBalance,
      note: note,
    );
    await history.put(nextKey, point.toMap());
  }
  /// Применить результат закрытой сделки к балансу.
  /// [pnlUsdt] — абсолютная прибыль/убыток в USDT.
  /// Возвращает новый баланс.
  Future<double> applyPnl(double pnlUsdt, {String note = ''}) async {
    final current = getPaperBalance();
    final updated = current + pnlUsdt;
    await setPaperBalance(updated, note: note);
    return updated;
  }
  /// Полный сброс демо-баланса к 1000 USDT (для кнопки «Сброс» в настройках).
  /// Очищает также историю графика.
  Future<void> resetPaperAccount() async {
    await _settingsBox.put(_kPaperBalance, _paperStartBalance);
    await _balanceHistoryBox.clear();
    await setPaperBalance(_paperStartBalance, note: 'Старт демо');
  }
  /// Вся история баланса, отсортированная по времени (для графика).
  List<BalancePoint> getBalanceHistory() {
    final list = _balanceHistoryBox.values
        .map((v) => BalancePoint.fromMap(v as Map))
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }
  // ==========================================================
  // 💱 КУРС USD/RUB (ЦБ РФ, раз в 24 часа)
  // ==========================================================
  /// Получить курс USD→RUB. Если кэш свежий (< 24 ч) — вернёт его,
  /// иначе сходит на cbr-xml-daily.ru и обновит.
  ///
  /// [forceRefresh] — принудительно обновить (кнопка «Обновить» в UI).
  Future<double> getUsdRubRate({bool forceRefresh = false}) async {
    final cachedRate = _cachedRate();
    final fetchedAt = _cachedFetchedAt();
    final isFresh = fetchedAt != null &&
        DateTime.now().difference(fetchedAt).inHours < _rateTtlHours;
    if (!forceRefresh && cachedRate != null && isFresh) {
      return cachedRate;
    }
    try {
      final fresh = await _fetchUsdRubFromCbr();
      await _settingsBox.put(_kUsdRubRate, fresh);
      await _settingsBox.put(
          _kUsdRubFetchedAtMs, DateTime.now().millisecondsSinceEpoch);
      _log.i('💱 Курс USD/RUB обновлён: $fresh');
      return fresh;
    } catch (e) {
      _log.w('⚠ Не удалось обновить курс USD/RUB: $e');
      // Если сети нет — вернём кэш (даже старый) либо дефолт.
      return cachedRate ?? 90.0;
    }
  }
  /// Только последний сохранённый курс (без сетевых запросов).
  double? getCachedUsdRubRate() => _cachedRate();
  // ==========================================================
  // 🛠 ВНУТРЕННИЕ
  // ==========================================================
  double? _cachedRate() {
    final v = _settingsBox.get(_kUsdRubRate);
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
  DateTime? _cachedFetchedAt() {
    final ms = _settingsBox.get(_kUsdRubFetchedAtMs);
    if (ms == null) return null;
    final v = (ms as num?)?.toInt();
    if (v == null || v <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(v);
  }
  /// Запрос к API ЦБ РФ.
  /// Формат ответа: { "Valute": { "USD": { "Value": 92.45, ... } } }
  Future<double> _fetchUsdRubFromCbr() async {
    final res = await _dio.get<String>(
      AppConstants.CBR_API_URL,
      options: Options(responseType: ResponseType.plain),
    );
    final body = res.data;
    if (body == null || body.isEmpty) {
      throw Exception('Пустой ответ от CBR');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final usd = (data['Valute']?['USD']) as Map<String, dynamic>?;
    if (usd == null) throw Exception('Не найден курс USD в ответе CBR');
    final value = (usd['Value'] as num?)?.toDouble();
    if (value == null || value <= 0) {
      throw Exception('Некорректный курс USD: $value');
    }
    return value;
  }
  // ==========================================================
  // 🧮 УТИЛИТЫ
  // ==========================================================
  /// Конвертировать USDT в USD (1:1).
  double usdtToUsd(double usdt) => usdt;
  /// Конвертировать USDT в RUB по сохранённому курсу.
  /// Если курса ещё нет — вернёт 0 (UI покажет "— ₽").
  double usdtToRub(double usdt) {
    final rate = _cachedRate();
    if (rate == null || rate <= 0) return 0.0;
    return usdt * rate;
  }
  /// Формат для UI: возвращает пару (USD, RUB) для текущего баланса.
  ({double usd, double rub}) getBalanceInBoth() {
    final balance = getPaperBalance();
    return (usd: balance, rub: usdtToRub(balance));
  }
}
