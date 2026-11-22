import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

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
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
    _prefetchVisitedSiteFavicons();
  }

  // Prioriza os favicons dos domínios com mais visitas, e não apenas os
  // quatro primeiros registos cronológicos.
  void _prefetchVisitedSiteFavicons() {
    final counts = <String, int>{};
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      final host = Uri.tryParse(entry.url)?.host.toLowerCase();
      if (host == null || host.isEmpty) continue;
      counts.update(host, (count) => count + 1, ifAbsent: () => 1);
    }
    final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final host in ranked.take(6)) {
      unawaited(browserFaviconCache.fetchForUrl('https://${host.key}'));
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    final hasActivity = entries.isNotEmpty || AdBlockStats.instance.totalBlocked > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: bg,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: bg,
              systemNavigationBarIconBrightness: Brightness.light,
              systemNavigationBarDividerColor: bg,
              systemNavigationBarContrastEnforced: false,
                          )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: bg,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: bg,
              systemNavigationBarIconBrightness: Brightness.dark,
              systemNavigationBarDividerColor: bg,
              systemNavigationBarContrastEnforced: false,
                          ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          toolbarHeight: 64,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: appText('back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: AppMaterialIcon(AppIcons.arrowLeft, color: text, size: 24),
          ),
          backgroundColor: bg,
          foregroundColor: text,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 18,
          title: Text(appText('activity'),
              style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w600)),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: !hasActivity
              ? _ActivityEmptyState(dark: dark)
              : ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            _RangeSelector(value: _range, onChanged: (value) => setState(() => _range = value)),
            const SizedBox(height: 14),
            _AdBlockBarChart(data: _chartData, range: _range),
            const SizedBox(height: 16),
            const _DayStreakCard(),
            const SizedBox(height: 20),
            const _VisitedSitesCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(appText('recent'), style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800))),
                if (entries.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(CupertinoPageRoute<void>(builder: (_) => const HistoryScreen())),
                    child: Text(appText('view_all')),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(children: [
                  AppMaterialIcon(AppIcons.clockCounterClockwise, size: 38, color: muted),
                  const SizedBox(height: 9),
                  Text(appText('no_recent_activity'), style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                ]),
              )
            else
              ...List.generate(recent.length, (index) {
                final isFirst = index == 0;
                final isLast = index == recent.length - 1;
                return TweenAnimationBuilder<double>(
                  key: ValueKey('${recent[index].url}-${recent[index].timestamp.microsecondsSinceEpoch}'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 260 + index * 35),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(offset: Offset(0, (1 - value) * 8), child: child),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 3),
                    child: ActivityTile(
                      entry: recent[index],
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(isFirst ? 22 : 8),
                        bottom: Radius.circular(isLast ? 22 : 8),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
        ),
      ),
    );
  }
}


class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 220, child: Lottie.asset(
              dark
                  ? 'assets/animations/analytics-illustration-dark-lottie.json'
                  : 'assets/animations/analytics-illustration-light-lottie.json',
              repeat: false,
              fit: BoxFit.contain,
            )),
            const SizedBox(height: 8),
            Text('Ainda não há atividade', textAlign: TextAlign.center, style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Quando navegares e usares o BrowseIt, as tuas estatísticas e os sites visitados aparecerão aqui.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13.5, height: 1.45)),
          ]),
        ),
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
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutQuint,
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
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutQuint,
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
/// (chave por range para disparar uma nova animação do zero). Curva
/// trocada para easeOutQuint e durações alongadas para um motion mais
/// suave na subida das barras.
///
/// Ao tocar numa barra, um card flutua ancorado logo acima dela mostrando
/// o valor exato daquele período, usando CompositedTransformTarget (na
/// barra) + CompositedTransformFollower (no card, dentro de um
/// OverlayEntry) — a mesma técnica por trás de todo Tooltip/
/// PopupMenuButton nativo do próprio Flutter. O card fecha ao tocar em
/// qualquer lugar fora dele, ao tocar noutra barra, ou ao sair da tela.
class _AdBlockBarChart extends StatefulWidget {
  const _AdBlockBarChart({required this.data, required this.range});
  final List<MapEntry<String, int>> data;
  final _ChartRange range;

  @override
  State<_AdBlockBarChart> createState() => _AdBlockBarChartState();
}

class _AdBlockBarChartState extends State<_AdBlockBarChart> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int? _selectedIndex;
  Size _barSize = Size.zero;
  Offset _barOffset = Offset.zero;

  @override
  void didUpdateWidget(covariant _AdBlockBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Período mudou (ou os dados mudaram) enquanto o card estava aberto:
    // fecha, para não mostrar um valor de uma barra que já não existe
    // naquela posição.
    if (oldWidget.range != widget.range) {
      _closeCallout();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _closeCallout() {
    if (_selectedIndex == null) return;
    _removeOverlay();
    setState(() => _selectedIndex = null);
  }

  void _openCallout(int index, Offset barTopCenter, Size barSize) {
    _removeOverlay();
    setState(() {
      _selectedIndex = index;
      _barOffset = barTopCenter;
      _barSize = barSize;
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Captura qualquer toque fora do card para fechá-lo, sem
            // bloquear visualmente o resto da tela (totalmente
            // transparente).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeCallout,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -10),
              child: _BarCalloutCard(
                label: widget.data[index].key,
                value: widget.data[index].value,
                barWidth: _barSize.width,
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final maxValue = widget.data.map((entry) => entry.value).fold<int>(0, (a, b) => a > b ? a : b);
    final highestIndex = () {
      var best = 0;
      for (var i = 1; i < widget.data.length; i++) {
        if (widget.data[i].value > widget.data[best].value) best = i;
      }
      return best;
    }();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutQuint,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 180,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.data.length, (index) {
            final entry = widget.data[index];
            final isHighlighted = index == highestIndex && maxValue > 0;
            final isSelected = index == _selectedIndex;
            final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
            final barHeight = 18.0 + (122.0 * fraction);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_selectedIndex == index) {
                          _closeCallout();
                          return;
                        }
                        final renderBox = context.findRenderObject() as RenderBox;
                        final barRenderBox = _barKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
                        if (barRenderBox == null) return;
                        final topLeft = barRenderBox.localToGlobal(Offset.zero, ancestor: renderBox);
                        final barTopCenter = Offset(topLeft.dx + barRenderBox.size.width / 2, topLeft.dy);
                        _openCallout(index, barTopCenter, barRenderBox.size);
                      },
                      child: CompositedTransformTarget(
                        link: index == _selectedIndex ? _layerLink : LayerLink(),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('${widget.range}-$index-$barHeight'),
                          tween: Tween<double>(begin: 0, end: barHeight),
                          duration: Duration(milliseconds: 680 + index * 45),
                          curve: Curves.easeOutQuint,
                          builder: (context, value, _) => AnimatedContainer(
                            key: _barKeys.putIfAbsent(index, () => GlobalKey()),
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutQuint,
                            height: value,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : (isHighlighted ? accent : muted.withOpacity(.22)),
                              borderRadius: BorderRadius.circular(999),
                              border: isSelected
                                  ? Border.all(color: text.withOpacity(.25), width: 2)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutQuint,
                      style: TextStyle(
                        color: (isHighlighted || isSelected) ? text : muted,
                        fontSize: 11.5,
                        fontWeight: (isHighlighted || isSelected) ? FontWeight.w800 : FontWeight.w600,
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

  // Um GlobalKey por barra, para medir sua posição/tamanho exatos no
  // momento do tap (necessário porque a altura da barra é animada e o
  // RenderBox só existe depois de construído).
  final Map<int, GlobalKey> _barKeys = <int, GlobalKey>{};
}

/// Card ancorado mostrado ao tocar numa barra: fundo sólido, cantos
/// arredondados, sombra leve, mostrando o rótulo do período e o valor
/// exato. Largura mínima de 72 para não ficar espremido em barras finas.
class _BarCalloutCard extends StatelessWidget {
  const _BarCalloutCard({required this.label, required this.value, required this.barWidth});

  final String label;
  final int value;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Opacity(
        opacity: scale.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale.clamp(0.0, 1.0),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(minWidth: barWidth.clamp(72, 140)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: settingsCardColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                                ? const Icon(Symbols.check_rounded, key: ValueKey('check'), color: Colors.white, size: 24, weight: 400, opticalSize: 24)
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

/// Resumo visual dos domínios mais visitados. Os favicons formam uma fila
/// sobreposta de círculos, como no cartão de referência, em vez de ícones
/// separados por espaços largos.
class _VisitedSitesCard extends StatelessWidget {
  const _VisitedSitesCard();

  List<String> _recentUniqueHosts() {
    final counts = <String, int>{};
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      final host = Uri.tryParse(entry.url)?.host.toLowerCase();
      if (host == null || host.isEmpty) continue;
      counts.update(host, (count) => count + 1, ifAbsent: () => 1);
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(3).map((entry) => entry.key).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final hosts = _recentUniqueHosts();
    final visibleCount = hosts.isEmpty ? 1 : hosts.length;
    final stackWidth = 42.0 + ((visibleCount - 1) * 27.0);

    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hosts.isEmpty
            ? null
            : () => Navigator.of(context).push<void>(
                  CupertinoPageRoute<void>(builder: (_) => const SiteUsageDetailScreen()),
                ),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: browserFaviconCache,
                builder: (context, _) => SizedBox(
                  width: stackWidth,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (hosts.isEmpty)
                        Positioned(
                          left: 0,
                          top: 1,
                          child: _VisitedSiteFavicon(fallbackColor: muted),
                        )
                      else
                        for (var index = 0; index < hosts.length; index++)
                          Positioned(
                            left: index * 27.0,
                            top: 1,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: settingsCardColor(context),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: SiteFaviconAvatar(
                                  url: 'https://${hosts[index]}',
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
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
                    const SizedBox(height: 3),
                    Text(
                      appText('visited_sites_subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              AppMaterialIcon(AppIcons.caretRight, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitedSiteFavicon extends StatelessWidget {
  const _VisitedSiteFavicon({required this.fallbackColor});

  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pillColor(context),
        shape: BoxShape.circle,
      ),
      child: AppMaterialIcon(AppIcons.globe, color: fallbackColor, size: 22),
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