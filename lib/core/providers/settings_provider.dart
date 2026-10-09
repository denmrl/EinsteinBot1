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
