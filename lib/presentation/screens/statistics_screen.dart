import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/trades_provider.dart';
import 'log_screen.dart';
import '../../core/providers/system_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/closed_trade.dart';
import '../../data/models/system_status.dart';
import '../../data/repositories/balance_repository.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _balance = BalanceRepository.instance;
  List<BalancePoint> _history = const [];

  @override
  void initState() { super.initState(); _reloadHistory(); }
  void _reloadHistory() => setState(() => _history = _balance.getBalanceHistory());

  @override
  Widget build(BuildContext context) {
    final trades = context.watch<TradesProvider>();
    final settings = context.watch<SettingsProvider>();
    final sys = context.watch<SystemProvider>();
    final chartPoints = _history.isNotEmpty ? _history : [BalancePoint(timestamp: DateTime.now(), balance: settings.paperBalanceUsdt)];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: 'Полный лог',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogScreen())),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () async { await settings.refreshUsdRub(); _reloadHistory(); }),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentGreen, backgroundColor: AppColors.darkSurface,
        onRefresh: () async { await settings.refreshUsdRub(); _reloadHistory(); },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _BalanceHeadlineCard(usdt: settings.paperBalanceUsdt, rub: settings.balanceInRub, rate: settings.usdRubRate, pnlUsdt: trades.totalPnlUsdt),
            _SectionTitle('Динамика баланса'),
            _BalanceChartCard(points: chartPoints),
            _SectionTitle('Здоровье системы (API)'),
            _SystemHealthCard(metrics: sys.metrics, history: sys.history),
            _SectionTitle('Статистика'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _StatBadge(icon: '🏆', label: 'Винрейт', value: Formatters.percent(trades.winRatePct, decimals: 1), color: _winRateColor(trades.winRatePct), subtitle: '${trades.wins} / ${trades.totalTrades}')),
                  const SizedBox(width: 8),
                  Expanded(child: _StatBadge(icon: '⚖️', label: 'Приб / Убыт', value: _ratioLabel(trades.profitLossRatio), color: _ratioColor(trades.profitLossRatio), subtitle: 'коэффициент')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _StatBadge(icon: '🟢', label: 'Профит', value: '+${trades.totalGainPct.toStringAsFixed(2)}%', color: AppColors.accentGreen, subtitle: 'суммарный')),
                  const SizedBox(width: 8),
                  Expanded(child: _StatBadge(icon: '🔴', label: 'Убыток', value: '-${trades.totalLossPct.toStringAsFixed(2)}%', color: AppColors.accentRed, subtitle: 'суммарный')),
                ]),
              ]),
            ),
            _SectionTitle('Последние сделки'),
            if (trades.history.isEmpty) const _EmptyHistory()
            else ...trades.lastClosed.map((t) => _ClosedTradeRow(trade: t)),
          ],
        ),
      ),
    );
  }

  Color _winRateColor(double pct) => pct >= 60 ? AppColors.accentGreen : (pct >= 45 ? AppColors.accentYellow : (pct > 0 ? AppColors.accentRed : AppColors.darkTextSecondary));
  Color _ratioColor(double r) => r == double.infinity ? AppColors.accentPurple : (r >= 1.5 ? AppColors.accentGreen : (r >= 1.0 ? AppColors.accentYellow : AppColors.accentRed));
  String _ratioLabel(double r) => r == double.infinity ? '∞' : r.toStringAsFixed(2);
}

class _BalanceHeadlineCard extends StatelessWidget {
  final double usdt; final double? rub; final double? rate; final double pnlUsdt;
  const _BalanceHeadlineCard({required this.usdt, required this.rub, required this.rate, required this.pnlUsdt});

  @override
  Widget build(BuildContext context) {
    final pnlColor = pnlUsdt >= 0 ? AppColors.accentGreen : AppColors.accentRed;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 6), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.darkBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.darkTextSecondary),
            const SizedBox(width: 6),
            const Text('ТЕКУЩИЙ БАЛАНС', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            if (rate != null) Text(Formatters.rateUsdRub(rate!), style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Text(Formatters.usdt(usdt), style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(rub == null ? '— ₽' : Formatters.rub(rub!), style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: pnlColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(pnlUsdt >= 0 ? Icons.trending_up : Icons.trending_down, size: 16, color: pnlColor),
              const SizedBox(width: 6),
              Text('PnL: ${Formatters.usdt(pnlUsdt)}', style: TextStyle(color: pnlColor, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _BalanceChartCard extends StatelessWidget {
  final List<BalancePoint> points;
  const _BalanceChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final isGrowing = points.length < 2 ? true : points.last.balance >= points.first.balance;
    final accent = isGrowing ? AppColors.accentGreen : AppColors.accentRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Мин: ${Formatters.usdt(points.map((p) => p.balance).reduce((a, b) => a < b ? a : b))}', style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11))),
            Expanded(child: Text('Макс: ${Formatters.usdt(points.map((p) => p.balance).reduce((a, b) => a > b ? a : b))}', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 180, width: double.infinity,
            child: points.length < 2
                ? Center(child: Text('Пока нет данных для графика.\nСделки появятся — график начнёт расти.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.darkTextSecondary.withOpacity(0.7), fontSize: 12, height: 1.4)))
                : CustomPaint(painter: _BalanceChartPainter(points: points, lineColor: accent)),
          ),
          const SizedBox(height: 8),
          if (points.length >= 2)
            Row(children: [
              Text(_shortTime(points.first.timestamp), style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 10)),
              const Spacer(),
              Text(_shortTime(points.last.timestamp), style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 10)),
            ]),
        ],
      ),
    );
  }
  String _shortTime(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// УЛУЧШЕННЫЙ PAINTER (СЕТКА + СВЕЧЕНИЕ)
class _BalanceChartPainter extends CustomPainter {
  final List<BalancePoint> points; final Color lineColor;
  _BalanceChartPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double min = points.first.balance, max = points.first.balance;
    for (final p in points) { if (p.balance < min) min = p.balance; if (p.balance > max) max = p.balance; }
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    const padding = 20.0;
    final drawHeight = size.height - padding * 2;
    final drawWidth = size.width;

    // 1. Сетка (горизонтальные линии)
    final gridPaint = Paint()..color = AppColors.darkBorder.withOpacity(0.5)..strokeWidth = 1.0;
    for (int i = 0; i <= 4; i++) {
      final y = padding + (drawHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(drawWidth, y), gridPaint);
    }

    // 2. Пути (линия и заливка)
    final linePath = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * drawWidth;
      final y = padding + drawHeight - ((points[i].balance - min) / range) * drawHeight;
      if (i == 0) { linePath.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y); }
      else { linePath.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(drawWidth, size.height); fillPath.close();

    // 3. Заливка
    final fillPaint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
    ).createShader(Rect.fromLTWH(0, 0, drawWidth, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 4. Свечение (Glow)
    final glowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);

    // 5. Сама линия
    final linePaint = Paint()..color = lineColor..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 6. Точка на конце
    final lastX = drawWidth;
    final lastY = padding + drawHeight - ((points.last.balance - min) / range) * drawHeight;
    canvas.drawCircle(Offset(lastX, lastY), 6, Paint()..color = lineColor.withOpacity(0.25));
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _BalanceChartPainter old) => old.points != points || old.lineColor != lineColor;
}

class _StatBadge extends StatelessWidget {
  final String icon; final String label; final String value; final String subtitle; final Color color;
  const _StatBadge({required this.icon, required this.label, required this.value, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(icon, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: AppColors.darkTextSecondary.withOpacity(0.8), fontSize: 10)),
      ]),
    );
  }
}

class _ClosedTradeRow extends StatelessWidget {
  final ClosedTrade trade;
  const _ClosedTradeRow({required this.trade});
  @override
  Widget build(BuildContext context) {
    final isWin = trade.isWin; final color = isWin ? AppColors.accentGreen : AppColors.accentRed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(trade.reason.contains('Trailing') ? Icons.rocket_launch_outlined : Icons.shield_outlined, size: 18, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(trade.symbol, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('${trade.reason} • ${_shortDate(trade.closedAt)}', style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Text(Formatters.percentSigned(trade.finalNetPnlPct), style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
  String _shortDate(String s) { try { final p = s.split(' '); final d = p[0].split('-'); final t = p[1].split(':'); return '${d[2]}.${d[1]} ${t[0]}:${t[1]}'; } catch (_) { return s; } }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.darkTextSecondary.withOpacity(0.5)),
        const SizedBox(height: 10),
        const Text('Пока ни одной закрытой сделки', style: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Как только бот закроет первую позицию — она появится здесь.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12, height: 1.35)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6), child: Text(text.toUpperCase(), style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)));
}


class _SystemHealthCard extends StatelessWidget {
  final Map<String, ApiMetric> metrics;
  final List<String> history;
  const _SystemHealthCard({required this.metrics, required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // API Метрики
          ...metrics.values.map((m) {
            final successRate = m.successCount + m.errorCount == 0 ? 0.0 : (m.successCount / (m.successCount + m.errorCount)) * 100;
            final color = successRate > 95 ? AppColors.accentGreen : (successRate > 80 ? AppColors.accentYellow : AppColors.accentRed);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.cloud_done_outlined, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Успешно: ${m.successCount} | Ошибок: ${m.errorCount} | Пинг: ${m.lastLatencyMs}мс', style: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('${successRate.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            );
          }),
          
          const Divider(color: AppColors.darkBorder, height: 24),
          
          // Мини-консоль (последние 5 логов)
          const Text('Последние события:', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: history.reversed.take(5).map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(log, style: const TextStyle(color: AppColors.accentGreen, fontSize: 12, fontFamily: 'Roboto'), maxLines: 1, overflow: TextOverflow.ellipsis),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
