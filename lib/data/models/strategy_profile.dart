import '../../data/repositories/settings_repository.dart';

class StrategyProfile {
  final String name;
  final BotSettings settings;

  const StrategyProfile({required this.name, required this.settings});

  Map<String, dynamic> toMap() => {
    'name': name,
    'settings': {
      'themeMode': settings.themeMode.name,
      'tradingMode': settings.tradingMode.name,
      'environment': settings.environment.name,
      'minTurnover24h': settings.minTurnover24h,
      'maxTurnover24h': settings.maxTurnover24h,
      'minOpenInterest': settings.minOpenInterest,
      'capMultiplier': settings.capMultiplier,
      'minEstimatedCap': settings.minEstimatedCap,
      'maxEstimatedCap': settings.maxEstimatedCap,
      'minRealMarketCap': settings.minRealMarketCap,
      'maxRealMarketCap': settings.maxRealMarketCap,
      'skipUpcomingUnlocks': settings.skipUpcomingUnlocks,
      'flagMinImpulse': settings.flagMinImpulse,
      'vrevWickBodyRatio': settings.vrevWickBodyRatio,
      'vrevVolumeSpike': settings.vrevVolumeSpike,
      'tp1Multiplier': settings.tp1Multiplier,
      'tp2Multiplier': settings.tp2Multiplier,
      'tp3Multiplier': settings.tp3Multiplier,
      'trailingPercent': settings.trailingPercent,
      'leverage': settings.leverage,
      'riskPerTradePct': settings.riskPerTradePct,
    }
  };
}
