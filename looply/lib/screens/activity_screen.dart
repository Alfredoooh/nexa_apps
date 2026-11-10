import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../localization.dart';
import '../models.dart';
import '../browser_library.dart';
import '../theme.dart';
import '../shell/browser_navigation.dart';
import 'history_screen.dart';
import 'site_usage_detail_screen.dart';
import '../widgets/svg_icon.dart';

enum _ChartRange { day, week, month, year }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ChartRange _range = _ChartRange.day;

  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    AdBlockStats.instance.addListener(_onChanged);
    for (final entry in activityController.entries) {
      if (entry.kind == ActivityKind.site) {
        unawaited(browserFaviconCache.fetchForUrl(entry.url));
      }
    }
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    AdBlockStats.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<MapEntry<String, int>> get _chartData {
    final stats = AdBlockStats.instance;
    switch (_range) {
      case _ChartRange.day:
        return stats.dayView;
      case _ChartRange.week:
        return stats.weekView;
      case _ChartRange.month:
        return stats.monthView;
      case _ChartRange.year:
        return stats.yearView;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = activityController.entries;
    final recent = entries.take(5).toList();

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        centerTitle: true,
        title: Text(appText('activity')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          _RangeSelector(
            value: _range,
            onChanged: (value) => setState(() => _range = value),
          ),
          const SizedBox(height: 14),
          _AdBlockBarChart(data: _chartData),
          const SizedBox(height: 16),
          const _DayStreakCard(),
          const SizedBox(height: 20),
          const _VisitedSitesCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  appText('recent'),
                  style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                  child: Text(appText('view_all')),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  AppSvgIcon(AppIcons.clockCounterClockwise, size: 38, color: muted),
                  const SizedBox(height: 9),
                  Text(
                    appText('no_recent_activity'),
                    style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
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

/// Seletor de período (Day / Week / Month / Year), em cápsula arredondada.
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});
  final _ChartRange value;
  final ValueChanged<_ChartRange> onChanged;

  String _label(_ChartRange range) {
    switch (range) {
      case _ChartRange.day:
        return appText('range_day');
      case _ChartRange.week:
        return appText('range_week');
      case _ChartRange.month:
        return appText('range_month');
      case _ChartRange.year:
        return appText('range_year');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: _ChartRange.values.map((range) {
          final selected = range == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? pageBg(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  _label(range),
                  style: TextStyle(
                    color: selected ? text : muted,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Gráfico de barras com anúncios bloqueados por período, com bordas
/// totalmente arredondadas (estilo cápsula) em cada barra.
class _AdBlockBarChart extends StatelessWidget {
  const _AdBlockBarChart({required this.data});
  final List<MapEntry<String, int>> data;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final maxValue = data.map((entry) => entry.value).fold<int>(0, (a, b) => a > b ? a : b);
    final highestIndex = () {
      var best = 0;
      for (var i = 1; i < data.length; i++) {
        if (data[i].value > data[best].value) best = i;
      }
      return best;
    }();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 180,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(data.length, (index) {
            final entry = data[index];
            final isHighlighted = index == highestIndex && maxValue > 0;
            final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
            final barHeight = 18.0 + (122.0 * fraction);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: barHeight),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Container(
                        height: value,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isHighlighted ? accent : muted.withOpacity(.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: isHighlighted ? text : muted,
                        fontSize: 11.5,
                        fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Sequência de dias de uso da semana atual, com check animado nos dias em
/// que o Looply registou pelo menos uma visita a um site.
class _DayStreakCard extends StatefulWidget {
  const _DayStreakCard();
  @override
  State<_DayStreakCard> createState() => _DayStreakCardState();
}

class _DayStreakCardState extends State<_DayStreakCard> {
  static const _weekdayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final stats = AdBlockStats.instance;
    final usage = stats.currentWeekUsage;
    final streak = stats.currentStreak;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSvgIcon(AppIcons.calendar, color: text, size: 19),
              const SizedBox(width: 8),
              Text(
                appText('day_streak'),
                style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final used = usage[index];
              return Column(
                children: [
                  Text(
                    _weekdayLabels[index],
                    style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Container(
                      key: ValueKey(used),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: used ? accent : pillColor(context),
                      ),
                      child: used
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(
            streak > 0
                ? appText('streak_active').replaceAll('{count}', streak.toString())
                : appText('streak_inactive'),
            style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Favicons dos últimos sites visitados, empilhados em círculos sobrepostos
/// (estilo "avatares em pilha"). Ao tocar, navega para o detalhe de uso.
class _VisitedSitesCard extends StatelessWidget {
  const _VisitedSitesCard();

  List<String> _recentUniqueHosts(BuildContext context) {
    final seen = <String>{};
    final hosts = <String>[];
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      final host = Uri.tryParse(entry.url)?.host.toLowerCase();
      if (host == null || host.isEmpty || !seen.add(host)) continue;
      hosts.add(host);
      if (hosts.length >= 4) break;
    }
    return hosts;
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final hosts = _recentUniqueHosts(context);

    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hosts.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SiteUsageDetailScreen()),
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: hosts.isEmpty ? 38 : 24.0 + (hosts.length - 1) * 20.0 + 14.0,
                height: 38,
                child: hosts.isEmpty
                    ? Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                        child: Icon(Icons.public_rounded, color: muted, size: 18),
                      )
                    : Stack(
                        children: List.generate(hosts.length, (index) {
                          final host = hosts[index];
                          final encoded = browserFaviconCache.forUrl('https://$host');
                          Widget icon = Icon(Icons.public_rounded, color: accent, size: 16);
                          if (encoded != null) {
                            try {
                              icon = ClipOval(
                                child: Image.memory(
                                  base64Decode(encoded),
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: accent, size: 16),
                                ),
                              );
                            } catch (_) {}
                          }
                          return Positioned(
                            left: index * 20.0,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: pillColor(context),
                                border: Border.all(color: settingsCardColor(context), width: 2.5),
                              ),
                              child: Center(child: icon),
                            ),
                          );
                        }),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText('visited_sites'),
                      style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appText('visited_sites_subtitle'),
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry, this.borderRadius, this.selected = false, this.onTap, this.onLongPress});
  final ActivityEntry entry;
  final BorderRadius? borderRadius;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: selected ? accentColor(context).withOpacity(.13) : settingsCardColor(context),
      borderRadius: borderRadius ?? BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => openOrbitTab(context, entry.url, title: entry.title),
        onLongPress: onLongPress,
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            AnimatedBuilder(
              animation: browserFaviconCache,
              builder: (context, _) {
                final encoded = browserFaviconCache.forUrl(entry.url);
                Widget icon = AppSvgIcon(AppIcons.globe, color: accentColor(context), size: 19);
                if (encoded != null) {
                  try {
                    icon = Image.memory(
                      base64Decode(encoded),
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => AppSvgIcon(AppIcons.globe, color: accentColor(context), size: 19),
                    );
                  } catch (_) {}
                }
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                  child: Center(child: icon),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(formatActivityTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            AppSvgIcon(
              selected ? AppIcons.checkCircle : AppIcons.caretRight,
              color: selected ? accentColor(context) : muted,
              size: 19,
            ),
          ]),
        ),
      ),
    );
  }
}

String formatActivityTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return appText('time_now');
  if (diff.inMinutes < 60) return appText('time_minutes').replaceAll('{count}', diff.inMinutes.toString());
  if (diff.inHours < 24) return appText('time_hours').replaceAll('{count}', diff.inHours.toString());
  return appText('time_days').replaceAll('{count}', diff.inDays.toString());
}