// ==========================================================
//  ЭЙНШТЕЙН — Репозиторий настроек и API-ключей
//  Файл: lib/data/repositories/settings_repository.dart
//  • UI-настройки (тема, режим, фильтры) — shared_preferences.
//  • Секреты (Bybit API) — flutter_secure_storage.
// ==========================================================

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Режим торговли (Paper / Real).
enum TradingMode {
  /// Демо-торговля: виртуальный баланс 1000 USDT, ничего не отправляем на биржу.
  paper,

  /// Реальная торговля (Вариант C): ордера летят на Bybit V5.
  real,
}

/// Тип подключения к Bybit.
enum BybitEnvironment {
  /// Основной контур (mainnet). Реальные деньги.
  mainnet,

  /// Тестовый контур (testnet). Игрушечные монеты, но реальные ордера.
  testnet,
}

/// Полный снимок пользовательских настроек.
/// Удобно передавать в UI одним объектом через Provider.
class BotSettings {
  // ---------- UI ----------
  final ThemeMode themeMode;
  final TradingMode tradingMode;
  final BybitEnvironment environment;

  // ---------- Фильтры поиска (можно менять в UI на лету) ----------
  final double minTurnover24h;
  final double maxTurnover24h;
  final double minOpenInterest;
  final double capMultiplier;
  final double minEstimatedCap;
  final double maxEstimatedCap;

  // ---------- Параметры паттернов ----------
  final double flagMinImpulse;      // импульс роста для Бычьего Флага
  final double vrevWickBodyRatio;   // тень/тело для V-Разворота
  final double vrevVolumeSpike;     // объёмный спайк для V-Разворота

  // ---------- Логика сопровождения ----------
  final double tp1Multiplier;
  final double tp2Multiplier;
  final double tp3Multiplier;
  final double trailingPercent;
  final int leverage;               // кредитное плечо для реального режима
  final double riskPerTradePct;     // % от депозита на сделку

  const BotSettings({
    this.themeMode = ThemeMode.dark,
    this.tradingMode = TradingMode.paper,
    this.environment = BybitEnvironment.testnet,
    this.minTurnover24h = AppConstants.MIN_TURNOVER_24H,
    this.maxTurnover24h = AppConstants.MAX_TURNOVER_24H,
    this.minOpenInterest = AppConstants.MIN_OPEN_INTEREST,
    this.capMultiplier = AppConstants.CAP_MULTIPLIER,
    this.minEstimatedCap = AppConstants.MIN_ESTIMATED_CAP,
    this.maxEstimatedCap = AppConstants.MAX_ESTIMATED_CAP,
    this.flagMinImpulse = AppConstants.FLAG_MIN_IMPULSE,
    this.vrevWickBodyRatio = AppConstants.VREV_WICK_BODY_RATIO,
    this.vrevVolumeSpike = AppConstants.VREV_VOLUME_SPIKE,
    this.tp1Multiplier = AppConstants.TP1_MULTIPLIER,
    this.tp2Multiplier = AppConstants.TP2_MULTIPLIER,
    this.tp3Multiplier = AppConstants.TP3_MULTIPLIER,
    this.trailingPercent = AppConstants.TRAILING_PERCENT,
    this.leverage = 3,
    this.riskPerTradePct = 5.0,
  });

  /// Копия с изменениями — удобно для редактирования в UI.
  BotSettings copyWith({
    ThemeMode? themeMode,
    TradingMode? tradingMode,
    BybitEnvironment? environment,
    double? minTurnover24h,
    double? maxTurnover24h,
    double? minOpenInterest,
    double? capMultiplier,
    double? minEstimatedCap,
    double? maxEstimatedCap,
    double? flagMinImpulse,
    double? vrevWickBodyRatio,
    double? vrevVolumeSpike,
    double? tp1Multiplier,
    double? tp2Multiplier,
    double? tp3Multiplier,
    double? trailingPercent,
    int? leverage,
    double? riskPerTradePct,
  }) {
    return BotSettings(
      themeMode: themeMode ?? this.themeMode,
      tradingMode: tradingMode ?? this.tradingMode,
      environment: environment ?? this.environment,
      minTurnover24h: minTurnover24h ?? this.minTurnover24h,
      maxTurnover24h: maxTurnover24h ?? this.maxTurnover24h,
      minOpenInterest: minOpenInterest ?? this.minOpenInterest,
      capMultiplier: capMultiplier ?? this.capMultiplier,
      minEstimatedCap: minEstimatedCap ?? this.minEstimatedCap,
      maxEstimatedCap: maxEstimatedCap ?? this.maxEstimatedCap,
      flagMinImpulse: flagMinImpulse ?? this.flagMinImpulse,
      vrevWickBodyRatio: vrevWickBodyRatio ?? this.vrevWickBodyRatio,
      vrevVolumeSpike: vrevVolumeSpike ?? this.vrevVolumeSpike,
      tp1Multiplier: tp1Multiplier ?? this.tp1Multiplier,
      tp2Multiplier: tp2Multiplier ?? this.tp2Multiplier,
      tp3Multiplier: tp3Multiplier ?? this.tp3Multiplier,
      trailingPercent: trailingPercent ?? this.trailingPercent,
      leverage: leverage ?? this.leverage,
      riskPerTradePct: riskPerTradePct ?? this.riskPerTradePct,
    );
  }
}

/// Синглтон-репозиторий настроек.
class SettingsRepository {
  SettingsRepository._internal();
  static final SettingsRepository instance = SettingsRepository._internal();

  // ---------- Ключи SharedPreferences ----------
  static const _kThemeMode        = 'settings.theme_mode';
  static const _kTradingMode      = 'settings.trading_mode';
  static const _kEnvironment      = 'settings.environment';
  static const _kMinTurnover      = 'settings.min_turnover';
  static const _kMaxTurnover      = 'settings.max_turnover';
  static const _kMinOi            = 'settings.min_oi';
  static const _kCapMultiplier    = 'settings.cap_multiplier';
  static const _kMinEstCap        = 'settings.min_est_cap';
  static const _kMaxEstCap        = 'settings.max_est_cap';
  static const _kFlagMinImpulse   = 'settings.flag_min_impulse';
  static const _kVrevWickBody     = 'settings.vrev_wick_body';
  static const _kVrevVolumeSpike  = 'settings.vrev_volume_spike';
  static const _kTp1Multiplier    = 'settings.tp1_mult';
  static const _kTp2Multiplier    = 'settings.tp2_mult';
  static const _kTp3Multiplier    = 'settings.tp3_mult';
  static const _kTrailingPercent  = 'settings.trailing_pct';
  static const _kLeverage         = 'settings.leverage';
  static const _kRiskPerTradePct  = 'settings.risk_per_trade';

  // ---------- Secure Storage ----------
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ==========================================================
  // 📥 ЗАГРУЗКА ВСЕХ НАСТРОЕК
  // ==========================================================
  /// Возвращает полный объект настроек с текущими значениями.
  /// Если чего-то нет в хранилище — берётся дефолт из BotSettings.
  Future<BotSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    return BotSettings(
      themeMode: _parseThemeMode(prefs.getString(_kThemeMode)),
      tradingMode: _parseTradingMode(prefs.getString(_kTradingMode)),
      environment: _parseEnvironment(prefs.getString(_kEnvironment)),
      minTurnover24h: prefs.getDouble(_kMinTurnover) ?? AppConstants.MIN_TURNOVER_24H,
      maxTurnover24h: prefs.getDouble(_kMaxTurnover) ?? AppConstants.MAX_TURNOVER_24H,
      minOpenInterest: prefs.getDouble(_kMinOi) ?? AppConstants.MIN_OPEN_INTEREST,
      capMultiplier: prefs.getDouble(_kCapMultiplier) ?? AppConstants.CAP_MULTIPLIER,
      minEstimatedCap: prefs.getDouble(_kMinEstCap) ?? AppConstants.MIN_ESTIMATED_CAP,
      maxEstimatedCap: prefs.getDouble(_kMaxEstCap) ?? AppConstants.MAX_ESTIMATED_CAP,
      flagMinImpulse: prefs.getDouble(_kFlagMinImpulse) ?? AppConstants.FLAG_MIN_IMPULSE,
      vrevWickBodyRatio: prefs.getDouble(_kVrevWickBody) ?? AppConstants.VREV_WICK_BODY_RATIO,
      vrevVolumeSpike: prefs.getDouble(_kVrevVolumeSpike) ?? AppConstants.VREV_VOLUME_SPIKE,
      tp1Multiplier: prefs.getDouble(_kTp1Multiplier) ?? AppConstants.TP1_MULTIPLIER,
      tp2Multiplier: prefs.getDouble(_kTp2Multiplier) ?? AppConstants.TP2_MULTIPLIER,
      tp3Multiplier: prefs.getDouble(_kTp3Multiplier) ?? AppConstants.TP3_MULTIPLIER,
      trailingPercent: prefs.getDouble(_kTrailingPercent) ?? AppConstants.TRAILING_PERCENT,
      leverage: prefs.getInt(_kLeverage) ?? 3,
      riskPerTradePct: prefs.getDouble(_kRiskPerTradePct) ?? 5.0,
    );
  }

  // ==========================================================
  // 📤 СОХРАНЕНИЕ ВСЕХ НАСТРОЕК
  // ==========================================================
  /// Полная запись объекта BotSettings в SharedPreferences.
  /// Вызывается после «Сохранить» в экране настроек.
  Future<void> save(BotSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kThemeMode, s.themeMode.name),
      prefs.setString(_kTradingMode, s.tradingMode.name),
      prefs.setString(_kEnvironment, s.environment.name),
      prefs.setDouble(_kMinTurnover, s.minTurnover24h),
      prefs.setDouble(_kMaxTurnover, s.maxTurnover24h),
      prefs.setDouble(_kMinOi, s.minOpenInterest),
      prefs.setDouble(_kCapMultiplier, s.capMultiplier),
      prefs.setDouble(_kMinEstCap, s.minEstimatedCap),
      prefs.setDouble(_kMaxEstCap, s.maxEstimatedCap),
      prefs.setDouble(_kFlagMinImpulse, s.flagMinImpulse),
      prefs.setDouble(_kVrevWickBody, s.vrevWickBodyRatio),
      prefs.setDouble(_kVrevVolumeSpike, s.vrevVolumeSpike),
      prefs.setDouble(_kTp1Multiplier, s.tp1Multiplier),
      prefs.setDouble(_kTp2Multiplier, s.tp2Multiplier),
      prefs.setDouble(_kTp3Multiplier, s.tp3Multiplier),
      prefs.setDouble(_kTrailingPercent, s.trailingPercent),
      prefs.setInt(_kLeverage, s.leverage),
      prefs.setDouble(_kRiskPerTradePct, s.riskPerTradePct),
    ]);
  }

  // ==========================================================
  // 🔐 БЕЗОПАСНОЕ ХРАНЕНИЕ API-КЛЮЧЕЙ
  // ==========================================================

  /// Сохранить пару ключ/секрет Bybit. Оба шифруются Android'ом.
  Future<void> saveBybitCredentials({
    required String apiKey,
    required String apiSecret,
  }) async {
    await _secure.write(key: AppConstants.SECURE_KEY_BYBIT_API, value: apiKey);
    await _secure.write(key: AppConstants.SECURE_KEY_BYBIT_SECRET, value: apiSecret);
  }

  /// Загрузить ключи. Возвращает null, если ещё не сохраняли.
  Future<({String apiKey, String apiSecret})?> loadBybitCredentials() async {
    final k = await _secure.read(key: AppConstants.SECURE_KEY_BYBIT_API);
    final s = await _secure.read(key: AppConstants.SECURE_KEY_BYBIT_SECRET);
    if (k == null || s == null || k.isEmpty || s.isEmpty) return null;
    return (apiKey: k, apiSecret: s);
  }

  /// Есть ли вообще сохранённые ключи — для отображения статуса в UI.
  Future<bool> hasBybitCredentials() async {
    return (await loadBybitCredentials()) != null;
  }

  /// Удалить ключи (например, при выходе из реального режима).
  Future<void> clearBybitCredentials() async {
    await _secure.delete(key: AppConstants.SECURE_KEY_BYBIT_API);
    await _secure.delete(key: AppConstants.SECURE_KEY_BYBIT_SECRET);
  }

  // ==========================================================
  // 🛠 ПАРСЕРЫ ENUM ИЗ СТРОК
  // ==========================================================

  static ThemeMode _parseThemeMode(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static TradingMode _parseTradingMode(String? v) {
    return v == 'real' ? TradingMode.real : TradingMode.paper;
  }

  static BybitEnvironment _parseEnvironment(String? v) {
    return v == 'mainnet'
        ? BybitEnvironment.mainnet
        : BybitEnvironment.testnet;
  }
}