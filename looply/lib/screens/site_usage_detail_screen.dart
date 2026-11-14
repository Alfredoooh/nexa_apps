import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';

import '../localization.dart';
import '../models.dart';
import '../browser_library.dart';
import '../theme.dart';
import '../shell/browser_navigation.dart';
import 'history_screen.dart';
import 'site_usage_detail_screen.dart';
import '../widgets/material_symbols.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _ChartRange { day, week, month, year }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ChartRange _range = _ChartRange.day;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    AdBlockStats.instance.addListener(_onChanged);
    _scrollController.addListener(_onScroll);
    for (final entry in activityController.entries) {
      if (entry.kind == ActivityKind.site) {
        unawaited(browserFaviconCache.fetchForUrl(entry.url));
      }
    }
    _prefetchVisitedSiteFavicons();
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    AdBlockStats.instance.removeListener(_onChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.hasClients ? _scrollController.offset.clamp(0.0, 100.0) : 0.0;
    if ((offset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = offset.toDouble());
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _prefetchVisitedSiteFavicons();
  }

  void _prefetchVisitedSiteFavicons() {
    final seen = <String>{};
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      final host = Uri.tryParse(entry.url)?.host.toLowerCase();
      if (host == null || host.isEmpty || !seen.add(host)) continue;
      unawaited(browserFaviconCache.fetchForUrl('https://$host'));
      if (seen.length >= 4) break;
    }
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
    final bg = pageBg(context);
    final entries = activityController.entries;
    final recent = entries.take(5).toList();
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(14, topInset + 60, 14, 24),
            children: [
              _RangeSelector(
                value: _range,
                onChanged: (value) => setState(() => _range = value),
              ),
              const SizedBox(height: 14),
              _AdBlockBarChart(data: _chartData, range: _range),
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
                  // "Ver tudo" agora é um M3EButton de verdade (estilo
                  // text, como o botão de abrir da tela de sites
                  // visitados), com squish/ripple de spring em vez do
                  // TextButton padrão do Flutter.
                  if (entries.isNotEmpty)
                    M3EButton.text(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
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
                      AppMaterialIcon(AppIcons.clockCounterClockwise, size: 38, color: muted),
                      const SizedBox(height: 9),
                      Text(
                        appText('no_recent_activity'),
                        style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                M3ESegmentedColumn(
                  color: settingsCardColor(context),
                  outerRadius: 22,
                  innerRadius: 8,
                  gap: 2,
                  padding: EdgeInsets.zero,
                  onTap: (index) {
                    final entry = recent[index];
                    openOrbitTab(context, entry.url, title: entry.title);
                  },
                  children: [
                    for (final entry in recent)
                      M3EListItem(
                        leading: SiteFaviconAvatar(url: entry.url, size: 38),
                        headline: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        supportingText: Text(
                          formatActivityTime(entry.timestamp),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        trailing: AppMaterialIcon(AppIcons.caretRight, color: muted, size: 19),
                        minHeight: 70,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ActivityAppBar(scrollProgress: _scrollOffset / 100.0),
          ),
        ],
      ),
    );
  }
}

class _ActivityAppBar extends StatelessWidget {
  const _ActivityAppBar({required this.scrollProgress});

  final double scrollProgress;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final topInset = MediaQuery.of(context).padding.top;
    final solidness = Curves.easeOut.transform(scrollProgress.clamp(0.0, 1.0));

    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg, bg.withOpacity(bg.opacity * solidness)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  appText('activity'),
                  style: TextStyle(
                    color: text,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final index = _ChartRange.values.indexOf(value);
    return M3ESegmentedRow(
      equalWidth: true,
      outerRadius: 999,
      innerRadius: 9,
      gap: 3,
      color: settingsCardColor(context),
      selectedColor: pillColor(context),
      selectedRadius: 999,
      selectedIndices: <int>{index},
      selectionMode: M3ESelectionMode.single,
      selectionTrigger: M3ESelectionTrigger.tap,
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(_ChartRange.values[selection.first]);
      },
      children: [
        for (final range in _ChartRange.values)
          M3EListItem(
            headline: Center(
              child: Text(
                _label(range),
                maxLines: 1,
                style: TextStyle(
                  color: range == value ? text : muted,
                  fontSize: 12.5,
                  fontWeight: range == value ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            minHeight: 42,
            contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
      ],
    );
  }
}

/// Gráfico de barras estilo Google Fit: cada barra tem cor interpolada
/// (Material red → amber → green) conforme a sua PRÓPRIA altura relativa
/// ao máximo do período, não uma cor fixa por posição. A barra mais alta
/// da semana ganha um ícone de check circular sobreposto no topo (como
/// as barras com check na referência), nas demais o topo fica só
/// colorido, sem check. Curvas e durações alongadas (easeOutQuint,
/// 520-900ms) para transições mais suaves do que a versão anterior.
class _AdBlockBarChart extends StatelessWidget {
  const _AdBlockBarChart({required this.data, required this.range});
  final List<MapEntry<String, int>> data;
  final _ChartRange range;

  // Interpola a cor Material conforme a fração (0.0 = vermelho, 0.5 =
  // âmbar, 1.0 = verde), usando os tons 500 das paletas Material
  // padrão do Flutter — não cores arbitrárias.
  Color _colorForFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    if (clamped <= 0.5) {
      final t = clamped / 0.5;
      return Color.lerp(Colors.red.shade500, Colors.amber.shade600, t)!;
    }
    final t = (clamped - 0.5) / 0.5;
    return Color.lerp(Colors.amber.shade600, Colors.green.shade500, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final maxValue = data.map((entry) => entry.value).fold<int>(0, (a, b) => a > b ? a : b);
    final highestIndex = () {
      var best = 0;
      for (var i = 1; i < data.length; i++) {
        if (data[i].value > data[best].value) best = i;
      }
      return best;
    }();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutQuint,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 196,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(data.length, (index) {
            final entry = data[index];
            final isHighlighted = index == highestIndex && maxValue > 0;
            final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
            final barHeight = 18.0 + (122.0 * fraction);
            final barColor = maxValue == 0 ? muted.withOpacity(.22) : _colorForFraction(fraction);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // O check circular fica fora do fluxo de altura da
                    // barra (Stack com clipBehavior.none), sobreposto no
                    // topo, só na barra mais alta — assim ele não altera
                    // a altura visual da cápsula em si.
                    TweenAnimationBuilder<double>(
                      key: ValueKey('$range-$index-$barHeight'),
                      tween: Tween<double>(begin: 0, end: barHeight),
                      duration: Duration(milliseconds: 760 + index * 60),
                      curve: Curves.easeOutQuint,
                      builder: (context, animatedHeight, _) => Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          TweenAnimationBuilder<Color?>(
                            tween: ColorTween(begin: barColor, end: barColor),
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeOutQuint,
                            builder: (context, animatedColor, __) => AnimatedContainer(
                              duration: const Duration(milliseconds: 520),
                              curve: Curves.easeOutQuint,
                              height: animatedHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: animatedColor ?? barColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          if (isHighlighted)
                            Positioned(
                              top: -12,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) => Transform.scale(
                                  scale: value.clamp(0.0, 1.15),
                                  child: child,
                                ),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: barColor,
                                    border: Border.all(color: settingsCardColor(context), width: 2),
                                  ),
                                  child: const Icon(Symbols.check_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutQuint,
                      style: TextStyle(
                        color: isHighlighted ? text : muted,
                        fontSize: 11.5,
                        fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                      ),
                      child: Text(entry.key),
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
              AppMaterialIcon(AppIcons.calendar, color: text, size: 19),
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
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 420 + index * 70),
                curve: Curves.easeOutQuint,
                builder: (context, entryValue, child) => Opacity(
                  opacity: entryValue,
                  child: Transform.translate(
                    offset: Offset(0, (1 - entryValue) * 10),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdayLabels[index],
                      style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      key: ValueKey(used),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 480),
                      curve: used ? Curves.elasticOut : Curves.easeOutQuint,
                      builder: (context, value, child) {
                        final scale = used ? (0.6 + 0.4 * value).clamp(0.0, 1.15) : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          begin: pillColor(context),
                          end: used ? accent : pillColor(context),
                        ),
                        duration: const Duration(milliseconds: 440),
                        curve: Curves.easeOutQuint,
                        builder: (context, color, _) => Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, animation) => ScaleTransition(
                              scale: animation,
                              child: FadeTransition(opacity: animation, child: child),
                            ),
                            child: used
                                ? const Icon(Symbols.check_rounded, key: ValueKey('check'), color: Colors.white, size: 18)
                                : const SizedBox.shrink(key: ValueKey('empty')),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Text(
              streak > 0
                  ? appText('streak_active').replaceAll('{count}', streak.toString())
                  : appText('streak_inactive'),
              key: ValueKey(streak > 0),
              style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

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

    const avatarSize = 34.0;
    const overlapStep = 8.0;

    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hosts.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SiteUsageDetailScreen()),
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: browserFaviconCache,
                builder: (context, _) {
                  return SizedBox(
                    width: hosts.isEmpty
                        ? avatarSize
                        : avatarSize + (hosts.length - 1) * overlapStep,
                    height: avatarSize,
                    child: hosts.isEmpty
                        ? Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                            child: Icon(Symbols.public_rounded, color: muted, size: 16),
                          )
                        : Stack(
                            children: List.generate(hosts.length, (index) {
                              final host = hosts[index];
                              final encoded = browserFaviconCache.forUrl('https://$host');
                              Widget icon = Icon(Symbols.public_rounded, color: accent, size: 14);
                              if (encoded != null) {
                                try {
                                  icon = ClipOval(
                                    child: Image.memory(
                                      base64Decode(encoded),
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Symbols.public_rounded, color: accent, size: 14),
                                    ),
                                  );
                                } catch (_) {}
                              }
                              return Positioned(
                                left: index * overlapStep,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(milliseconds: 360 + index * 80),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) => Transform.scale(
                                    scale: value.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                  child: Container(
                                    width: avatarSize,
                                    height: avatarSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: pillColor(context),
                                      border: Border.all(color: settingsCardColor(context), width: 2),
                                    ),
                                    child: Center(child: icon),
                                  ),
                                ),
                              );
                            }),
                          ),
                  );
                },
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
              Icon(Symbols.chevron_right_rounded, color: muted),
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
            SiteFaviconAvatar(url: entry.url, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(formatActivityTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            AppMaterialIcon(
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

class SiteFaviconAvatar extends StatelessWidget {
  const SiteFaviconAvatar({super.key, required this.url, this.size = 38});

  final String url;
  final double size;

  String _initialFor(String url) {
    final host = Uri.tryParse(url)?.host ?? url;
    final cleaned = host.startsWith('www.') ? host.substring(4) : host;
    return cleaned.isNotEmpty ? cleaned[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: browserFaviconCache,
      builder: (context, _) {
        final encoded = browserFaviconCache.forUrl(url);
        Widget? faviconImage;
        if (encoded != null) {
          try {
            faviconImage = Image.memory(
              base64Decode(encoded),
              width: size * 0.58,
              height: size * 0.58,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              gaplessPlayback: true,
            );
          } catch (_) {
            faviconImage = null;
          }
        }
        if (faviconImage == null) {
          unawaited(browserFaviconCache.fetchForUrl(url));
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fallbackBg = isDark ? Colors.white.withOpacity(.10) : Colors.black.withOpacity(.06);
        final fallbackFg = isDark ? Colors.white.withOpacity(.42) : Colors.black.withOpacity(.34);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: faviconImage != null
              ? Container(
                  key: const ValueKey('favicon'),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                  child: Center(child: faviconImage),
                )
              : Container(
                  key: ValueKey('initial-${_initialFor(url)}'),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: fallbackBg),
                  alignment: Alignment.center,
                  child: Text(
                    _initialFor(url),
                    style: TextStyle(
                      color: fallbackFg,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        );
      },
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