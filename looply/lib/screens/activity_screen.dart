import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/stats_chart.dart';
import 'game_webview_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';

// Tela de Atividade: mostra resumo, gráfico de anúncios bloqueados e
// as 5 entradas mais recentes, com botão "Ver tudo" que leva ao
// histórico completo.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() { super.initState(); activityController.addListener(_onChanged); }
  @override
  void dispose() { activityController.removeListener(_onChanged); super.dispose(); }
  void _onChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = activityController.entries;
    final recent = entries.take(5).toList();

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(toolbarHeight: 64, title: const Text('Atividade'), actions: [if (entries.isNotEmpty) IconButton(tooltip: 'Limpar atividade', icon: Icon(Symbols.delete_sweep_rounded, color: text), onPressed: activityController.clear)]),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Symbols.history_rounded, size: 48, color: muted), const SizedBox(height: 12), Text('Sem atividade recente', style: TextStyle(color: text, fontWeight: FontWeight.w700))]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                const ActivitySummaryCard(),
                const SizedBox(height: 14),
                const AdBlockStatsChart(),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: Text('Recente', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800))),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    child: const Text('Ver tudo'),
                  ),
                ]),
                const SizedBox(height: 4),
                ...recent.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: ActivityTile(entry: entry),
                )),
              ],
            ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry});
  final ActivityEntry entry;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final isGame = entry.kind == ActivityKind.game;
    return Material(
      color: panelColor(context), borderRadius: BorderRadius.circular(16),
      child: ListTile(
        leading: Container(
          width: 40, height: 40, padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
          child: Icon(isGame ? Symbols.sports_esports_rounded : Symbols.public_rounded, color: isGame ? accentColor(context) : muted, size: 18),
        ),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        subtitle: Text(formatActivityTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 12)),
        onTap: () {
          if (isGame) {
            final game = looplyGames.firstWhere((g) => g.url == entry.url, orElse: () => looplyGames.first);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameWebViewScreen(game: game)));
          } else {
            openNewTab(context, entry.url, title: entry.title);
          }
        },
      ),
    );
  }
}

String formatActivityTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'agora mesmo';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} dias';
}
