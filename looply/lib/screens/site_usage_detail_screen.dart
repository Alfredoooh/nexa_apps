import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../browser_library.dart';
import '../localization.dart';
import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';

/// Lista os domínios visitados com a mesma estrutura visual do Histórico.
/// O período apresentado é o intervalo entre a primeira e a última visita
/// registadas; não é apresentado como duração real de utilização.
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
    activityController.addListener(_refresh);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_refresh);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (mounted) setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final bg = pageBg(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final allStats = _computeSiteStats();
    final stats = allStats
        .where((item) => _query.isEmpty || item.host.contains(_query) || item.title.toLowerCase().contains(_query))
        .toList(growable: false);
    final maxVisits = stats.isEmpty ? 0 : stats.map((item) => item.visitCount).reduce((a, b) => a > b ? a : b);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        extendBody: true,
        body: Stack(
          children: [
            if (stats.isEmpty)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(26, topInset + 78, 26, bottomInset + 84),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppMaterialIcon(AppIcons.globe, size: 46, color: muted),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty ? appText('no_recent_activity') : appText('no_results'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(14, topInset + 78, 14, bottomInset + 88),
                itemCount: stats.length,
                itemBuilder: (context, index) {
                  final item = stats[index];
                  final last = index == stats.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : 9),
                    child: _SiteUsageTile(
                      item: item,
                      fraction: maxVisits == 0 ? 0 : item.visitCount / maxVisits,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  );
                },
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(top: topInset),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg, bg, bg.withOpacity(0)],
                    stops: const [0, .58, 1],
                  ),
                ),
                child: SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        _SiteUsageBackButton(
                          tooltip: appText('back'),
                          icon: AppIcons.arrowLeft,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appText('visited_sites'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppMaterialIcon(AppIcons.globe, color: muted, size: 14),
                              const SizedBox(width: 6),
                              Text('${stats.length}', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _VisitedSitesSearchBar(
                controller: _searchController,
                bottomInset: bottomInset,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_SiteStat> _computeSiteStats() {
    final byHost = <String, List<ActivityEntry>>{};
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      final host = Uri.tryParse(entry.url)?.host.toLowerCase();
      if (host == null || host.isEmpty) continue;
      byHost.putIfAbsent(host, () => <ActivityEntry>[]).add(entry);
    }

    final total = byHost.values.fold<int>(0, (sum, visits) => sum + visits.length);
    final stats = byHost.entries.map((group) {
      final visits = group.value;
      final times = visits.map((entry) => entry.timestamp).toList()..sort();
      return _SiteStat(
        host: group.key,
        title: visits.first.title,
        url: visits.first.url,
        visitCount: visits.length,
        percentOfTotal: total == 0 ? 0 : visits.length / total * 100,
        firstVisit: times.first,
        lastVisit: times.last,
        activeSpan: times.last.difference(times.first),
      );
    }).toList()
      ..sort((a, b) {
        final countOrder = b.visitCount.compareTo(a.visitCount);
        return countOrder != 0 ? countOrder : b.lastVisit.compareTo(a.lastVisit);
      });
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

String _formatVisitedSpan(Duration span) {
  if (span.inMinutes < 1) return appText('time_now');
  if (span.inHours < 1) return appText('time_minutes').replaceAll('{count}', span.inMinutes.toString());
  if (span.inDays < 1) return appText('time_hours').replaceAll('{count}', span.inHours.toString());
  return appText('time_days').replaceAll('{count}', span.inDays.toString());
}

class _SiteUsageTile extends StatelessWidget {
  const _SiteUsageTile({required this.item, required this.fraction, required this.borderRadius});
  final _SiteStat item;
  final double fraction;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final encoded = browserFaviconCache.forUrl('https://${item.host}');
    Widget favicon = AppMaterialIcon(AppIcons.globe, color: muted, size: 20);
    if (encoded != null) {
      try {
        favicon = Image.memory(
          base64Decode(encoded),
          width: 27,
          height: 27,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: muted, size: 20),
        );
      } catch (_) {}
    }

    return Material(
      color: settingsCardColor(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => openOrbitTab(context, item.url, title: item.title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(14)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(7), child: favicon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.trim().isEmpty ? item.host : item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(item.host, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      appText('visit_count').replaceAll('{count}', item.visitCount.toString()),
                      style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(Symbols.open_in_new_rounded, size: 17, color: muted),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: fraction.clamp(0.0, 1.0),
                  backgroundColor: pillColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _VisitedMeta(icon: AppIcons.calendar, label: '${item.firstVisit.day.toString().padLeft(2, '0')}/${item.firstVisit.month.toString().padLeft(2, '0')}/${item.firstVisit.year}'),
                  const SizedBox(width: 14),
                  _VisitedMeta(icon: AppIcons.clockCounterClockwise, label: _formatVisitedSpan(item.activeSpan)),
                  const Spacer(),
                  Text('${item.percentOfTotal.toStringAsFixed(0)}%', style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitedMeta extends StatelessWidget {
  const _VisitedMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppMaterialIcon(icon, size: 13, color: mutedText(context)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: mutedText(context), fontSize: 10.5)),
        ],
      );
}

class _VisitedSitesSearchBar extends StatelessWidget {
  const _VisitedSitesSearchBar({required this.controller, required this.bottomInset});
  final TextEditingController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withOpacity(0), bg, bg],
          stops: const [0, .45, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(23)),
          child: Row(
            children: [
              AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: appText('search_history'),
                    hintStyle: TextStyle(color: muted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  onPressed: controller.clear,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: AppMaterialIcon(AppIcons.x, color: muted, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteUsageBackButton extends StatelessWidget {
  const _SiteUsageBackButton({required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 42, height: 42,
              child: Center(child: AppMaterialIcon(icon, color: mutedText(context), size: 20)),
            ),
          ),
        ),
      );
}
