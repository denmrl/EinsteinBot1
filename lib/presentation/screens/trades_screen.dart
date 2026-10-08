// ==========================================================
//  ЭЙНШТЕЙН — Главный экран (Активные / Наблюдение) [ОБНОВЛЕННЫЙ]
//  Файл: lib/presentation/screens/trades_screen.dart
// ==========================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/bot_status_provider.dart';
import '../../core/providers/trades_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/candle.dart';
import '../../data/sources/bybit_api.dart';
import '../widgets/trade_card.dart';
import 'trading_mode_screen.dart'; // Навигация
import 'settings_screen.dart';     // Навигация

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});
  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _api = BybitApi.instance;
  final Map<String, double> _prices = {};
  final Map<String, List<Candle>> _miniCandles = {};
  Timer? _priceTimer;
  Timer? _candlesTimer;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _refreshPrices();
    _priceTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshPrices());
    _candlesTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshCandles());
  }

  @override
  void dispose() {
    _tab.dispose();
    _priceTimer?.cancel();
    _candlesTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPrices() async {
    try {
      final tickers = await _api.getTickers();
      final map = <String, double>{};
      for (final t in tickers) {
        final sym = (t['symbol'] ?? '').toString();
        final lp = double.tryParse((t['lastPrice'] ?? '0').toString()) ?? 0;
        if (sym.isNotEmpty && lp > 0) map[sym] = lp;
      }
      if (!mounted) return;
      setState(() {
        _prices..clear()..addAll(map);
      });
    } catch (_) {}
  }

  Future<void> _refreshCandles() async {
    final active = context.read<TradesProvider>().active;
    final updates = <String, List<Candle>>{};
    for (final t in active) {
      try {
        final candles = await _api.getKline(
          symbol: t.symbol,
          interval: '15',
          limit: 30,
        );
        if (candles.isNotEmpty) updates[t.symbol] = candles;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _miniCandles..clear()..addAll(updates);
    });
  }

  @override
  Widget build(BuildContext context) {
    final trades = context.watch<TradesProvider>();
    final bot = context.watch<BotStatusProvider>();
    
    if (trades.active.isNotEmpty && _miniCandles.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCandles());
    }
    
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Эйнштейн'),
            const SizedBox(width: 10),
            _BotStatusChip(running: bot.isRunning, busy: bot.isBusy),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: () async {
              trades.refresh();
              await _refreshPrices();
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Настройки',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Управление ботом',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TradingModeScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accentGreen,
          labelColor: AppColors.darkTextPrimary,
          unselectedLabelColor: AppColors.darkTextSecondary,
          tabs: [
            Tab(text: 'Активные (${trades.active.length})'),
            Tab(text: 'Наблюдение (${trades.watched.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ActiveList(trades: trades.active, prices: _prices, miniCandles: _miniCandles),
          _WatchedList(trades: trades.watched),
        ],
      ),
    );
  }
}

class _ActiveList extends StatelessWidget {
  final List<dynamic> trades;
  final Map<String, double> prices;
  final Map<String, List<Candle>> miniCandles;
  const _ActiveList({required this.trades, required this.prices, required this.miniCandles});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const _EmptyState(
        icon: Icons.auto_awesome,
        title: 'Сканер чист, ищу сетапы...',
        subtitle: 'Как только найду монету в укате с паттерном, она появится здесь автоматически.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: trades.length,
      itemBuilder: (context, i) {
        final t = trades[i];
        return ActiveTradeCard(
          trade: t,
          currentPrice: prices[t.symbol],
          miniCandles: miniCandles[t.symbol] ?? const [],
        );
      },
    );
  }
}

class _WatchedList extends StatelessWidget {
  final List<dynamic> trades;
  const _WatchedList({required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const _EmptyState(
        icon: Icons.visibility_outlined,
        title: 'Ничего на радаре',
        subtitle: 'Здесь появятся монеты, которые нашли укат и паттерн, но пока ждут подтверждения входа.',
      );
    }
    final provider = context.read<TradesProvider>();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: trades.length,
      itemBuilder: (context, i) {
        final w = trades[i];
        return WatchedCard(setup: w, onDelete: () => provider.removeWatched(w.symbol));
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Icon(icon, size: 40, color: AppColors.accentGreen),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _BotStatusChip extends StatelessWidget {
  final bool running;
  final bool busy;
  const _BotStatusChip({required this.running, required this.busy});

  @override
  Widget build(BuildContext context) {
    final color = busy ? AppColors.accentYellow : (running ? AppColors.accentGreen : AppColors.darkTextSecondary);
    final label = busy ? 'Запуск…' : (running ? 'Работает' : 'Остановлен');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha((0.4 * 255).toInt())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
