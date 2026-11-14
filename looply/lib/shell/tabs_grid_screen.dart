import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../localization.dart';
import '../browser_library.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/looply_popup.dart';
import '../widgets/material_symbols.dart';

class TabsGridScreen extends StatefulWidget {
  const TabsGridScreen({
    super.key,
    required this.onSelectTab,
    required this.onClose,
    required this.onHome,
    required this.onNewTab,
    required this.onNewIncognitoTab,
    required this.onCloseAllTabs,
    required this.previewKeys,
    required this.cardKeys,
    this.initialIncognitoMode = false,
    this.initialActiveTabId,
  });

  final ValueChanged<BrowserTab> onSelectTab;
  final VoidCallback onClose;
  final VoidCallback onHome;
  final VoidCallback onNewTab;
  final VoidCallback onNewIncognitoTab;
  final ValueChanged<bool> onCloseAllTabs;
  final Map<String, GlobalKey> previewKeys;
  final Map<String, GlobalKey> cardKeys;
  final bool initialIncognitoMode;
  final String? initialActiveTabId;

  @override
  State<TabsGridScreen> createState() => _TabsGridScreenState();
}

class _TabsGridScreenState extends State<TabsGridScreen> {
  bool _selectionMode = false;
  bool _showIncognitoTabs = false;
  bool _initialScrollScheduled = false;
  final ScrollController _gridScrollController = ScrollController();
  final Set<String> _selectedIds = <String>{};
  int _visibleTabsHash = 0;
  int _visibleTabsCount = -1;

  @override
  void initState() {
    super.initState();
    _showIncognitoTabs = widget.initialIncognitoMode;
    tabsController.addListener(_onChanged);
    // Favicons atualizam apenas o ícone de cada cartão (AnimatedBuilder local).
    // Evita reconstruir toda a grelha sempre que uma imagem chega da rede.
    if (!_showIncognitoTabs) {
      for (final tab in tabsController.tabs) {
        if (!tab.isIncognito && tab.kind != TabKind.appScreen) {
          unawaited(browserFaviconCache.fetchForUrl(tab.url));
        }
      }
    }
  }

  @override
  void dispose() {
    tabsController.removeListener(_onChanged);
    _gridScrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final visibleTabs = tabsController.tabs
        .where((tab) => tab.isIncognito == _showIncognitoTabs)
        .toList(growable: false);
    final liveIds = visibleTabs.map((tab) => tab.id).toSet();
    _selectedIds.removeWhere((id) => !liveIds.contains(id));

    // O ChangeNotifier também recebe atualizações de abas fora da vista atual.
    // Só reconstruímos a grelha se algum cartão visível realmente mudou.
    final nextHash = Object.hashAll(visibleTabs.map((tab) => Object.hash(
          tab.id,
          tab.url,
          tab.title,
          tab.thumbnail == null ? 0 : identityHashCode(tab.thumbnail!),
          tab.canGoBack,
          tab.canGoForward,
        )));
    if (visibleTabs.length == _visibleTabsCount && nextHash == _visibleTabsHash) {
      return;
    }
    _visibleTabsCount = visibleTabs.length;
    _visibleTabsHash = nextHash;
    setState(() {});
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _handleMenu(String action) {
    switch (action) {
      case 'incognito':
        widget.onNewIncognitoTab();
        break;
      case 'new':
        if (_showIncognitoTabs) {
          widget.onNewIncognitoTab();
        } else {
          widget.onNewTab();
        }
        break;
      case 'select':
        _toggleSelectionMode();
        break;
      case 'close_all':
        _selectedIds.clear();
        setState(() => _selectionMode = false);
        widget.onCloseAllTabs(_showIncognitoTabs);
        break;
    }
  }

  void _openOrSelect(BrowserTab tab) {
    if (_selectionMode) {
      setState(() {
        if (!_selectedIds.add(tab.id)) _selectedIds.remove(tab.id);
      });
    } else {
      widget.onSelectTab(tab);
    }
  }

  void _removeSelected() {
    if (_selectedIds.isEmpty) return;
    tabsController.closeTabs(_selectedIds.toList(growable: false));
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showIncognitoTabs) {
      return Theme(
        data: buildLooplyTheme(Brightness.dark),
        child: Builder(builder: _buildGrid),
      );
    }
    return _buildGrid(context);
  }

  Widget _buildGrid(BuildContext context) {
    final bg = softColor(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final tabs = tabsController.tabs
        .where((tab) => tab.isIncognito == _showIncognitoTabs)
        .toList(growable: false);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: bg,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
              systemNavigationBarColor: bg,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Material(
      color: bg,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  color: bg,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Row(
                    children: [
                      IconButton(
                        tooltip: appText('back'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
                        style: IconButton.styleFrom(
                          foregroundColor: text,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        icon: AppMaterialIcon(AppIcons.arrowLeft, size: 22, color: text),
                        onPressed: widget.onClose,
                      ),
                      IconButton(
                        tooltip: appText('home'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
                        style: IconButton.styleFrom(
                          foregroundColor: text,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                        icon: AppMaterialIcon(AppIcons.house, size: 20, color: text),
                        onPressed: widget.onHome,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: appText(_showIncognitoTabs ? 'normal_tabs' : 'incognito_tabs'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _showIncognitoTabs = !_showIncognitoTabs;
                          _initialScrollScheduled = false;
                          _visibleTabsHash = 0;
                          _visibleTabsCount = -1;
                          if (_gridScrollController.hasClients) {
                            _gridScrollController.jumpTo(0);
                          }
                          _selectedIds.clear();
                          _selectionMode = false;
                          if (!_showIncognitoTabs) {
                            for (final tab in tabsController.tabs) {
                              if (!tab.isIncognito && tab.kind != TabKind.appScreen) {
                                unawaited(browserFaviconCache.fetchForUrl(tab.url));
                              }
                            }
                          }
                        }),
                        icon: AppMaterialIcon(
                          AppIcons.incognito,
                          size: 22,
                          color: text,
                        ),
                      ),
                      const SizedBox(width: 2),
                      // O contador representa apenas o conjunto atualmente visível.
                      _TabsCountBadge(count: tabs.length, color: text),
                      const SizedBox(width: 6),
                      if (_selectionMode) ...[
                        IconButton(
                          tooltip: _selectedIds.isEmpty ? 'Seleciona separadores' : 'Eliminar selecionados',
                          visualDensity: VisualDensity.compact,
                          onPressed: _selectedIds.isEmpty ? null : _removeSelected,
                          icon: AppMaterialIcon(AppIcons.trash, color: _selectedIds.isEmpty ? muted : text),
                        ),
                        IconButton(
                          tooltip: appText('finish_selection'),
                          visualDensity: VisualDensity.compact,
                          icon: AppMaterialIcon(AppIcons.check, color: text),
                          onPressed: _toggleSelectionMode,
                        ),
                      ] else
                        LooplyPopupMenuButton<String>(
                          tooltip: appText('more_options'),
                          iconColor: text,
                          menuWidth: 286,
                          actions: <LooplyPopupAction<String>>[
                            LooplyPopupAction(value: 'incognito', icon: AppIcons.eyeSlash, label: appText('open_private_tab')),
                            LooplyPopupAction(value: 'new', icon: AppIcons.plus, label: appText('new_tab')),
                            LooplyPopupAction(value: 'select', icon: AppIcons.listChecks, label: appText('select_tabs')),
                            LooplyPopupAction(value: 'close_all', icon: AppIcons.trash, label: appText('close_all_tabs')),
                          ],
                          onSelected: _handleMenu,
                        ),
                    ],
                    ),
                  ),
                ),
                Expanded(
                  child: tabs.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            AppMaterialIcon(_showIncognitoTabs ? AppIcons.incognito : AppIcons.browser, size: 44, color: muted),
                            const SizedBox(height: 10),
                            Text(appText(_showIncognitoTabs ? 'no_private_tabs' : 'no_tabs'), style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                            if (_showIncognitoTabs) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 36),
                                child: Text(appText('private_mode_description'), textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
                              ),
                            ],
                          ]),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 700 ? 3 : 2;
                            const spacing = 12.0;
                            const horizontalPadding = 14.0;
                            final itemWidth = (constraints.maxWidth -
                                    horizontalPadding * 2 - spacing * (columns - 1)) /
                                columns;
                            final itemHeight = itemWidth / .77;
                            _scheduleInitialGridScroll(
                              tabs: tabs,
                              columns: columns,
                              itemExtent: itemHeight + spacing,
                            );
                            final tabIndexById = <String, int>{
                              for (var i = 0; i < tabs.length; i++) tabs[i].id: i,
                            };

                            return GridView.builder(
                              controller: _gridScrollController,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                              cacheExtent: 420,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                childAspectRatio: .77,
                              ),
                              itemCount: tabs.length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              findChildIndexCallback: (key) {
                                if (key is ValueKey<String>) {
                                  return tabIndexById[key.value];
                                }
                                return null;
                              },
                              itemBuilder: (context, index) {
                                final tab = tabs[index];
                                return KeyedSubtree(
                                  key: ValueKey<String>(tab.id),
                                  child: _tabGridItem(context, tab),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton(
                heroTag: 'looply-tabs-new-tab-fab',
                tooltip: appText(_showIncognitoTabs ? 'new_private_tab' : 'new_tab'),
                backgroundColor: _showIncognitoTabs ? Colors.white : looplyPrimary,
                foregroundColor: _showIncognitoTabs ? Colors.black : Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                onPressed: _showIncognitoTabs ? widget.onNewIncognitoTab : widget.onNewTab,
                child: AppMaterialIcon(AppIcons.plus, size: 27, color: _showIncognitoTabs ? Colors.black : Colors.white),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _scheduleInitialGridScroll({
    required List<BrowserTab> tabs,
    required int columns,
    required double itemExtent,
  }) {
    if (_initialScrollScheduled) return;
    _initialScrollScheduled = true;

    var targetIndex = -1;
    final preferredId = widget.initialActiveTabId;
    if (preferredId != null) {
      targetIndex = tabs.indexWhere((tab) => tab.id == preferredId);
    }
    // Ao alternar entre abas normais e privadas, mantém a grelha próxima da
    // aba mais recente daquele conjunto em vez de deixar a seleção fora de vista.
    if (targetIndex < 0 && preferredId != null && tabs.isNotEmpty) {
      targetIndex = tabs.length - 1;
    }
    if (targetIndex < 0) return;

    final targetOffset = (targetIndex ~/ columns) * itemExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_gridScrollController.hasClients) return;
      final max = _gridScrollController.position.maxScrollExtent;
      final offset = targetOffset.clamp(0.0, max).toDouble();
      if ((_gridScrollController.offset - offset).abs() > 1) {
        _gridScrollController.jumpTo(offset);
      }
    });
  }

  Widget _tabGridItem(BuildContext context, BrowserTab tab) {
    final previewKey = widget.previewKeys.putIfAbsent(tab.id, GlobalKey.new);
    final cardKey = widget.cardKeys.putIfAbsent(tab.id, GlobalKey.new);

    Widget card({required bool forFeedback}) => RepaintBoundary(
          child: TabGridCard(
            key: ValueKey('${tab.id}${forFeedback ? '-drag' : ''}'),
            tab: tab,
            previewKey: forFeedback ? GlobalKey() : previewKey,
            cardKey: forFeedback ? GlobalKey() : cardKey,
            selected: _selectedIds.contains(tab.id),
            selectionMode: _selectionMode,
            onTap: () => _openOrSelect(tab),
            onClose: tab.kind != TabKind.appScreen
                ? () => tabsController.closeTab(tab.id)
                : null,
          ),
        );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !_selectionMode && details.data != tab.id,
      onAcceptWithDetails: (details) {
        HapticFeedback.selectionClick();
        tabsController.reorderById(details.data, tab.id);
      },
      builder: (context, candidates, rejected) => _PressScale(
        child: LongPressDraggable<String>(
          data: tab.id,
          maxSimultaneousDrags: _selectionMode ? 0 : 1,
          hapticFeedbackOnStart: true,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 240,
              height: 312,
              child: Transform.scale(scale: .94, child: card(forFeedback: true)),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: .25,
            child: card(forFeedback: false),
          ),
          child: card(forFeedback: false),
        ),
      ),
    );
  }

}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});
  final Widget child;
  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  Timer? _pressTimer;
  bool _pressed = false;

  void _begin() {
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(milliseconds: 170), () {
      if (mounted) setState(() => _pressed = true);
    });
  }

  void _end() {
    _pressTimer?.cancel();
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _begin(),
    onPointerUp: (_) => _end(),
    onPointerCancel: (_) => _end(),
    child: AnimatedScale(
      scale: _pressed ? .94 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: widget.child,
    ),
  );
}

class _TabsCountBadge extends StatelessWidget {
  const _TabsCountBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.asset(
          'assets/icons/svg/regular/tabs-counter.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TabGridCard extends StatelessWidget {
  const TabGridCard({
    super.key,
    required this.tab,
    required this.onTap,
    required this.previewKey,
    required this.cardKey,
    this.onClose,
    this.selected = false,
    this.selectionMode = false,
  });

  final BrowserTab tab;
  final VoidCallback onTap;
  final GlobalKey previewKey;
  final GlobalKey cardKey;
  final VoidCallback? onClose;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = panelColor(context);
    final bg = softColor(context);
    final muted = mutedText(context);
    final text = mainText(context);
    final isApp = tab.kind == TabKind.appScreen;
    final host = Uri.tryParse(tab.url)?.host ?? '';
    final label = isApp
        ? (tab.appScreenLabel ?? 'BrowseIt')
        : ((tab.title?.trim().isNotEmpty ?? false) ? tab.title! : (host.isEmpty ? tab.url : host));

    return Material(
      key: cardKey,
      color: accentColor(context).withOpacity(.15),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 7),
              child: Row(children: [
                if (isApp)
                  AppMaterialIcon(tab.appScreenIcon ?? AppIcons.squaresFour, size: 17, color: muted)
                else if (tab.isIncognito)
                  AppMaterialIcon(AppIcons.incognito, size: 18, color: muted)
                else
                  AnimatedBuilder(
                    animation: browserFaviconCache,
                    builder: (context, _) {
                      final encoded = browserFaviconCache.forUrl(tab.url);
                      if (encoded != null) {
                        try {
                          return Image.memory(base64Decode(encoded), width: 18, height: 18, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: muted, size: 17));
                        } catch (_) {}
                      }
                      return AppMaterialIcon(AppIcons.globe, color: muted, size: 17);
                    },
                  ),
                const SizedBox(width: 7),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600))),
                if (selectionMode)
                  AppMaterialIcon(selected ? AppIcons.checkCircle : AppIcons.circle, color: selected ? accentColor(context) : muted, size: 20)
                else if (onClose != null)
                  SizedBox(
                    width: 28, height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: appText('close_tab'),
                      style: IconButton.styleFrom(backgroundColor: pillColor(context), foregroundColor: muted),
                      icon: const AppMaterialIcon(AppIcons.x, size: 15),
                      onPressed: onClose,
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ClipRRect(
                  key: previewKey,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: double.infinity,
                    color: bg,
                    child: tab.thumbnail != null
                        ? Image.memory(tab.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.low, cacheWidth: 520, cacheHeight: 760,
                            errorBuilder: (_, __, ___) => Center(child: AppMaterialIcon(AppIcons.globe, size: 32, color: muted.withOpacity(.55))))
                        : Center(child: AppMaterialIcon(isApp ? (tab.appScreenIcon ?? AppIcons.squaresFour) : AppIcons.globe, size: 34, color: muted.withOpacity(.40))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
