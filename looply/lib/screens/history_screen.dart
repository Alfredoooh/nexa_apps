import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../localization.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/material_symbols.dart';
import 'activity_screen.dart' show SiteFaviconAvatar;
import '../shell/browser_navigation.dart';
import 'package:material_symbols_icons/symbols.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<String> _selectedKeys = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _searchActive = false;

  bool get _isSelecting => _selectedKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final existing = activityController.entries.map(_key).toSet();
    _selectedKeys.removeWhere((key) => !existing.contains(key));
    setState(() {});
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus && !_searchActive) {
      setState(() => _searchActive = true);
    }
  }

  String _key(ActivityEntry entry) =>
      '${entry.kind.name}|${entry.url}|${entry.timestamp.microsecondsSinceEpoch}';

  void _toggle(ActivityEntry entry) {
    HapticFeedback.selectionClick();
    setState(() {
      final key = _key(entry);
      if (!_selectedKeys.add(key)) _selectedKeys.remove(key);
    });
  }

  void _handleBack() {
    if (_isSelecting) {
      HapticFeedback.selectionClick();
      setState(_selectedKeys.clear);
      return;
    }
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

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('delete_history_selected'),
      icon: AppIcons.trash,
      content: Text(appText('delete_history_count').replaceAll('{count}', _selectedKeys.length.toString())),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('delete'), value: true, isDestructive: true),
      ],
    );
    if (confirmed != true || !mounted) return;
    final selected = activityController.entries.where((entry) => _selectedKeys.contains(_key(entry))).toList();
    activityController.removeEntries(selected);
    setState(_selectedKeys.clear);
  }

  List<ActivityEntry> _filteredEntries() {
    final all = activityController.entries;
    if (_query.isEmpty) return all;
    return all.where((entry) {
      final title = entry.title.toLowerCase();
      final url = entry.url.toLowerCase();
      return title.contains(_query) || url.contains(_query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = _filteredEntries();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCount = _selectedKeys.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);

    return PopScope<void>(
      canPop: !_isSelecting && !_searchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
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
              _HistorySliverAppBar(
                isSelecting: _isSelecting,
                searchActive: _searchActive,
                selectedCount: selectedCount,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onBack: _handleBack,
                onOpenSearch: _openSearch,
                onCloseSearch: _closeSearch,
                onDelete: _deleteSelected,
              ),
              if (entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AppMaterialIcon(AppIcons.clockCounterClockwise, size: 48, color: muted),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty ? appText('no_history') : appText('no_results'),
                        style: TextStyle(color: text, fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset + 24),
                  sliver: SliverList.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isFirst = index == 0;
                      final isLast = index == entries.length - 1;
                      final previous = index > 0 ? entries[index - 1] : null;
                      final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
                      final previousDay = previous == null ? null : DateTime(previous.timestamp.year, previous.timestamp.month, previous.timestamp.day);
                      final showDay = previousDay == null || day != previousDay;
                      final groupFirst = isFirst || showDay;
                      final nextEntry = index < entries.length - 1 ? entries[index + 1] : null;
                      final nextDay = nextEntry == null
                          ? null
                          : DateTime(nextEntry.timestamp.year, nextEntry.timestamp.month, nextEntry.timestamp.day);
                      final groupLast = isLast || nextDay != day;
                      final card = _HistoryCard(
                        entry: entry,
                        selected: _selectedKeys.contains(_key(entry)),
                        onTap: () {
                          if (_isSelecting) {
                            _toggle(entry);
                          } else if (entry.kind == ActivityKind.site) {
                            openOrbitTab(context, entry.url, title: entry.title);
                          }
                        },
                        onLongPress: () => _toggle(entry),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(groupFirst ? 22 : 8),
                          bottom: Radius.circular(groupLast ? 22 : 8),
                        ),
                      );
                      return Padding(
                        padding: EdgeInsets.only(bottom: groupLast ? 0 : 2),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (showDay)
                            Padding(
                              padding: EdgeInsets.fromLTRB(4, isFirst ? 0 : 16, 4, 8),
                              child: Text(
                                '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
                                style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .2),
                              ),
                            ),
                          card,
                        ]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// AppBar M3 expressive padrão: título na posição padrão (sem transparência,
// sem surfaceTint, sem elevation ao rolar), e os botões (voltar/pesquisar/
// lixeira) são ícones puros, sem nenhum container circular por trás.
// Ao tocar em pesquisar, o campo de busca ocupa o título e já traz o botão
// de voltar embutido dentro dele, que ao ser tocado fecha a busca.
// AppBar M3 expressive padrão (ver nota em bookmarks_screen.dart).
class _HistorySliverAppBar extends StatelessWidget {
  const _HistorySliverAppBar({
    required this.isSelecting,
    required this.searchActive,
    required this.selectedCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.onBack,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.onDelete,
  });

  final bool isSelecting;
  final bool searchActive;
  final int selectedCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final VoidCallback onDelete;

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
      leading: searchActive
          ? null
          : _HistoryIconButton(
              tooltip: isSelecting ? appText('close') : appText('back'),
              icon: isSelecting ? AppIcons.x : AppIcons.arrowLeft,
              onTap: onBack,
            ),
      title: AnimatedSwitcher(
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
            ? _HistorySearchField(
                key: const ValueKey<String>('search-field'),
                controller: searchController,
                focusNode: searchFocusNode,
                onBack: onCloseSearch,
              )
            : Text(
                isSelecting
                    ? appText('selected_count').replaceAll('{count}', selectedCount.toString())
                    : appText('history'),
                key: const ValueKey<String>('title'),
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
                child: isSelecting
                    ? _HistoryIconButton(
                        key: const ValueKey<String>('delete'),
                        tooltip: '${appText('delete')} ($selectedCount)',
                        icon: AppIcons.trash,
                        foreground: const Color(0xFFFF453A),
                        onTap: onDelete,
                      )
                    : _HistoryIconButton(
                        key: const ValueKey<String>('search'),
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

// Campo de busca em formato de pílula comprida e fina, com o botão de
// voltar embutido DENTRO da própria pílula.
class _HistorySearchField extends StatelessWidget {
  const _HistorySearchField({
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
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _HistoryIconButton(
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

// Botão de ícone puro do appbar (fora da pílula de busca).
class _HistoryIconButton extends StatelessWidget {
  const _HistoryIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.foreground,
    this.size = 24,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? mainText(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: AppMaterialIcon(icon, color: color, size: size),
      splashRadius: 22,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        highlightColor: Colors.transparent,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.borderRadius,
  });

  final ActivityEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final isSite = entry.kind == ActivityKind.site;

    return Material(
      color: selected ? accent.withOpacity(.12) : settingsCardColor(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: selected ? 0 : 1,
                      child: isSite
                          ? SiteFaviconAvatar(url: entry.url, size: 38)
                          : Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                              child: AppMaterialIcon(
                                AppIcons.magnifyingGlass,
                                color: accent,
                                size: 18,
                              ),
                            ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Opacity(
                        opacity: value.clamp(0, 1),
                        child: Transform.scale(scale: value, child: child),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                        child: const Icon(Symbols.check_rounded, color: Colors.white, size: 24, weight: 400, opticalSize: 24),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title.trim().isNotEmpty ? entry.title : entry.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 14.2, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Symbols.open_in_new_rounded, size: 24, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}