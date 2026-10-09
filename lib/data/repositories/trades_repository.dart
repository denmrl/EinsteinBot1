// ==========================================================
//  ЭЙНШТЕЙН — Репозиторий сделок (обёртка над Hive)
//  Файл: lib/data/repositories/trades_repository.dart
//  Аналог функций Python: load_active_trades, save_active_trade,
//  remove_active_trade, load_watched_trades, save_watched_trade,
//  remove_watched_trade, record_closed_trade.
// ==========================================================
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../models/active_trade.dart';
import '../models/closed_trade.dart';
import '../models/watched_setup.dart';
/// Единая точка работы с тремя боксами Hive:
///  • активные сделки,
///  • наблюдения,
///  • история закрытых сделок.
///
/// Ключи:
///  • активные сделки — ключ = symbol (одна сделка на монету);
///  • наблюдения — ключ = symbol;
///  • история — ключ = автоинкрементный int (можно хранить много
///    сделок по одному символу).
class TradesRepository {
  // ==========================================================
  // 🗂 ГЕТТЕРЫ БОКСОВ
  // ==========================================================
  // Ленивая инициализация через `late final` — Hive уже открыл
  // боксы в main.dart, тут мы просто получаем ссылки.
  Box get _activeBox => Hive.box(AppConstants.BOX_ACTIVE_TRADES);
  Box get _watchedBox => Hive.box(AppConstants.BOX_WATCHED_SETUPS);
  Box get _historyBox => Hive.box(AppConstants.BOX_TRADE_HISTORY);
  // ==========================================================
  // 📌 АКТИВНЫЕ СДЕЛКИ
  // ==========================================================
  /// Загрузить все открытые позиции.
  List<ActiveTrade> loadActiveTrades() {
    return _activeBox.values
        .map((v) => ActiveTrade.fromMap(v as Map))
        .toList();
  }
  /// Получить одну активную сделку по тикеру (или null).
  ActiveTrade? getActiveTrade(String symbol) {
    final raw = _activeBox.get(symbol);
    if (raw == null) return null;
    return ActiveTrade.fromMap(raw as Map);
  }
  /// Сохранить/обновить активную сделку.
  /// Одновременно удаляет монету из списка наблюдения —
  /// как в Python-коде `save_active_trade` вызывает `remove_watched_trade`.
  Future<void> saveActiveTrade(ActiveTrade trade) async {
    await _activeBox.put(trade.symbol, trade.toMap());
    // Монета «переехала» из наблюдения в активную сделку.
    await removeWatchedTrade(trade.symbol);
  }
  /// Удалить активную сделку (например, при закрытии по стопу/трейлингу).
  Future<void> removeActiveTrade(String symbol) async {
    await _activeBox.delete(symbol);
  }
  /// Список тикеров активных сделок (для быстрой проверки «уже в сделке?»).
  Set<String> activeSymbols() {
    return _activeBox.keys.map((k) => k.toString()).toSet();
  }
  // ==========================================================
  // 👁 НАБЛЮДЕНИЯ
  // ==========================================================
  /// Все монеты на наблюдении.
  List<WatchedSetup> loadWatchedSetups() {
    return _watchedBox.values
        .map((v) => WatchedSetup.fromMap(v as Map))
        .toList();
  }
  /// Получить одно наблюдение по тикеру (или null).
  WatchedSetup? getWatchedSetup(String symbol) {
    final raw = _watchedBox.get(symbol);
    if (raw == null) return null;
    return WatchedSetup.fromMap(raw as Map);
  }
  /// Сохранить/обновить наблюдение.
  Future<void> saveWatchedSetup(WatchedSetup setup) async {
    await _watchedBox.put(setup.symbol, setup.toMap());
  }
  /// Удалить наблюдение (при отмене или при переходе в активную сделку).
  Future<void> removeWatchedTrade(String symbol) async {
    await _watchedBox.delete(symbol);
  }
  /// Список тикеров на наблюдении.
  Set<String> watchedSymbols() {
    return _watchedBox.keys.map((k) => k.toString()).toSet();
  }
  // ==========================================================
  // 📜 ИСТОРИЯ ЗАКРЫТЫХ СДЕЛОК
  // ==========================================================
  /// Вся история закрытых сделок (в порядке добавления).
  /// Репозиторий не сортирует — сортировку сделаем на экране истории.
  List<ClosedTrade> loadHistory() {
    return _historyBox.values
        .map((v) => ClosedTrade.fromMap(v as Map))
        .toList();
  }
  /// Записать закрытую сделку:
  ///  1) удалить её из активных,
  ///  2) добавить в историю,
  ///  3) вернуть записанный объект.
  Future<ClosedTrade> recordClosedTrade(ClosedTrade trade) async {
    // 1. Убираем из активных (если была).
    await removeActiveTrade(trade.symbol);
    // 2. Генерируем новый ключ для истории.
    //    Hive сам подскажет следующий int через `_historyBox.length`.
    //    Гарантируем уникальность: если такой ключ уже есть —
    //    используем максимальный + 1.
    final nextKey = _nextHistoryKey();
    // 3. Пишем в историю.
    await _historyBox.put(nextKey, trade.toMap());
    return trade;
  }
  /// Очистить всю историю (для отладки / сброса).
  Future<void> clearHistory() async {
    await _historyBox.clear();
  }
  /// Удалить одну запись истории по ключу (например, кнопка «удалить»).
  Future<void> deleteHistoryEntry(int key) async {
    await _historyBox.delete(key);
  }
  // ==========================================================
  // 🧮 СТАТИСТИКА (утилиты, считаются на лету из истории)
  // ==========================================================
  /// Количество закрытых сделок.
  int get totalTradesCount => _historyBox.length;
  /// Средний винрейт в процентах (0..100).
  /// Возвращает 0, если сделок нет.
  double get winRatePct {
    if (_historyBox.isEmpty) return 0.0;
    final list = loadHistory();
    final wins = list.where((t) => t.isWin).length;
    return (wins / list.length) * 100.0;
  }
  /// Сумма положительных PnL в процентах.
  double get totalGainPct {
    return loadHistory()
        .where((t) => t.isWin)
        .fold<double>(0.0, (sum, t) => sum + t.finalNetPnlPct);
  }
  /// Сумма отрицательных PnL в процентах (по модулю).
  double get totalLossPct {
    return loadHistory()
        .where((t) => !t.isWin)
        .fold<double>(0.0, (sum, t) => sum + t.finalNetPnlPct.abs());
  }
  /// Коэффициент Прибыль/Убыток. Возвращает double.infinity,
  /// если убытков ещё не было (как в Python: "∞").
  double get profitLossRatio {
    if (totalLossPct == 0) return double.infinity;
    return totalGainPct / totalLossPct;
  }
  // ==========================================================
  // 🛠 ВСПОМОГАТЕЛЬНЫЕ
  // ==========================================================
  /// Вычисляет следующий свободный int-ключ для истории.
  int _nextHistoryKey() {
    if (_historyBox.isEmpty) return 1;
    // Ключи Hive могут быть int — берём максимум и прибавляем 1.
    int maxKey = 0;
    for (final k in _historyBox.keys) {
      if (k is int && k > maxKey) maxKey = k;
    }
    return maxKey + 1;
  }
  /// Полная очистка всех боксов (только для отладки!).
  /// В UI не показываем — используем в тестах или по скрытой кнопке.
  Future<void> wipeAll() async {
    await _activeBox.clear();
    await _watchedBox.clear();
    await _historyBox.clear();
  }
}
