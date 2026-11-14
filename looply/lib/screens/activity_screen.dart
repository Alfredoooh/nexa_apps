import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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
    _prefetchVisitedSiteFavicons();
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    AdBlockStats.instance.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _ActivitySliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      outerRadius: 26,
                      innerRadius: 10,
                      gap: 3,
                      padding: EdgeInsets.zero,
                      onTap: (index) {
                        final entry = recent[index];
                        openOrbitTab(context, entry.url, title: entry.title);
                      },
                      children: [
                        for (final entry in recent)
                          M3EListItem(
                            leading: SiteFaviconAvatar(url: entry.url, size: 40),
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
                            minHeight: 72,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior sólida, alinhada ao AppBar definido no tema Looply.
class _ActivitySliverAppBar extends StatelessWidget {
  const _ActivitySliverAppBar();

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      primary: true,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      backgroundColor: bg,
      foregroundColor: text,
      surfaceTintColor: bg,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        appText('activity'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.2),
      ),
    );
  }
}
/// Seletor de período (Day / Week / Month / Year), em cápsula arredondada.
/// O indicador deslizante usa AnimatedPositioned sobre os rótulos fixos,
/// em vez de recriar o fundo a cada item — isto evita o "salto" e dá um
/// movimento contínuo de um item para o outro. Duração aumentada e curva
/// trocada para easeOutQuint: a desaceleração final fica mais longa e
/// macia do que o easeOutCubic anterior, lendo como um motion mais suave.
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

/// Gráfico de barras com anúncios bloqueados por período, com bordas
/// totalmente arredondadas (estilo cápsula) em cada barra. A troca de
/// período agora anima a altura E a cor de cada barra ao reconstruir
/// (chave por range para disparar uma nova animação do zero). Curva
/// trocada para easeOutQuint e durações alongadas para um motion mais
/// suave na subida das barras.
class _AdBlockBarChart extends StatelessWidget {
  const _AdBlockBarChart({required this.data, required this.range});

  final List<MapEntry<String, int>> data;
  final _ChartRange range;

  String _periodTitle() {
    switch (range) {
      case _ChartRange.day:
        return appText('last_7_days');
      case _ChartRange.week:
        return appText('last_7_weeks');
      case _ChartRange.month:
        return appText('last_7_months');
      case _ChartRange.year:
        return appText('last_5_years');
    }
  }

  String _formatAxisValue(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    return value.toString();
  }

  String _formatCount(int value) {
    final separator = appLanguageController.value.code == 'en' ? ',' : '.';
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => separator,
    );
  }

  String _averageLabel() {
    switch (range) {
      case _ChartRange.day:
        return appText('average_per_day');
      case _ChartRange.week:
        return appText('average_per_week');
      case _ChartRange.month:
        return appText('average_per_month');
      case _ChartRange.year:
        return appText('average_per_year');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final tertiary = Theme.of(context).colorScheme.tertiary;
    final total = data.fold<int>(0, (sum, entry) => sum + entry.value);
    final average = data.isEmpty ? 0 : (total / data.length).round();
    final maxValue = data.fold<int>(0, (current, entry) => current > entry.value ? current : entry.value);
    final scaleMax = maxValue == 0 ? 1 : maxValue + (maxValue * .18).ceil();
    final averageFraction = average / scaleMax;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AppMaterialIcon(AppIcons.shieldCheck, color: accent, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  appText('ad_blocker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppMaterialIcon(AppIcons.calendar, color: muted, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      _periodTitle(),
                      style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: average.toDouble()),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      _formatCount(value.round()),
                      style: TextStyle(
                        color: text,
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _averageLabel(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${_formatCount(total)} ${appText('blocked_ads_period')}',
            style: TextStyle(color: muted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: _ActivityChartGuidesPainter(
                                    guideColor: lineColor(context).withOpacity(.75),
                                    averageColor: tertiary.withOpacity(.72),
                                    averageFraction: averageFraction,
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var index = 0; index < data.length; index++)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 5),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: TweenAnimationBuilder<double>(
                                              key: ValueKey('${range.name}-$index-${data[index].value}'),
                                              tween: Tween<double>(
                                                begin: 0,
                                                end: maxValue == 0
                                                    ? 4.0
                                                    : (constraints.maxHeight * .88 * data[index].value / scaleMax)
                                                        .clamp(4.0, constraints.maxHeight * .88)
                                                        .toDouble(),
                                              ),
                                              duration: Duration(milliseconds: 520 + index * 55),
                                              curve: Curves.easeOutBack,
                                              builder: (context, height, _) {
                                                final aboveAverage = average > 0 && data[index].value >= average;
                                                final barColor = aboveAverage
                                                    ? tertiary
                                                    : accent.withOpacity(.48);
                                                return Container(
                                                  height: height,
                                                  width: 22,
                                                  decoration: BoxDecoration(
                                                    color: barColor,
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            for (final entry in data)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    entry.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final plotHeight = constraints.maxHeight - 28;
                      final avgTop = (plotHeight * (1 - averageFraction) - 7)
                          .clamp(0.0, plotHeight - 14)
                          .toDouble();
                      final middleTop = (plotHeight * .5 - 7).clamp(0.0, plotHeight - 14).toDouble();
                      final showMiddleLabel = (averageFraction - .5).abs() > .15;
                      return Stack(
                        children: [
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Text(_formatAxisValue(scaleMax), style: TextStyle(color: muted, fontSize: 10)),
                          ),
                          if (showMiddleLabel)
                            Positioned(
                              top: middleTop,
                              right: 0,
                              child: Text(_formatAxisValue(scaleMax ~/ 2), style: TextStyle(color: muted, fontSize: 10)),
                            ),
                          Positioned(
                            top: avgTop,
                            right: 0,
                            child: Text(_formatAxisValue(average), style: TextStyle(color: tertiary, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                          Positioned(
                            bottom: 20,
                            right: 0,
                            child: Text('0', style: TextStyle(color: muted, fontSize: 10)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: tertiary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(appText('above_average'), style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent.withOpacity(.48), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(appText('below_average'), style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityChartGuidesPainter extends CustomPainter {
  const _ActivityChartGuidesPainter({
    required this.guideColor,
    required this.averageColor,
    required this.averageFraction,
  });

  final Color guideColor;
  final Color averageColor;
  final double averageFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), guidePaint);
    }

    if (averageFraction > 0) {
      final averagePaint = Paint()
        ..color = averageColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final clampedFraction = averageFraction.clamp(0.0, 1.0).toDouble();
      final y = size.height * (1.0 - clampedFraction);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), averagePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityChartGuidesPainter oldDelegate) =>
      oldDelegate.guideColor != guideColor ||
      oldDelegate.averageColor != averageColor ||
      oldDelegate.averageFraction != averageFraction;
}
/// Sequência de dias de uso da semana atual, com check animado nos dias em
/// que o Looply registou pelo menos uma visita a um site. Além da
/// transição de cor/escala já existente ao marcar, os 7 círculos agora
/// entram com um stagger (fade + leve subida), atrasado por índice, igual
/// ao padrão já usado nos cartões de "Recentes" mais abaixo na mesma tela
/// — dá uma sensação de sequência sendo "desenhada" da esquerda para a
/// direita ao abrir o ecrã, em vez de aparecer tudo de uma vez.
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
                duration: Duration(milliseconds: 360 + index * 60),
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
                      duration: const Duration(milliseconds: 420),
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
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutQuint,
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

/// Favicons dos últimos sites visitados, em pilha bem próxima (overlap de
/// ~75%, só ~25% de cada avatar fica visível atrás do seguinte — estilo
/// "grupo de avatares" bem compacto), com bordas 100% circulares em todos
/// os elementos: o avatar individual, a moldura entre eles e o próprio
/// card (que usa borderRadius 999, ou seja, pílula/circular nas pontas).
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

    // Overlap bem mais apertado que antes: cada avatar seguinte avança só
    // 8px sobre um diâmetro de 34px — deixa cerca de 25% de cada círculo
    // visível, bem mais próximo de um grupo compacto do que a versão
    // anterior (15px de avanço, ~56% visível).
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
                                  duration: Duration(milliseconds: 320 + index * 70),
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