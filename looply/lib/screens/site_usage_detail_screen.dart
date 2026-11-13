import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../localization.dart';
import '../models.dart';
import '../browser_library.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Detalhe de uso por site: percentagem de visitas em relação aos restantes
/// sites e tempo total desde a primeira visita registada até à última.
///
/// Nota sobre os dados: o Looply não regista a duração de cada sessão de
/// navegação (quanto tempo uma aba ficou aberta). Por isso "tempo de uso"
/// aqui é calculado como o intervalo real entre a primeira e a última visita
/// registadas a esse site no histórico de atividade — e a percentagem é
/// calculada a partir do número real de visitas de cada site, não de um
/// valor fixo. Não há nenhum dado inventado nesta tela.
class SiteUsageDetailScreen extends StatefulWidget {
  const SiteUsageDetailScreen({super.key});
  @override
  State<SiteUsageDetailScreen> createState() => _SiteUsageDetailScreenState();
}

class _SiteUsageDetailScreenState extends State<SiteUsageDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (mounted) setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);

    final allStats = _computeSiteStats();
    final stats = allStats.where((item) => _query.isEmpty || item.host.contains(_query) || item.title.toLowerCase().contains(_query)).toList(growable: false);
    final maxVisits = stats.isEmpty
        ? 0
        : stats.map((item) => item.visitCount).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: true,
        title: Text(appText('visited_sites')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Container(
              height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(15)),
              child: Row(children: [
                AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 19),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _searchController, style: TextStyle(color: text, fontSize: 14), decoration: InputDecoration(border: InputBorder.none, hintText: appText('search_history'), hintStyle: TextStyle(color: muted), isDense: true))),
                if (_query.isNotEmpty) IconButton(onPressed: _searchController.clear, icon: Icon(Icons.close_rounded, color: muted, size: 18)),
              ]),
            ),
          ),
          if (allStats.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: settingsCardColor(context), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(appText('visited_sites'), style: TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 4), Text('${allStats.length}', style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800))])),
                AppMaterialIcon(AppIcons.globe, size: 26, color: accent),
              ]),
            ),
          ),
          Expanded(child: stats.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppMaterialIcon(AppIcons.globe, size: 38, color: muted),
                    const SizedBox(height: 9),
                    Text(
                      appText('no_recent_activity'),
                      style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: stats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = stats[index];
                final fraction = maxVisits == 0 ? 0.0 : item.visitCount / maxVisits;
                return _SiteUsageTile(item: item, fraction: fraction);
              },
            )),
        ],
      ),
    );
  }

  List<_SiteStat> _computeSiteStats() {
    final byHost = <String, List<ActivityEntry>>{};
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      final host = Uri.tryParse(entry.url)?.host.toLowerCase();
      if (host == null || host.isEmpty) continue;
      byHost.putIfAbsent(host, () => []).add(entry);
    }

    final totalVisits = byHost.values.fold<int>(0, (sum, list) => sum + list.length);
    final stats = byHost.entries.map((grouped) {
      final host = grouped.key;
      final visits = grouped.value;
      final timestamps = visits.map((entry) => entry.timestamp).toList()..sort();
      final first = timestamps.first;
      final last = timestamps.last;
      final span = last.difference(first);
      return _SiteStat(
        host: host,
        title: visits.first.title,
        url: visits.first.url,
        visitCount: visits.length,
        percentOfTotal: totalVisits == 0 ? 0 : (visits.length / totalVisits) * 100,
        firstVisit: first,
        lastVisit: last,
        activeSpan: span,
      );
    }).toList();

    stats.sort((a, b) => b.visitCount.compareTo(a.visitCount));
    return stats;
  }
}

class _SiteStat {
  const _SiteStat({
    required this.host,
    required this.title,
    required this.url,
    required this.visitCount,
    required this.percentOfTotal,
    required this.firstVisit,
    required this.lastVisit,
    required this.activeSpan,
  });
  final String host;
  final String title;
  final String url;
  final int visitCount;
  final double percentOfTotal;
  final DateTime firstVisit;
  final DateTime lastVisit;
  final Duration activeSpan;
}

String _formatSpan(Duration span) {
  if (span.inMinutes < 1) return appText('time_now');
  if (span.inHours < 1) return appText('time_minutes').replaceAll('{count}', span.inMinutes.toString());
  if (span.inDays < 1) return appText('time_hours').replaceAll('{count}', span.inHours.toString());
  return appText('time_days').replaceAll('{count}', span.inDays.toString());
}

class _SiteUsageTile extends StatelessWidget {
  const _SiteUsageTile({required this.item, required this.fraction});
  final _SiteStat item;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final encoded = browserFaviconCache.forUrl('https://${item.host}');

    Widget icon = AppMaterialIcon(AppIcons.globe, color: accent, size: 19);
    if (encoded != null) {
      try {
        icon = ClipOval(
          child: Image.memory(
            base64Decode(encoded),
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: accent, size: 19),
          ),
        );
      } catch (_) {}
    }

    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: () => openOrbitTab(context, item.url, title: item.title),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                child: Center(child: icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isNotEmpty ? item.title : item.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.percentOfTotal.toStringAsFixed(1)}%',
                style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: pillColor(context),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Symbols.bar_chart_rounded, size: 14, color: muted),
              const SizedBox(width: 4),
              Text(
                appText('visit_count').replaceAll('{count}', item.visitCount.toString()),
                style: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              Icon(Symbols.schedule_rounded, size: 14, color: muted),
              const SizedBox(width: 4),
              Text(
                _formatSpan(item.activeSpan),
                style: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
      ),
      ),
    );
  }
}