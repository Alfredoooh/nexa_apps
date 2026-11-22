import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';
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
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light, systemNavigationBarDividerColor: bg, systemNavigationBarContrastEnforced: false)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark, systemNavigationBarDividerColor: bg, systemNavigationBarContrastEnforced: false),
        child: Scaffold(
          backgroundColor: bg,
          body: SafeArea(
          top: false,
          bottom: true,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              _SiteUsageSliverAppBar(
                searchActive: _searchActive,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onBack: _handleBack,
                onOpenSearch: _openSearch,
              ),
              if (stats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(26, 0, 26, bottomInset + 24),
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
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset + 24),
                  sliver: SliverToBoxAdapter(
                    // Cartões segmentados M3E com conteúdo personalizado.
                    // A coluna controla os raios, o espaçamento, a superfície
                    // e a interação, enquanto cada linha preserva os detalhes
                    // de visitas e o indicador wavy.
                    child: M3ESegmentedColumn(
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
                  ),
                ),
            ],
          ),
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

// AppBar M3 expressive padrão, igual às telas de Histórico/Downloads/
// Favoritos: título na posição padrão, sem transparência/gradiente, e
// botões (voltar/pesquisar) como ícones puros, sem container circular.
// Esta tela não tem modo de seleção, então não existe terceiro estado.
class _SiteUsageSliverAppBar extends StatelessWidget {
  const _SiteUsageSliverAppBar({
    required this.searchActive,
    required this.searchController,
    required this.searchFocusNode,
    required this.onBack,
    required this.onOpenSearch,
  });

  final bool searchActive;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;

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
      titleSpacing: NavigationToolbar.kMiddleSpacing,
      backgroundColor: bg,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // Quando a busca está ativa, o campo de busca (com o voltar embutido)
      // toma conta de toda a largura do appbar, no lugar do leading+title.
      leading: searchActive
          ? null
          : _SiteUsageIconButton(
              tooltip: appText('back'),
              icon: AppIcons.arrowLeft,
              onTap: onBack,
            ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, axis: Axis.horizontal, axisAlignment: -1, child: child),
        ),
        child: searchActive
            ? _SiteUsageSearchField(
                key: const ValueKey<String>('site-usage-search-field'),
                controller: searchController,
                focusNode: searchFocusNode,
                onBack: onBack,
              )
            : Text(
                appText('visited_sites'),
                key: const ValueKey<String>('site-usage-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w500),
              ),
      ),
      actions: searchActive
          ? const []
          : [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _SiteUsageIconButton(
                  key: const ValueKey<String>('site-usage-search-action'),
                  tooltip: appText('search_history'),
                  icon: AppIcons.magnifyingGlass,
                  onTap: onOpenSearch,
                ),
              ),
              const SizedBox(width: 4),
            ],
    );
  }
}

// Campo de busca com o botão de voltar embutido dentro dele (ícone puro,
// sem container circular): seta à esquerda dentro do próprio input, texto
// ao lado, botão de limpar (x) quando há texto digitado.
class _SiteUsageSearchField extends StatelessWidget {
  const _SiteUsageSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 2, right: 12),
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          _SiteUsageIconButton(
            tooltip: appText('close_search'),
            icon: AppIcons.arrowLeft,
            size: 24,
            onTap: onBack,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(color: text, fontSize: 14),
              cursorColor: accentColor(context),
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
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: controller.clear,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: AppMaterialIcon(AppIcons.x, color: muted, size: 15),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Botão de ícone puro do appbar: sem container, sem círculo, sem fundo —
// apenas o ícone com feedback tátil e splash padrão de InkResponse.
class _SiteUsageIconButton extends StatelessWidget {
  const _SiteUsageIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.size = 24,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: AppMaterialIcon(icon, color: mainText(context), size: size),
      splashRadius: 22,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        highlightColor: Colors.transparent,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// Conteúdo personalizado de cada cartão da coluna segmentada M3E.
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
    Widget favicon = AppMaterialIcon(AppIcons.globe, color: muted, size: 24, weight: 400, opticalSize: 24);
    if (encoded != null) {
      try {
        favicon = Image.memory(
          base64Decode(encoded),
          width: 27,
          height: 27,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: muted, size: 24, weight: 400, opticalSize: 24),
        );
      } catch (_) {}
    }

    return Column(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title.trim().isEmpty ? item.host : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            M3EButton.tonal(
              onPressed: onOpen,
              size: M3EButtonSize.xs,
              shape: M3EButtonShape.round,
              child: Text(
                appText('visit_count').replaceAll('{count}', item.visitCount.toString()),
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            M3EButton.text(
              onPressed: onOpen,
              size: M3EButtonSize.xs,
              shape: M3EButtonShape.round,
              tooltip: appText('open'),
              child: Icon(Symbols.open_in_new_rounded, size: 24, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 4,
            color: accent,
            backgroundColor: pillColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _VisitedMeta(
              icon: AppIcons.calendar,
              label: '${item.firstVisit.day.toString().padLeft(2, '0')}/${item.firstVisit.month.toString().padLeft(2, '0')}/${item.firstVisit.year}',
            ),
            const SizedBox(width: 14),
            _VisitedMeta(icon: AppIcons.clockCounterClockwise, label: _formatVisitedSpan(item.activeSpan)),
            const Spacer(),
            Text(
              '${item.percentOfTotal.toStringAsFixed(0)}%',
              style: TextStyle(color: muted, fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
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