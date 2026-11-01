import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../browser_library.dart';
import '../models.dart';
import '../theme.dart';

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
  });

  final ValueChanged<BrowserTab> onSelectTab;
  final VoidCallback onClose;
  final VoidCallback onHome;
  final VoidCallback onNewTab;
  final VoidCallback onNewIncognitoTab;
  final VoidCallback onCloseAllTabs;
  final Map<String, GlobalKey> previewKeys;
  final Map<String, GlobalKey> cardKeys;

  @override
  State<TabsGridScreen> createState() => _TabsGridScreenState();
}

class _TabsGridScreenState extends State<TabsGridScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    tabsController.addListener(_onChanged);
    browserFaviconCache.addListener(_onChanged);
    for (final tab in tabsController.tabs) {
      if (tab.kind != TabKind.appScreen) unawaited(browserFaviconCache.fetchForUrl(tab.url));
    }
  }

  @override
  void dispose() {
    tabsController.removeListener(_onChanged);
    browserFaviconCache.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final live = tabsController.tabs.map((tab) => tab.id).toSet();
    _selectedIds.removeWhere((id) => !live.contains(id));
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
        widget.onNewTab();
        break;
      case 'select':
        _toggleSelectionMode();
        break;
      case 'close_all':
        _selectedIds.clear();
        setState(() => _selectionMode = false);
        widget.onCloseAllTabs();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplySoftDark : looplySoftLight;
    final text = mainText(context);
    final muted = mutedText(context);
    final tabs = tabsController.tabs;

    return Material(
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
                      // Voltar e Home partilham uma única cápsula contínua.
                      Material(
                        color: pillColor(context),
                        borderRadius: BorderRadius.circular(99),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                tooltip: 'Voltar',
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Symbols.arrow_back_rounded, size: 22, color: text),
                                onPressed: widget.onClose,
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                tooltip: 'Página inicial',
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Symbols.home_rounded, size: 20, color: text),
                                onPressed: widget.onHome,
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const Spacer(),
                      // Contador quadrado alinhado à direita, junto ao menu,
                      // em vez de ficar solto no centro da AppBar.
                      _TabsCountBadge(count: tabs.length, color: text),
                      const SizedBox(width: 6),
                      if (_selectionMode) ...[
                        IconButton(
                          tooltip: _selectedIds.isEmpty ? 'Seleciona separadores' : 'Eliminar selecionados',
                          visualDensity: VisualDensity.compact,
                          onPressed: _selectedIds.isEmpty ? null : _removeSelected,
                          icon: Icon(Symbols.delete_outline_rounded, color: _selectedIds.isEmpty ? muted : text),
                        ),
                        IconButton(
                          tooltip: 'Concluir seleção',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Symbols.check_rounded, color: text),
                          onPressed: _toggleSelectionMode,
                        ),
                      ] else
                        PopupMenuButton<String>(
                          tooltip: 'Mais opções',
                          icon: Icon(Symbols.more_vert_rounded, color: text, size: 23),
                          color: pillColor(context),
                          surfaceTintColor: Colors.transparent,
                          elevation: 9,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                          onSelected: _handleMenu,
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'incognito', child: _TabsMenuItem(icon: Symbols.visibility_off_rounded, label: 'Abrir separador anónimo')),
                            PopupMenuItem(value: 'new', child: _TabsMenuItem(icon: Symbols.add_rounded, label: 'Abrir novo separador')),
                            PopupMenuItem(value: 'select', child: _TabsMenuItem(icon: Symbols.checklist_rounded, label: 'Selecionar separadores')),
                            PopupMenuItem(value: 'close_all', child: _TabsMenuItem(icon: Symbols.delete_sweep_rounded, label: 'Eliminar todos os separadores')),
                          ],
                        ),
                    ],
                    ),
                  ),
                ),
                Expanded(
                  child: tabs.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Symbols.tab_rounded, size: 44, color: muted),
                            const SizedBox(height: 10),
                            Text('Nenhum separador aberto', style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                          ]),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 700 ? 3 : 2;
                            const horizontalPadding = 14.0;
                            const gap = 12.0;
                            const verticalPadding = 12.0;
                            final availableWidth = constraints.maxWidth - horizontalPadding * 2;
                            final cardWidth = (availableWidth - gap * (columns - 1)) / columns;
                            final cardHeight = cardWidth / .77;
                            final rows = (tabs.length / columns).ceil();
                            final contentHeight = verticalPadding * 2 + rows * cardHeight + (rows - 1) * gap;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 100),
                              child: SizedBox(
                                height: contentHeight,
                                width: constraints.maxWidth,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (var index = 0; index < tabs.length; index++)
                                      _positionedTab(
                                        context: context,
                                        tab: tabs[index],
                                        index: index,
                                        columns: columns,
                                        cardWidth: cardWidth,
                                        cardHeight: cardHeight,
                                        gap: gap,
                                        horizontalPadding: horizontalPadding,
                                        verticalPadding: verticalPadding,
                                        selected: _selectedIds.contains(tabs[index].id),
                                      ),
                                  ],
                                ),
                              ),
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
                tooltip: 'Novo separador',
                backgroundColor: accentColor(context),
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: widget.onNewTab,
                child: const Icon(Symbols.add_rounded, size: 27),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionedTab({
    required BuildContext context,
    required BrowserTab tab,
    required int index,
    required int columns,
    required double cardWidth,
    required double cardHeight,
    required double gap,
    required double horizontalPadding,
    required double verticalPadding,
    required bool selected,
  }) {
    final left = horizontalPadding + (index % columns) * (cardWidth + gap);
    final top = verticalPadding + (index ~/ columns) * (cardHeight + gap);
    final previewKey = widget.previewKeys.putIfAbsent(tab.id, GlobalKey.new);
    final cardKey = widget.cardKeys.putIfAbsent(tab.id, GlobalKey.new);

    Widget card({required bool forFeedback}) => TabGridCard(
      key: ValueKey('${tab.id}${forFeedback ? '-drag' : ''}'),
      tab: tab,
      previewKey: forFeedback ? GlobalKey() : previewKey,
      cardKey: forFeedback ? GlobalKey() : cardKey,
      selected: selected,
      selectionMode: _selectionMode,
      onTap: () => _openOrSelect(tab),
      onClose: tab.kind != TabKind.appScreen ? () => tabsController.closeTab(tab.id) : null,
    );

    Widget draggable = DragTarget<String>(
      onWillAcceptWithDetails: (details) => !_selectionMode && details.data != tab.id,
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
              width: cardWidth,
              height: cardHeight,
              child: Transform.scale(scale: .94, child: card(forFeedback: true)),
            ),
          ),
          childWhenDragging: Opacity(opacity: .25, child: card(forFeedback: false)),
          child: card(forFeedback: false),
        ),
      ),
    );

    return AnimatedPositioned(
      key: ValueKey('position-${tab.id}'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      left: left,
      top: top,
      width: cardWidth,
      height: cardHeight,
      child: draggable,
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
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(.88), width: 1.6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, height: 1),
        ),
      ),
    ),
  );
}

class _TabsMenuItem extends StatelessWidget {
  const _TabsMenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 19, color: mainText(context)),
    const SizedBox(width: 12),
    Text(label, style: TextStyle(color: mainText(context))),
  ]);
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
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplySoftLight;
    final muted = mutedText(context);
    final text = mainText(context);
    final isApp = tab.kind == TabKind.appScreen;
    final host = Uri.tryParse(tab.url)?.host ?? '';
    final label = isApp
        ? (tab.appScreenLabel ?? 'Looply')
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
                  Icon(tab.appScreenIcon ?? Symbols.apps_rounded, size: 17, color: muted)
                else
                  AnimatedBuilder(
                    animation: browserFaviconCache,
                    builder: (context, _) {
                      final encoded = browserFaviconCache.forUrl(tab.url);
                      if (encoded != null) {
                        try {
                          return Image.memory(base64Decode(encoded), width: 18, height: 18, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Symbols.public_rounded, color: muted, size: 17));
                        } catch (_) {}
                      }
                      return Icon(Symbols.public_rounded, color: muted, size: 17);
                    },
                  ),
                const SizedBox(width: 7),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600))),
                if (selectionMode)
                  Icon(selected ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded, color: selected ? accentColor(context) : muted, size: 20)
                else if (onClose != null)
                  SizedBox(
                    width: 28, height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Fechar aba',
                      style: IconButton.styleFrom(backgroundColor: pillColor(context), foregroundColor: muted),
                      icon: const Icon(Symbols.close_rounded, size: 15),
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
                        ? Image.memory(tab.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => Center(child: Icon(Symbols.public_rounded, size: 32, color: muted.withOpacity(.55))))
                        : Center(child: Icon(isApp ? (tab.appScreenIcon ?? Symbols.apps_rounded) : Symbols.public_rounded, size: 34, color: muted.withOpacity(.40))),
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
