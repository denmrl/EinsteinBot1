// ==========================================================
//  ЭЙНШТЕЙН — Экран статистики (совместимо с Flutter 3.24)
//  Файл: lib/presentation/screens/statistics_screen.dart
// ==========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/providers/trades_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/closed_trade.dart';
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
  void initState() {
    super.initState();
    _reloadHistory();
  }

  void _reloadHistory() {
    setState(() => _history = _balance.getBalanceHistory());
  }

  @override
  Widget build(BuildContext context) {
    final trades = context.watch<TradesProvider>();
    final settings = context.watch<SettingsProvider>();

    final chartPoints = _history.isNotEmpty
        ? _history
        : [
            BalancePoint(
              timestamp: DateTime.now(),
              balance: settings.paperBalanceUsdt,
            ),
          ];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await settings.refreshUsdRub();
              _reloadHistory();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentGreen,
        backgroundColor: AppColors.darkSurface,
        onRefresh: () async {
          await settings.refreshUsdRub();
          _reloadHistory();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _BalanceHeadlineCard(
              usdt: settings.paperBalanceUsdt,
              rub: settings.balanceInRub,
              rate: settings.usdRubRate,
              pnlUsdt: trades.totalPnlUsdt,
            ),
            _SectionTitle('Динамика баланса'),
            _BalanceChartCard(points: chartPoints),
            _SectionTitle('Статистика'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatBadge(
                          icon: '🏆',
                          label: 'Винрейт',
                          value: Formatters.percent(trades.winRatePct,
                              decimals: 1),
                          color: _winRateColor(trades.winRatePct),
                          subtitle:
                              '${trades.wins} / ${trades.totalTrades}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBadge(
                          icon: '⚖️',
                          label: 'Прибыль / Убыток',
                          value: _ratioLabel(trades.profitLossRatio),
                          color: _ratioColor(trades.profitLossRatio),
                          subtitle: 'коэффициент',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBadge(
                          icon: '🟢',
                          label: 'Профит',
                          value:
                              '+${trades.totalGainPct.toStringAsFixed(2)}%',
                          color: AppColors.accentGreen,
                          subtitle: 'суммарный',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBadge(
                          icon: '🔴',
                          label: 'Убыток',
                          value:
                              '-${trades.totalLossPct.toStringAsFixed(2)}%',
                          color: AppColors.accentRed,
                          subtitle: 'суммарный',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _SectionTitle('Последние сделки'),
            if (trades.history.isEmpty)
              const _EmptyHistory()
            else
              ...trades.lastClosed.map((t) => _ClosedTradeRow(trade: t)),
          ],
        ),
      ),
    );
  }

  Color _winRateColor(double pct) {
    if (pct >= 60) return AppColors.accentGreen;
    if (pct >= 45) return AppColors.accentYellow;
    if (pct > 0) return AppColors.accentRed;
    return AppColors.darkTextSecondary;
  }

  Color _ratioColor(double r) {
    if (r == double.infinity) return AppColors.accentPurple;
    if (r >= 1.5) return AppColors.accentGreen;
    if (r >= 1.0) return AppColors.accentYellow;
    return AppColors.accentRed;
  }

  String _ratioLabel(double r) {
    if (r == double.infinity) return '∞';
    return r.toStringAsFixed(2);
  }
}

class _BalanceHeadlineCard extends StatelessWidget {
  final double usdt;
  final double? rub;
  final double? rate;
  final double pnlUsdt;

  const _BalanceHeadlineCard({
    required this.usdt,
    required this.rub,
    required this.rate,
    required this.pnlUsdt,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor =
        pnlUsdt >= 0 ? AppColors.accentGreen : AppColors.accentRed;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: AppColors.darkTextSecondary),
              const SizedBox(width: 6),
              const Text(
                'ТЕКУЩИЙ БАЛАНС',
                style: TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (rate != null)
                Text(
                  Formatters.rateUsdRub(rate!),
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Formatters.usdt(usdt),
            style: const TextStyle(
              color: AppColors.darkTextPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rub == null ? '— ₽' : Formatters.rub(rub!),
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: pnlColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pnlUsdt >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  size: 16,
                  color: pnlColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'PnL: ${Formatters.usdt(pnlUsdt)}',
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
    final isGrowing = points.length < 2
        ? true
        : points.last.balance >= points.first.balance;
    final accent =
        isGrowing ? AppColors.accentGreen : AppColors.accentRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Мин: ${Formatters.usdt(points.map((p) => p.balance).reduce((a, b) => a < b ? a : b))}',
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Макс: ${Formatters.usdt(points.map((p) => p.balance).reduce((a, b) => a > b ? a : b))}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: points.length < 2
                ? Center(
                    child: Text(
                      'Пока нет данных для графика.\n'
                      'Сделки появятся — график начнёт расти.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkTextSecondary
                            .withOpacity(0.7),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _BalanceChartPainter(
                      points: points,
                      lineColor: accent,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (points.length >= 2)
            Row(
              children: [
                Text(
                  _shortTime(points.first.timestamp),
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  _shortTime(points.last.timestamp),
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d.$m $h:$mi';
  }
}

class _BalanceChartPainter extends CustomPainter {
  final List<BalancePoint> points;
  final Color lineColor;

  _BalanceChartPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double min = points.first.balance;
    double max = points.first.balance;
    for (final p in points) {
      if (p.balance < min) min = p.balance;
      if (p.balance > max) max = p.balance;
    }
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    const padding = 8.0;
    final drawHeight = size.height - padding * 2;

    final linePath = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y = padding +
          drawHeight -
          ((points[i].balance - min) / range) * drawHeight;

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.30),
          lineColor.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final lastX = size.width;
    final lastY = padding +
        drawHeight -
        ((points.last.balance - min) / range) * drawHeight;

    canvas.drawCircle(
      Offset(lastX, lastY),
      6,
      Paint()..color = lineColor.withOpacity(0.25),
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      3,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _BalanceChartPainter old) =>
      old.points != points || old.lineColor != lineColor;
}

class _StatBadge extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.darkTextSecondary.withOpacity(0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedTradeRow extends StatelessWidget {
  final ClosedTrade trade;

  const _ClosedTradeRow({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isWin = trade.isWin;
    final color = isWin ? AppColors.accentGreen : AppColors.accentRed;
    final pnl = trade.finalNetPnlPct;

    IconData reasonIcon;
    if (trade.reason.contains('Trailing')) {
      reasonIcon = Icons.rocket_launch_outlined;
    } else if (trade.reason.contains('Stop Loss')) {
      reasonIcon = Icons.shield_outlined;
    } else if (trade.reason.contains('TP')) {
      reasonIcon = Icons.flag_outlined;
    } else {
      reasonIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(reasonIcon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trade.symbol,
                      style: const TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trade.tradingMode == 'real') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'REAL',
                          style: TextStyle(
                            color: AppColors.accentPurple,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${trade.reason} • ${_shortDate(trade.closedAt)}',
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            Formatters.percentSigned(pnl),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String s) {
    try {
      final parts = s.split(' ');
      if (parts.length != 2) return s;
      final d = parts[0].split('-');
      final t = parts[1].split(':');
      if (d.length != 3 || t.length < 2) return s;
      return '${d[2]}.${d[1]} ${t[0]}:${t[1]}';
    } catch (_) {
      return s;
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.darkTextSecondary.withOpacity(0.5)),
          const SizedBox(height: 10),
          const Text(
            'Пока ни одной закрытой сделки',
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Как только бот закроет первую позицию — она появится здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}