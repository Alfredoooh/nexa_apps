import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../screens/ad_block_calendar_screen.dart';

/// Gauge circular de bloqueio de anúncios, inspirado no mostrador Wear OS.
class AdBlockStatsChart extends StatelessWidget {
  const AdBlockStatsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = AdBlockStats.instance;
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);

    return AnimatedBuilder(
      animation: stats,
      builder: (context, _) {
        final total = stats.totalBlocked;
        // 1.000 bloqueios correspondem ao arco completo; o número continua
        // a apresentar o total real, sem limitar os dados persistidos.
        final double progress = total == 0
            ? 0.0
            : (0.16 + 0.84 * (1 - math.exp(-total / 650)))
                .clamp(0.0, 1.0)
                .toDouble();
        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const AdBlockCalendarScreen(),
                ),
              ),
              child: SizedBox(
                width: 278,
                height: 278,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: settingsCardColor(context),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              Theme.of(context).brightness == Brightness.dark ? .18 : .06,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: Transform.rotate(
                        angle: math.pi,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1050),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => CustomPaint(
                            painter: _AdGaugePainter(
                              progress: value,
                              trackColor: muted.withOpacity(.20),
                              valueColor: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 208,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Symbols.shield_rounded, size: 20, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'Anúncios bloqueados',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 19),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: total.toDouble()),
                            duration: const Duration(milliseconds: 950),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _formatGaugeValue(value.round()),
                                maxLines: 1,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 49,
                                  height: 1,
                                  letterSpacing: -1.8,
                                  fontWeight: FontWeight.w400,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'bloqueados no total',
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Ver calendário',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatGaugeValue(int value) {
  final raw = value.toString();
  final output = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) output.write(',');
    output.write(raw[index]);
  }
  return output.toString();
}

class _AdGaugePainter extends CustomPainter {
  const _AdGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.valueColor,
  });

  final double progress;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = 7 * math.pi / 4; // 315°: começo no topo direito.
    const sweepAngle = 3 * math.pi / 2; // 270°: abertura central no topo.
    final rect = Rect.fromLTWH(13, 13, size.width - 26, size.height - 26);
    const stroke = 11.5;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = valueColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, track);
    if (progress > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle * progress, false, active);
    }
  }

  @override
  bool shouldRepaint(covariant _AdGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.valueColor != valueColor;
}

/// Dois mini-cards distintos para os totais de sites e jogos.
class ActivitySummaryCard extends StatelessWidget {
  const ActivitySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = activityController.entries;
    final sites = entries.where((entry) => entry.kind == ActivityKind.site).length;
    final games = entries.where((entry) => entry.kind == ActivityKind.game).length;

    return Row(
      children: [
        Expanded(
          child: _ActivityMiniCard(
            icon: Symbols.public_rounded,
            label: 'Sites visitados',
            value: sites,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityMiniCard(
            icon: Symbols.sports_esports_rounded,
            label: 'Jogos jogados',
            value: games,
          ),
        ),
      ],
    );
  }
}

class _ActivityMiniCard extends StatelessWidget {
  const _ActivityMiniCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
