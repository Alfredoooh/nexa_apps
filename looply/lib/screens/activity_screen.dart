import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/stats_chart.dart';
import '../shell/browser_navigation.dart';
import 'game_webview_screen.dart';
import 'history_screen.dart';

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
                ...List.generate(recent.length, (index) {
                  final isFirst = index == 0;
                  final isLast = index == recent.length - 1;
                  final top = isFirst ? 22.0 : 8.0;
                  final bottom = isLast ? 22.0 : 8.0;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                    child: ActivityTile(
                      entry: recent[index],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(top),
                        bottom: Radius.circular(bottom),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry, this.borderRadius});
  final ActivityEntry entry;
  final BorderRadius? borderRadius;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final isGame = entry.kind == ActivityKind.game;
    return Material(
      color: settingsCardColor(context),
      borderRadius: borderRadius ?? BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isGame) {
            final game = looplyGames.firstWhere((g) => g.url == entry.url, orElse: () => looplyGames.first);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameWebViewScreen(game: game)));
          } else {
            openOrbitTab(context, entry.url, title: entry.title);
          }
        },
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
              child: Icon(isGame ? Symbols.sports_esports_rounded : Symbols.public_rounded, color: accentColor(context), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(formatActivityTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            Icon(Symbols.chevron_right_rounded, color: muted, size: 18),
          ]),
        ),
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