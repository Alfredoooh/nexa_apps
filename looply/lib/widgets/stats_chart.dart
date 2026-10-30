import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';

// Gráfico simples de barras (sem dependências externas) para mostrar
// o número de anúncios bloqueados nos últimos 7 "buckets" de sessão.
class AdBlockStatsChart extends StatefulWidget {
  const AdBlockStatsChart({super.key});
  @override
  State<AdBlockStatsChart> createState() => _AdBlockStatsChartState();
}

class _AdBlockStatsChartState extends State<AdBlockStatsChart> {
  @override
  void initState() {
    super.initState();
    AdBlockStats.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    AdBlockStats.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final stats = AdBlockStats.instance;
    final buckets = stats.dailyBuckets;
    final maxValue = buckets.fold<int>(1, (max, v) => v > max ? v : max);
    const labels = ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'Ontem', 'Hoje'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panelColor(context), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.shield_rounded, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Anúncios bloqueados', style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800))),
          Text('${stats.totalBlocked}', style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(buckets.length, (index) {
              final value = buckets[index];
              final heightFraction = value / maxValue;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('$value', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 50 * (heightFraction.clamp(0.04, 1.0)),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(index == buckets.length - 1 ? 1 : .45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[index], style: TextStyle(color: muted, fontSize: 9)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// Resumo de atividades gerais (sites visitados, jogos jogados) para a
// tela de Atividade / Histórico.
class ActivitySummaryCard extends StatelessWidget {
  const ActivitySummaryCard({super.key});
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final entries = activityController.entries;
    final sites = entries.where((e) => e.kind == ActivityKind.site).length;
    final games = entries.where((e) => e.kind == ActivityKind.game).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: panelColor(context), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.public_rounded, color: accent, size: 20),
            const SizedBox(height: 8),
            Text('$sites', style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Sites visitados', style: TextStyle(color: muted, fontSize: 11)),
          ]),
        ),
        Container(width: 1, height: 44, color: lineColor(context)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.sports_esports_rounded, color: accent, size: 20),
            const SizedBox(height: 8),
            Text('$games', style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Jogos jogados', style: TextStyle(color: muted, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}
