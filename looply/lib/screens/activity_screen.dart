import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

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
    final offset = _scrollController.hasClients ? _scrollController.offset.clamp(0.0, 24.0) : 0.0;
    if ((offset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = offset.toDouble());
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _prefetchVisitedSiteFavicons();
  }

  // Garante que os favicons dos hosts mostrados na pilha de "sites
  // visitados" já estão em cache antes de o card desenhar — sem isto, o
  // card nasce sempre com o fallback genérico mesmo quando o favicon já
  // foi visto noutra parte da app.
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
                  if (entries.isNotEmpty)
                    TextButton(
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
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(milliseconds: 320 + index * 45),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 14),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                      child: ActivityTile(
                        entry: recent[index],
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(top),
                          bottom: Radius.circular(bottom),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          // Appbar flutuante com o mesmo gradiente de esmaecimento usado em
          // HomeScreen/HistoryScreen: opaca no topo, transparente na base,
          // e com uma opacidade extra ligada ao scroll (fica mais sólida
          // assim que a lista começa a deslizar por baixo dela).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ActivityAppBar(scrollProgress: _scrollOffset / 24.0),
          ),
        ],
      ),
    );
  }
}

/// Appbar com título alinhado à esquerda, no mesmo estilo de peso/tamanho
/// da HomeScreen, com gradiente de esmaecimento por trás.
class _ActivityAppBar extends StatelessWidget {
  const _ActivityAppBar({required this.scrollProgress});

  final double scrollProgress;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final topInset = MediaQuery.of(context).padding.top;
    final solidness = scrollProgress.clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg, bg.withOpacity(0.55 + 0.45 * solidness).withOpacity(solidness == 0 ? 0.0 : bg.opacity)],
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

/// Seletor de período (Day / Week / Month / Year), em cápsula arredondada.
/// O indicador deslizante usa AnimatedPositioned sobre os rótulos fixos,
/// em vez de recriar o fundo a cada item — isto evita o "salto" e dá um
/// movimento contínuo de um item para o outro.
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / _ChartRange.values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: segmentWidth * index,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: pageBg(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: _ChartRange.values.map((range) {
                  final selected = range == value;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(range),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              color: selected ? text : muted,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                            child: Text(_label(range)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Gráfico de barras com anúncios bloqueados por período, com bordas
/// totalmente arredondadas (estilo cápsula) em cada barra. A troca de
/// período agora anima a altura E a cor de cada barra ao reconstruir
/// (chave por range para disparar uma nova animação do zero), em vez de
/// aparecer instantaneamente.
class _AdBlockBarChart extends StatelessWidget {
  const _AdBlockBarChart({required this.data, required this.range});
  final List<MapEntry<String, int>> data;
  final _ChartRange range;

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
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
                      key: ValueKey('$range-$index-$barHeight'),
                      tween: Tween<double>(begin: 0, end: barHeight),
                      duration: Duration(milliseconds: 560 + index * 35),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        height: value,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isHighlighted ? accent : muted.withOpacity(.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
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

/// Sequência de dias de uso da semana atual, com check animado nos dias em
/// que o Looply registou pelo menos uma visita a um site. O círculo agora
/// faz uma transição de cor suave (não só escala) e um leve "pop" elástico
/// ao marcar, em vez de só trocar de cor instantaneamente.
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
                  TweenAnimationBuilder<double>(
                    key: ValueKey(used),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: used ? Curves.elasticOut : Curves.easeOutCubic,
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
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      builder: (context, color, _) => Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) => ScaleTransition(
                            scale: animation,
                            child: FadeTransition(opacity: animation, child: child),
                          ),
                          child: used
                              ? const Icon(Icons.check_rounded, key: ValueKey('check'), color: Colors.white, size: 18)
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
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

/// Favicons dos últimos sites visitados, em pilha bem próxima (overlap
/// maior, como no exemplo de referência), com bordas 100% circulares em
/// todos os elementos — o avatar individual, a moldura entre eles e o
/// próprio card.
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

    // Overlap bem mais pronunciado (avatares quase a tocar-se, como na
    // referência) — cada avatar seguinte avança só 15px em vez de 20px
    // sobre um diâmetro de 34px, deixando pouco mais de metade visível.
    const avatarSize = 34.0;
    const overlapStep = 15.0;

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
                            child: Icon(Icons.public_rounded, color: muted, size: 16),
                          )
                        : Stack(
                            children: List.generate(hosts.length, (index) {
                              final host = hosts[index];
                              final encoded = browserFaviconCache.forUrl('https://$host');
                              Widget icon = Icon(Icons.public_rounded, color: accent, size: 14);
                              if (encoded != null) {
                                try {
                                  icon = ClipOval(
                                    child: Image.memory(
                                      base64Decode(encoded),
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: accent, size: 14),
                                    ),
                                  );
                                } catch (_) {}
                              }
                              return Positioned(
                                left: index * overlapStep,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: Duration(milliseconds: 280 + index * 60),
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
            SiteFaviconAvatar(url: entry.url, size: 38),
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

/// Avatar circular de favicon reutilizável: mostra o favicon em cache
/// quando disponível; caso contrário, um círculo cinza com a inicial do
/// host em cinza mais claro/escuro (consoante o tema), nunca o ícone de
/// globo genérico — isto deixa claro que aquele site específico não tem
/// favicon, em vez de parecer um estado de carregamento.
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