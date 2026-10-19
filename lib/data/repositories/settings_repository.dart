import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/strategy_profile.dart';

enum TradingMode { paper, real }
enum BybitEnvironment { mainnet, testnet }

class BotSettings {
  final ThemeMode themeMode;
  final TradingMode tradingMode;
  final BybitEnvironment environment;
  final double minTurnover24h;
  final double maxTurnover24h;
  final double minOpenInterest;
  final double capMultiplier;
  final double minEstimatedCap;
  final double maxEstimatedCap;
  final double minRealMarketCap;
  final double maxRealMarketCap;
  final bool skipUpcomingUnlocks;
  final double flagMinImpulse;
  final double vrevWickBodyRatio;
  final double vrevVolumeSpike;
  final double tp1Multiplier;
  final double tp2Multiplier;
  final double tp3Multiplier;
  final double trailingPercent;
  final int leverage;
  final double riskPerTradePct;

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
    this.minRealMarketCap = 1000000.0,
    this.maxRealMarketCap = 150000000.0,
    this.skipUpcomingUnlocks = true,
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

  BotSettings copyWith({
    ThemeMode? themeMode, TradingMode? tradingMode, BybitEnvironment? environment,
    double? minTurnover24h, double? maxTurnover24h, double? minOpenInterest,
    double? capMultiplier, double? minEstimatedCap, double? maxEstimatedCap,
    double? minRealMarketCap, double? maxRealMarketCap, bool? skipUpcomingUnlocks,
    double? flagMinImpulse, double? vrevWickBodyRatio, double? vrevVolumeSpike,
    double? tp1Multiplier, double? tp2Multiplier, double? tp3Multiplier,
    double? trailingPercent, int? leverage, double? riskPerTradePct,
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
      minRealMarketCap: minRealMarketCap ?? this.minRealMarketCap,
      maxRealMarketCap: maxRealMarketCap ?? this.maxRealMarketCap,
      skipUpcomingUnlocks: skipUpcomingUnlocks ?? this.skipUpcomingUnlocks,
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

class SettingsRepository {
  SettingsRepository._internal();
  static final SettingsRepository instance = SettingsRepository._internal();
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  Box get _profilesBox => Hive.box(AppConstants.BOX_STRATEGY_PROFILES);

  Future<BotSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BotSettings(
      themeMode: _parseTheme(prefs.getString('theme')),
      tradingMode: _parseTrading(prefs.getString('trading')),
      environment: _parseEnv(prefs.getString('env')),
      minTurnover24h: prefs.getDouble('min_turn') ?? AppConstants.MIN_TURNOVER_24H,
      maxTurnover24h: prefs.getDouble('max_turn') ?? AppConstants.MAX_TURNOVER_24H,
      minOpenInterest: prefs.getDouble('min_oi') ?? AppConstants.MIN_OPEN_INTEREST,
      capMultiplier: prefs.getDouble('cap_mult') ?? AppConstants.CAP_MULTIPLIER,
      minEstimatedCap: prefs.getDouble('min_est_cap') ?? AppConstants.MIN_ESTIMATED_CAP,
      maxEstimatedCap: prefs.getDouble('max_est_cap') ?? AppConstants.MAX_ESTIMATED_CAP,
      minRealMarketCap: prefs.getDouble('min_real_cap') ?? 1000000.0,
      maxRealMarketCap: prefs.getDouble('max_real_cap') ?? 150000000.0,
      skipUpcomingUnlocks: prefs.getBool('skip_unlocks') ?? true,
      flagMinImpulse: prefs.getDouble('flag_imp') ?? AppConstants.FLAG_MIN_IMPULSE,
      vrevWickBodyRatio: prefs.getDouble('vrev_wick') ?? AppConstants.VREV_WICK_BODY_RATIO,
      vrevVolumeSpike: prefs.getDouble('vrev_vol') ?? AppConstants.VREV_VOLUME_SPIKE,
      tp1Multiplier: prefs.getDouble('tp1') ?? AppConstants.TP1_MULTIPLIER,
      tp2Multiplier: prefs.getDouble('tp2') ?? AppConstants.TP2_MULTIPLIER,
      tp3Multiplier: prefs.getDouble('tp3') ?? AppConstants.TP3_MULTIPLIER,
      trailingPercent: prefs.getDouble('trail') ?? AppConstants.TRAILING_PERCENT,
      leverage: prefs.getInt('lev') ?? 3,
      riskPerTradePct: prefs.getDouble('risk') ?? 5.0,
    );
  }

  Future<void> save(BotSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('theme', s.themeMode.name), prefs.setString('trading', s.tradingMode.name),
      prefs.setString('env', s.environment.name), prefs.setDouble('min_turn', s.minTurnover24h),
      prefs.setDouble('max_turn', s.maxTurnover24h), prefs.setDouble('min_oi', s.minOpenInterest),
      prefs.setDouble('cap_mult', s.capMultiplier), prefs.setDouble('min_est_cap', s.minEstimatedCap),
      prefs.setDouble('max_est_cap', s.maxEstimatedCap), prefs.setDouble('min_real_cap', s.minRealMarketCap),
      prefs.setDouble('max_real_cap', s.maxRealMarketCap), prefs.setBool('skip_unlocks', s.skipUpcomingUnlocks),
      prefs.setDouble('flag_imp', s.flagMinImpulse), prefs.setDouble('vrev_wick', s.vrevWickBodyRatio),
      prefs.setDouble('vrev_vol', s.vrevVolumeSpike), prefs.setDouble('tp1', s.tp1Multiplier),
      prefs.setDouble('tp2', s.tp2Multiplier), prefs.setDouble('tp3', s.tp3Multiplier),
      prefs.setDouble('trail', s.trailingPercent), prefs.setInt('lev', s.leverage),
      prefs.setDouble('risk', s.riskPerTradePct),
    ]);
  }

  Future<void> saveProfile(String name, BotSettings settings) async {
    final profile = StrategyProfile(name: name, settings: settings);
    await _profilesBox.put(name, profile.toMap());
  }
  List<String> getProfileNames() => _profilesBox.keys.cast<String>().toList();
  Future<void> deleteProfile(String name) async => await _profilesBox.delete(name);

  BotSettings? loadProfile(String name) {
    final raw = _profilesBox.get(name);
    if (raw == null) return null;
    final map = raw['settings'] as Map;
    return BotSettings(
      themeMode: _parseTheme(map['themeMode']), tradingMode: _parseTrading(map['tradingMode']),
      environment: _parseEnv(map['environment']), minTurnover24h: (map['minTurnover24h'] as num).toDouble(),
      maxTurnover24h: (map['maxTurnover24h'] as num).toDouble(), minOpenInterest: (map['minOpenInterest'] as num).toDouble(),
      capMultiplier: (map['capMultiplier'] as num).toDouble(), minEstimatedCap: (map['minEstimatedCap'] as num).toDouble(),
      maxEstimatedCap: (map['maxEstimatedCap'] as num).toDouble(), minRealMarketCap: (map['minRealMarketCap'] as num).toDouble(),
      maxRealMarketCap: (map['maxRealMarketCap'] as num).toDouble(), skipUpcomingUnlocks: map['skipUpcomingUnlocks'] as bool,
      flagMinImpulse: (map['flagMinImpulse'] as num).toDouble(), vrevWickBodyRatio: (map['vrevWickBodyRatio'] as num).toDouble(),
      vrevVolumeSpike: (map['vrevVolumeSpike'] as num).toDouble(), tp1Multiplier: (map['tp1Multiplier'] as num).toDouble(),
      tp2Multiplier: (map['tp2Multiplier'] as num).toDouble(), tp3Multiplier: (map['tp3Multiplier'] as num).toDouble(),
      trailingPercent: (map['trailingPercent'] as num).toDouble(), leverage: (map['leverage'] as num).toInt(),
      riskPerTradePct: (map['riskPerTradePct'] as num).toDouble(),
    );
  }

  Future<void> saveBybitCredentials({required String apiKey, required String apiSecret}) async {
    await _secure.write(key: AppConstants.SECURE_KEY_BYBIT_API, value: apiKey);
    await _secure.write(key: AppConstants.SECURE_KEY_BYBIT_SECRET, value: apiSecret);
  }
  Future<({String apiKey, String apiSecret})?> loadBybitCredentials() async {
    final k = await _secure.read(key: AppConstants.SECURE_KEY_BYBIT_API);
    final s = await _secure.read(key: AppConstants.SECURE_KEY_BYBIT_SECRET);
    if (k == null || s == null) return null;
    return (apiKey: k, apiSecret: s);
  }
  Future<bool> hasBybitCredentials() async => (await loadBybitCredentials()) != null;
  Future<void> clearBybitCredentials() async {
    await _secure.delete(key: AppConstants.SECURE_KEY_BYBIT_API);
    await _secure.delete(key: AppConstants.SECURE_KEY_BYBIT_SECRET);
  }

  static ThemeMode _parseTheme(String? v) => v == 'light' ? ThemeMode.light : (v == 'system' ? ThemeMode.system : ThemeMode.dark);
  static TradingMode _parseTrading(String? v) => v == 'real' ? TradingMode.real : TradingMode.paper;
  static BybitEnvironment _parseEnv(String? v) => v == 'mainnet' ? BybitEnvironment.mainnet : BybitEnvironment.testnet;
}
