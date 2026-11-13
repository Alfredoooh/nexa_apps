import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';
import 'package:m3e_progress_indicator/m3e_progress_indicator.dart';
import 'package:m3e_buttons/m3e_buttons.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    activityController.addListener(_refresh);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_refresh);
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (mounted) setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus && !_searchActive) {
      setState(() => _searchActive = true);
    }
  }

  void _handleBack() {
    if (_searchActive) {
      _closeSearch();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openSearch() {
    setState(() => _searchActive = true);
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchActive = false;
      _query = '';
    });
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

    return PopScope<void>(
      canPop: !_searchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                    padding: EdgeInsets.fromLTRB(26, topInset + 78, 26, bottomInset + 24),
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
                ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(14, topInset + 72, 14, bottomInset + 24),
                  children: [
                    // M3ESegmentedColumn resolve sozinho os raios do
                    // primeiro/último item (outerRadius) e dos itens do
                    // meio (innerRadius), seguindo o padrão M3 Expressive
                    // de "cards segmentados" — sem cálculo manual de
                    // BorderRadius por índice.
                    M3ESegmentedColumn(
                      outerRadius: 22,
                      innerRadius: 8,
                      gap: 2,
                      color: settingsCardColor(context),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      onTap: (index) => openOrbitTab(context, stats[index].url, title: stats[index].title),
                      children: [
                        for (final item in stats)
                          _SiteUsageItemContent(
                            item: item,
                            fraction: maxVisits == 0 ? 0 : item.visitCount / maxVisits,
                            onOpen: () => openOrbitTab(context, item.url, title: item.title),
                          ),
                      ],
                    ),
                  ],
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SiteUsageFadeAppBar(
                  topInset: topInset,
                  searchActive: _searchActive,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onBack: _handleBack,
                  onOpenSearch: _openSearch,
                ),
              ),
            ],
          ),
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

// AppBar com o mesmo padrão de dois estados usado em Histórico/Downloads:
// normal (título + voltar) e busca (input expandido no lugar do título).
// Esta tela não tem modo de seleção, então não existe terceiro estado.
// A contagem de sites que antes aparecia como pílula no canto direito foi
// removida, como pedido.
class _SiteUsageFadeAppBar extends StatelessWidget {
  const _SiteUsageFadeAppBar({
    required this.topInset,
    required this.searchActive,
    required this.searchController,
    required this.searchFocusNode,
    required this.onBack,
    required this.onOpenSearch,
  });

  final double topInset;
  final bool searchActive;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);

    return Container(
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
              _SiteUsageHeaderButton(
                key: ValueKey<String>(searchActive ? 'close' : 'back'),
                tooltip: searchActive ? appText('close') : appText('back'),
                icon: searchActive ? AppIcons.x : AppIcons.arrowLeft,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: searchActive
                      ? _SiteUsageSearchField(
                          key: const ValueKey<String>('search-field'),
                          controller: searchController,
                          focusNode: searchFocusNode,
                        )
                      : Text(
                          appText('visited_sites'),
                          key: const ValueKey<String>('title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: searchActive
                    ? const SizedBox(key: ValueKey<String>('empty'), width: 42, height: 42)
                    : _SiteUsageHeaderButton(
                        key: const ValueKey<String>('search'),
                        tooltip: appText('search_history'),
                        icon: AppIcons.magnifyingGlass,
                        onTap: onOpenSearch,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteUsageSearchField extends StatelessWidget {
  const _SiteUsageSearchField({super.key, required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: controller.clear,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AppMaterialIcon(AppIcons.x, color: muted, size: 15),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Conteúdo de cada item dentro do M3ESegmentedColumn. O card em si
// (fundo, raios, splash, onTap) é resolvido pelo M3ESegmentedItem
// interno do pacote; este widget só monta o conteúdo:
// - M3EListItem para favicon/título/host
// - M3EFilledButton.tonal (pílula xs) para a contagem de visitas,
//   substituindo o antigo Container estático — agora com spring squish
// - M3EButton estilo tonal, ícone apenas, para abrir o site
// - M3ELinearWavyProgressIndicator (ondulada) no lugar da barra reta,
//   para a proporção de visitas deste site frente ao mais visitado
class _SiteUsageItemContent extends StatelessWidget {
  const _SiteUsageItemContent({required this.item, required this.fraction, required this.onOpen});

  final _SiteStat item;
  final double fraction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        M3EListItem(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(borderRadius: BorderRadius.circular(7), child: favicon),
          ),
          headline: Text(
            item.title.trim().isEmpty ? item.host : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          supportingText: Text(
            item.host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 11.5),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pílula de contagem de visitas: antes era um Container
              // estático com texto; agora é um botão M3E de verdade,
              // com squish de spring ao toque (mesmo sem ação própria
              // além de propagar o toque do card, ele já dá a textura
              // tátil pedida).
              M3EFilledButton.tonal(
                onPressed: onOpen,
                size: M3EButtonSize.xs,
                shape: M3EButtonShape.round,
                child: Text(
                  appText('visit_count').replaceAll('{count}', item.visitCount.toString()),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 7),
              M3EButton(
                onPressed: onOpen,
                style: M3EButtonStyle.text,
                size: M3EButtonSize.xs,
                shape: M3EButtonShape.round,
                tooltip: appText('open'),
                child: Icon(Symbols.open_in_new_rounded, size: 17, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Indicador ondulado M3 Expressive no lugar da barra reta
        // anterior. A amplitude da onda acompanha o próprio valor do
        // progresso (mais visitas = onda mais viva), usando o parâmetro
        // amplitude do pacote em vez de um valor fixo.
        M3ELinearWavyProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          color: accent,
          backgroundColor: pillColor(context),
          strokeWidth: 3,
          trackStrokeWidth: 3,
          wavelength: 18,
          waveSpeed: 8,
          height: 10,
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

class _SiteUsageHeaderButton extends StatelessWidget {
  const _SiteUsageHeaderButton({super.key, required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: icon == AppIcons.arrowLeft ? Colors.transparent : pillColor(context),
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(child: AppMaterialIcon(icon, color: mutedText(context), size: 20)),
            ),
          ),
        ),
      );
}