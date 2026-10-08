// ==========================================================
//  ЭЙНШТЕЙН — Карточки сетапов (активная сделка + наблюдение)
//  Файл: lib/presentation/widgets/trade_card.dart
//  • Плоский стиль ntfy: тонкая граница, скругление 16, лёгкая тень.
//  • Тап по карточке — плавное раскрытие вниз.
//  • Снизу — детали, мини-график и действия.
// ==========================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/active_trade.dart';
import '../../data/models/candle.dart';
import '../../data/models/watched_setup.dart';

// ==========================================================
// 🟢 КАРТОЧКА АКТИВНОЙ СДЕЛКИ
// ==========================================================
class ActiveTradeCard extends StatefulWidget {
  final ActiveTrade trade;
  final double? currentPrice;
  final List<Candle> miniCandles;

  const ActiveTradeCard({
    super.key,
    required this.trade,
    required this.currentPrice,
    this.miniCandles = const [],
  });

  @override
  State<ActiveTradeCard> createState() => _ActiveTradeCardState();
}

class _ActiveTradeCardState extends State<ActiveTradeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _expand;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expand = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final curr = widget.currentPrice ?? t.entryPrice;
    final pnlPct = ((curr - t.entryPrice) / t.entryPrice) * 100.0;

    // Цвет бейджа: зелёный/красный в зависимости от PnL.
    final accent = pnlPct >= 0
        ? AppColors.accentGreen
        : AppColors.accentRed;

    return _CardShell(
      onTap: _toggle,
      accentColor: accent,
      badgeText: Formatters.percentSigned(pnlPct),
      badgeIcon: Formatters.trendIcon(pnlPct),
      title: t.symbol,
      subtitle: t.patternName.isEmpty ? 'Сделка открыта' : t.patternName,
      // Раскрываемая часть.
      expanded: _expanded,
      animation: _expand,
      child: _ActiveDetails(
        trade: t,
        currentPrice: curr,
        pnlPct: pnlPct,
        miniCandles: widget.miniCandles,
      ),
    );
  }
}

class _ActiveDetails extends StatelessWidget {
  final ActiveTrade trade;
  final double currentPrice;
  final double pnlPct;
  final List<Candle> miniCandles;

  const _ActiveDetails({
    required this.trade,
    required this.currentPrice,
    required this.pnlPct,
    required this.miniCandles,
  });

  @override
  Widget build(BuildContext context) {
    final t = trade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // ---------- Мини-график ----------
        if (miniCandles.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  candles: miniCandles,
                  lineColor: pnlPct >= 0
                      ? AppColors.accentGreen
                      : AppColors.accentRed,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),

        // ---------- Сетка уровней ----------
        _levelsGrid(t, currentPrice),

        const SizedBox(height: 12),

        // ---------- Прогресс TP ----------
        _tpProgress(t),

        const SizedBox(height: 10),

        // ---------- Мета ----------
        Row(
          children: [
            Expanded(
              child: _MetaRow(
                icon: Icons.schedule,
                text: 'Вход: ${t.entryTime}',
              ),
            ),
            Expanded(
              child: _MetaRow(
                icon: Icons.shield_outlined,
                text: t.tradingMode == 'real' ? 'REAL' : 'PAPER',
                highlight: t.tradingMode == 'real',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _levelsGrid(ActiveTrade t, double curr) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _LevelBox(
                label: 'ВХОД',
                value: Formatters.price(t.entryPrice),
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LevelBox(
                label: 'ТЕКУЩАЯ',
                value: Formatters.price(curr),
                color: curr >= t.entryPrice
                    ? AppColors.accentGreen
                    : AppColors.accentRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _LevelBox(
                label: 'TP1',
                value: Formatters.price(t.tp1),
                done: t.tp1Done,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LevelBox(
                label: 'TP2',
                value: Formatters.price(t.tp2),
                done: t.tp2Done,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LevelBox(
                label: 'TP3',
                value: Formatters.price(t.tp3),
                done: t.tp3TrailingActive,
                color: AppColors.accentPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _LevelBox(
          label: 'СТОП-ЛОСС',
          value: Formatters.price(t.stopLoss),
          color: AppColors.accentRed,
        ),
      ],
    );
  }

  Widget _tpProgress(ActiveTrade t) {
    // Прогресс = сколько этапов пройдено.
    final steps = [
      t.tp1Done,
      t.tp2Done,
      t.tp3TrailingActive,
    ];
    return Row(
      children: List.generate(steps.length, (i) {
        final done = steps[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: done
                    ? (i == 2
                        ? AppColors.accentPurple
                        : AppColors.accentGreen)
                    : AppColors.darkBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ==========================================================
// 👁 КАРТОЧКА НАБЛЮДЕНИЯ
// ==========================================================
class WatchedCard extends StatefulWidget {
  final WatchedSetup setup;
  final VoidCallback? onDelete;

  const WatchedCard({
    super.key,
    required this.setup,
    this.onDelete,
  });

  @override
  State<WatchedCard> createState() => _WatchedCardState();
}

class _WatchedCardState extends State<WatchedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _expand;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expand = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.setup;

    return _CardShell(
      onTap: _toggle,
      accentColor: AppColors.accentYellow,
      badgeText: 'ЖДЁМ',
      badgeIcon: '👀',
      title: w.symbol,
      subtitle: w.patternName,
      expanded: _expanded,
      animation: _expand,
      child: _WatchedDetails(setup: w, onDelete: widget.onDelete),
    );
  }
}

class _WatchedDetails extends StatelessWidget {
  final WatchedSetup setup;
  final VoidCallback? onDelete;

  const _WatchedDetails({required this.setup, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final w = setup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _LevelBox(
                label: 'ЦЕНА',
                value: Formatters.price(w.detectedPrice),
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LevelBox(
                label: 'ТРИГГЕР',
                value: Formatters.price(w.triggerPrice),
                color: AppColors.accentYellow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _LevelBox(
                label: 'МИН. ПАТТЕРНА',
                value: Formatters.price(w.patternLow),
                color: AppColors.accentRed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LevelBox(
                label: 'ИСТОР. ДНО',
                value: Formatters.price(w.historicalLow),
                color: AppColors.accentRed,
              ),
            ),
          ],
        ),

        if (w.macroReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights,
                    size: 14, color: AppColors.accentBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    w.macroReason,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // ---------- Кнопки ----------
        Row(
          children: [
            Expanded(
              child: _MetaRow(
                icon: Icons.schedule,
                text: 'Найдено: ${w.detectedAt}',
              ),
            ),
            if (onDelete != null)
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.accentRed),
                label: const Text(
                  'Удалить',
                  style: TextStyle(color: AppColors.accentRed),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ==========================================================
// 🧱 ОБЩАЯ «ОБОЛОЧКА» КАРТОЧКИ (шапка + раскрытие)
// ==========================================================
class _CardShell extends StatelessWidget {
  final VoidCallback onTap;
  final Color accentColor;
  final String badgeText;
  final String badgeIcon;
  final String title;
  final String subtitle;
  final bool expanded;
  final Animation<double> animation;
  final Widget child;

  const _CardShell({
    required this.onTap,
    required this.accentColor,
    required this.badgeText,
    required this.badgeIcon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Шапка ----------
              Row(
                children: [
                  // Левый акцентный «нос».
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Заголовок и подзаголовок.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.darkTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.darkTextSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Бейдж статуса / PnL.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(badgeIcon,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Стрелка раскрытия.
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 220),
                    turns: expanded ? 0.5 : 0.0,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),

              // ---------- Раскрывающийся блок ----------
              SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// 🧩 МЕЛКИЕ ВИДЖЕТЫ
// ==========================================================
class _LevelBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool done;

  const _LevelBox({
    required this.label,
    required this.value,
    required this.color,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: done
            ? Border.all(color: color.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (done)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle,
                      size: 11, color: color),
                ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _MetaRow({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: highlight
                ? AppColors.accentPurple
                : AppColors.darkTextSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: highlight
                  ? AppColors.accentPurple
                  : AppColors.darkTextSecondary,
              fontSize: 12,
              fontWeight:
                  highlight ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// 📈 МИНИ-СПАРКЛАЙН (CustomPaint, без пакетов)
// ==========================================================
class _SparklinePainter extends CustomPainter {
  final List<Candle> candles;
  final Color lineColor;

  _SparklinePainter({required this.candles, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // Диапазон min..max закрытий.
    double min = candles.first.close;
    double max = candles.first.close;
    for (final c in candles) {
      if (c.close < min) min = c.close;
      if (c.close > max) max = c.close;
    }
    final range = (max - min).abs() < 1e-12 ? 1.0 : (max - min);

    // ---------- Заливка под линией ----------
    final fillPath = Path();
    final linePath = Path();

    for (var i = 0; i < candles.length; i++) {
      final x = (i / (candles.length - 1)) * size.width;
      final y = size.height -
          ((candles[i].close - min) / range) * (size.height - 4) -
          2;

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
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // ---------- Линия ----------
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.candles != candles || old.lineColor != lineColor;
}