#!/usr/bin/env bash
set -e

echo "===> 1. Проверка репозитория"
if [ ! -f pubspec.yaml ]; then
  echo "ОШИБКА: ты не в корне проекта. Открой Codespaces заново."
  exit 1
fi
git remote -v | grep -q "EinsteinBot1" || {
  echo "ОШИБКА: репозиторий не EinsteinBot1"
  exit 1
}
echo "OK: работаем в EinsteinBot1"

echo "===> 2. Проверка трёх файлов"
FAIL=0
grep -qi "firebase" lib/background/bot_task_handler.dart && { echo "❌ firebase в bot_task_handler"; FAIL=1; } || echo "✅ bot_task_handler чист"
grep -q "candles\." lib/domain/searcher_engine.dart && { echo "❌ candles в searcher_engine"; FAIL=1; } || echo "✅ searcher_engine чист"
grep -q "}}" lib/core/providers/settings_provider.dart && { echo "❌ двойные }} в settings_provider"; FAIL=1; } || echo "✅ settings_provider чист"

if [ "$FAIL" = "1" ]; then
  echo ""
  echo "⚠️  Найдены проблемы. Перезаписываю файлы..."
  cat > lib/core/providers/settings_provider.dart << 'ENDOFFILE_EINSTEIN'
import 'package:flutter/material.dart';
import '../../data/repositories/balance_repository.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    _init();
  }

  final _repo = SettingsRepository.instance;
  final _balance = BalanceRepository.instance;

  BotSettings _settings = const BotSettings();
  bool _loading = true;
  double? _usdRubRate;
  double _paperBalance = 0.0;
  bool _hasKeys = false;

  BotSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  TradingMode get tradingMode => _settings.tradingMode;
  BybitEnvironment get environment => _settings.environment;
  bool get isLoading => _loading;
  double get paperBalanceUsdt => _paperBalance;
  double? get usdRubRate => _usdRubRate;
  bool get hasBybitCredentials => _hasKeys;
  double get paperBalanceRub =>
      _usdRubRate == null ? 0.0 : _paperBalance * _usdRubRate!;
  double? get balanceInRub =>
      _usdRubRate == null ? null : _paperBalance * _usdRubRate!;

  Future<void> _init() async {
    await reload();
  }

  Future<void> reload() async {
    _loading = true;
    notifyListeners();
    try {
      _settings = await _repo.load();
      _hasKeys = await _repo.hasBybitCredentials();
      _paperBalance = _balance.getPaperBalance();
      _usdRubRate = await _balance.getUsdRubRate();
    } catch (e) {
      debugPrint('SettingsProvider.reload error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _repo.save(_settings);
  }

  Future<void> setTradingMode(TradingMode mode) async {
    _settings = _settings.copyWith(tradingMode: mode);
    notifyListeners();
    await _repo.save(_settings);
  }

  Future<void> setEnvironment(BybitEnvironment env) async {
    _settings = _settings.copyWith(environment: env);
    notifyListeners();
    await _repo.save(_settings);
  }

  Future<void> updateSettings(BotSettings updated) async {
    _settings = updated;
    notifyListeners();
    await _repo.save(_settings);
  }

  Future<void> saveBybitKeys({
    required String apiKey,
    required String apiSecret,
  }) async {
    await _repo.saveBybitCredentials(
      apiKey: apiKey.trim(),
      apiSecret: apiSecret.trim(),
    );
    _hasKeys = true;
    notifyListeners();
  }

  Future<void> clearBybitKeys() async {
    await _repo.clearBybitCredentials();
    _hasKeys = false;
    notifyListeners();
  }

  Future<void> refreshUsdRub() async {
    final rate = await _balance.getUsdRubRate(forceRefresh: true);
    _usdRubRate = rate;
    notifyListeners();
  }

  void refreshBalance() {
    _paperBalance = _balance.getPaperBalance();
    notifyListeners();
  }

  Future<void> resetPaperAccount() async {
    await _balance.resetPaperAccount();
    _paperBalance = _balance.getPaperBalance();
    notifyListeners();
  }
}
ENDOFFILE_EINSTEIN
  echo "✅ settings_provider перезаписан"
fi

echo ""
echo "===> 3. Проверка ещё раз"
grep -qi "firebase" lib/background/bot_task_handler.dart && echo "❌ ЕЩЁ firebase" || echo "✅ bot_task_handler OK"
grep -q "candles\." lib/domain/searcher_engine.dart && echo "❌ ЕЩЁ candles" || echo "✅ searcher_engine OK"
grep -q "}}" lib/core/providers/settings_provider.dart && echo "❌ ЕЩЁ двойные }}" || echo "✅ settings_provider OK"

echo ""
echo "===> 4. Триггерим сборку (обновляем комментарий в pubspec.yaml)"
STAMP=$(date +%s)
sed -i "s|^description:.*|description: \"Эйнштейн — торговый и аналитический терминал для Bybit (build $STAMP).\"|" pubspec.yaml
head -3 pubspec.yaml

echo ""
echo "===> 5. Git commit + push"
git add -A
git commit -m "Force build after clean files (build $STAMP)"
git push origin main

echo ""
echo "==================================================="
echo "✅ ГОТОВО. Открой Actions:"
echo "https://github.com/denmrl/EinsteinBot1/actions"
echo "Обнови страницу, дождись нового запуска (~3 мин)"
echo "==================================================="
