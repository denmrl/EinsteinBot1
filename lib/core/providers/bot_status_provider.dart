// ==========================================================
//  ЭЙНШТЕЙН — Провайдер статуса фонового бота
//  Файл: lib/core/providers/bot_status_provider.dart
//  Управляет тумблером «Запустить/Остановить бота» в UI.
//  Внутри обращается к ForegroundServiceManager.
// ==========================================================
import 'package:flutter/foundation.dart';
import '../../background/foreground_service.dart';

class BotStatusProvider extends ChangeNotifier {
  BotStatusProvider() {
    _syncStatus();
  }
  final _fgs = ForegroundServiceManager.instance;

  // ---------- Состояние ----------
  bool _running = false;
  bool _busy = false;         // идёт старт/стоп — блокируем кнопку
  String? _lastError;

  // ---------- Геттеры ----------
  bool get isRunning => _running;
  bool get isBusy => _busy;
  String? get lastError => _lastError;

  // ==========================================================
  // 🔄 СИНХРОНИЗАЦИЯ С СЕРВИСОМ
  // ==========================================================
  /// Проверить, работает ли FGS в данный момент (например, при старте UI).
  Future<void> _syncStatus() async {
    try {
      _running = await _fgs.isRunning();
      notifyListeners();
    } catch (_) {/* no-op */}
  }

  /// Публичный вызов для синхронизации из UI (при возврате на экран).
  Future<void> syncStatus() => _syncStatus();

  // ==========================================================
  // 🚀 СТАРТ / ⏹ СТОП
  // ==========================================================
  /// Запустить бота. Возвращает true, если сервис стартовал.
  Future<bool> start() async {
    if (_busy || _running) return _running;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final ok = await _fgs.start();
      _running = ok;
      return ok;
    } catch (e) {
      _lastError = e.toString();
      _running = false;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Остановить бота.
  Future<void> stop() async {
    if (_busy || !_running) return;
    _busy = true;
    notifyListeners();
    try {
      await _fgs.stop();
      _running = false;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Удобный метод для тумблера (тумблер передаёт true/false).
  Future<void> toggle(bool value) async {
    if (value) {
      await start();
    } else {
      await stop();
    }
  }
}
