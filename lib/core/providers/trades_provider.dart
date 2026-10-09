// ==========================================================
//  ЭЙНШТЕЙН — Провайдер сделок
//  Файл: lib/core/providers/trades_provider.dart
//  Отдаёт в UI:
//    • активные сделки (с текущим PnL),
//    • монеты на наблюдении,
//    • историю закрытых сделок,
//    • статистику (винрейт, коэфф. Прибыль/Убыток).
//  Автоматически перерисовывает UI при любом изменении Hive.
// ==========================================================
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/active_trade.dart';
import '../../data/models/closed_trade.dart';
import '../../data/models/watched_setup.dart';
import '../../data/repositories/trades_repository.dart';

class TradesProvider extends ChangeNotifier {
  TradesProvider() {
    _repo = TradesRepository();
    _attachListeners();
    _reload();
  }
  late final TradesRepository _repo;

  // ---------- Кэш данных для UI ----------
  List<ActiveTrade> _active = const [];
  List<WatchedSetup> _watched = const [];
  List<ClosedTrade> _history = const [];

  // ---------- Геттеры ----------
  List<ActiveTrade> get active => _active;
  List<WatchedSetup> get watched => _watched;
  List<ClosedTrade> get history => _history;

  /// Есть ли хоть что-то интересное в UI (для показа плейсхолдеров).
  bool get isEmpty =>
      _active.isEmpty && _watched.isEmpty && _history.isEmpty;

  // ==========================================================
  // 📊 СТАТИСТИКА (считается на лету по истории)
  // ==========================================================
  int get totalTrades => _history.length;
  int get wins => _history.where((t) => t.isWin).length;
  int get losses => _history.length - wins;

  /// Винрейт в процентах (0..100).
  double get winRatePct =>
      totalTrades == 0 ? 0.0 : (wins / totalTrades) * 100.0;

  /// Сумма положительных PnL (в %).
  double get totalGainPct => _history
      .where((t) => t.isWin)
      .fold<double>(0.0, (s, t) => s + t.finalNetPnlPct);

  /// Сумма отрицательных PnL (по модулю, в %).
  double get totalLossPct => _history
      .where((t) => !t.isWin)
      .fold<double>(0.0, (s, t) => s + t.finalNetPnlPct.abs());

  /// Коэффициент Прибыль/Убыток (∞, если убытков нет).
  double get profitLossRatio =>
      totalLossPct == 0 ? double.infinity : totalGainPct / totalLossPct;

  /// Общий PnL в USDT за всё время.
  double get totalPnlUsdt =>
      _history.fold<double>(0.0, (s, t) => s + t.pnlUsdt);

  /// 5 последних закрытых сделок (для блока «Последние сделки»).
  List<ClosedTrade> get lastClosed {
    final copy = [..._history];
    copy.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    return copy.take(5).toList();
  }

  // ==========================================================
  // 📥 ПОДПИСКИ НА ИЗМЕНЕНИЯ HIVE
  // ==========================================================
  void _attachListeners() {
    Hive.box(AppConstants.BOX_ACTIVE_TRADES)
        .listenable()
        .addListener(_reload);
    Hive.box(AppConstants.BOX_WATCHED_SETUPS)
        .listenable()
        .addListener(_reload);
    Hive.box(AppConstants.BOX_TRADE_HISTORY)
        .listenable()
        .addListener(_reload);
  }

  /// Читаем данные из репозитория и уведомляем UI.
  void _reload() {
    try {
      _active = _repo.loadActiveTrades();
      _watched = _repo.loadWatchedSetups();
      _history = _repo.loadHistory();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠ TradesProvider reload error: $e');
    }
  }

  /// Публичная ручная перезагрузка (например, при pull-to-refresh).
  void refresh() => _reload();

  @override
  void dispose() {
    try {
      Hive.box(AppConstants.BOX_ACTIVE_TRADES)
          .listenable()
          .removeListener(_reload);
      Hive.box(AppConstants.BOX_WATCHED_SETUPS)
          .listenable()
          .removeListener(_reload);
      Hive.box(AppConstants.BOX_TRADE_HISTORY)
          .listenable()
          .removeListener(_reload);
    } catch (_) {}
    super.dispose();
  }

  // ==========================================================
  // 🛠 ОПЕРАЦИИ (кнопки в карточках UI)
  // ==========================================================
  /// Удалить монету из наблюдения вручную.
  Future<void> removeWatched(String symbol) async {
    await _repo.removeWatchedTrade(symbol);
    _reload();
  }

  /// Очистить всю историю (для кнопки в настройках).
  Future<void> clearHistory() async {
    await _repo.clearHistory();
    _reload();
  }
}
