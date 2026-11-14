import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:m3e_buttons/m3e_buttons.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';
import '../browser_library.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/looply_dialog.dart';
import '../localization.dart';
import '../widgets/material_symbols.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final Set<String> _selectedIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _searchActive = false;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    bookmarksController.addListener(_refresh);
    browserFaviconCache.addListener(_refresh);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    bookmarksController.removeListener(_refresh);
    browserFaviconCache.removeListener(_refresh);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final existing = bookmarksController.entries.map((entry) => entry.id).toSet();
    _selectedIds.removeWhere((id) => !existing.contains(id));
    setState(() {});
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  void _toggle(dynamic entry) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.add(entry.id)) _selectedIds.remove(entry.id);
    });
  }

  void _handleBack() {
    if (_isSelecting) {
      HapticFeedback.selectionClick();
      setState(_selectedIds.clear);
      return;
    }
    if (_searchActive) {
      _closeSearch();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openSearch() {
    if (_searchActive) return;
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchActive) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    if (mounted) {
      setState(() {
        _searchActive = false;
        _query = '';
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('delete_bookmarks_selected'),
      icon: AppIcons.trash,
      content: Text(appText('delete_bookmarks_count').replaceAll('{count}', _selectedIds.length.toString())),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('delete'), value: true, isDestructive: true),
      ],
    );
    if (confirmed != true || !mounted) return;
    final ids = _selectedIds.toList(growable: false);
    for (final id in ids) {
      bookmarksController.remove(id);
    }
    setState(_selectedIds.clear);
  }

  List<dynamic> get _filtered => bookmarksController.entries.where((entry) {
        if (_query.isEmpty) return true;
        return entry.title.toLowerCase().contains(_query) ||
            entry.url.toLowerCase().contains(_query);
      }).toList(growable: false);

  void _onEntryTap(dynamic entry) {
    if (_isSelecting) {
      _toggle(entry);
    } else {
      openOrbitTab(context, entry.url, title: entry.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = _filtered;
    final bg = pageBg(context);
    final selectedCount = _selectedIds.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope<void>(
      canPop: !_isSelecting && !_searchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
            _BookmarksSliverAppBar(
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppMaterialIcon(AppIcons.bookmarksSimple, size: 46, color: muted),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty ? appText('no_bookmarks') : appText('no_results'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: text, fontWeight: FontWeight.w600),
                      ),
                      if (_query.isEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          appText('bookmark_help'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                sliver: SliverM3ESegmentedList(
                    itemCount: entries.length,
                    color: settingsCardColor(context),
                    outerRadius: 22,
                    innerRadius: 8,
                    gap: 2,
                    onTap: (index) => _onEntryTap(entries[index]),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selected = _selectedIds.contains(entry.id);
                      final encoded = browserFaviconCache.forUrl(entry.url);
                      Widget favicon = AppMaterialIcon(AppIcons.globe, color: muted, size: 19);
                      if (encoded != null) {
                        try {
                          favicon = Image.memory(
                            base64Decode(encoded),
                            width: 21,
                            height: 21,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: muted, size: 19),
                          );
                        } catch (_) {}
                      }
                      return GestureDetector(
                        onLongPress: () => _toggle(entry),
                        child: M3EListItem(
                          leading: SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: selected ? 0 : 1,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: pillColor(context), shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: favicon,
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
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor(context)),
                                    child: const Icon(AppIcons.check, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          headline: Text(
                            entry.title.isNotEmpty ? entry.title : entry.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          supportingText: Text(
                            entry.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                          minHeight: 60,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      );
                    },
                  ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

// AppBar com o mesmo padrão de 3 estados do Histórico/Downloads: normal
// (voltar + título + lupa), seleção (fechar + "X selecionados" + lixeira)
// e busca (fechar + input expandido). O botão de lixeira NUNCA aparece
// fora do modo de seleção — some por completo em vez de ficar oculto por
// condição de lista vazia, e só surge quando _isSelecting é true.
class _BookmarksSliverAppBar extends StatelessWidget {
  const _BookmarksSliverAppBar({
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
      automaticallyImplyLeading: false,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      titleSpacing: 0,
      backgroundColor: bg,
      foregroundColor: text,
      surfaceTintColor: bg,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _BookmarksHeaderButton(
              key: ValueKey<String>(isSelecting ? 'close-selection' : 'back'),
              tooltip: isSelecting ? appText('close') : appText('back'),
              icon: isSelecting ? AppIcons.x : AppIcons.arrowLeft,
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
                    ? _BookmarksSearchField(
                        key: const ValueKey<String>('search-field'),
                        controller: searchController,
                        focusNode: searchFocusNode,
                      )
                    : Text(
                        isSelecting
                            ? appText('selected_count').replaceAll('{count}', selectedCount.toString())
                            : appText('bookmarks'),
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
              child: isSelecting
                  ? _BookmarksHeaderButton(
                      key: const ValueKey<String>('delete'),
                      tooltip: '${appText('delete')} ($selectedCount)',
                      icon: AppIcons.trash,
                      foreground: const Color(0xFFFF453A),
                      onTap: onDelete,
                    )
                  : _BookmarksHeaderButton(
                      key: ValueKey<String>(searchActive ? 'close-search' : 'search'),
                      tooltip: searchActive ? appText('close_search') : appText('search_hint'),
                      icon: searchActive ? AppIcons.x : AppIcons.magnifyingGlass,
                      onTap: searchActive ? onCloseSearch : onOpenSearch,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
class _BookmarksSearchField extends StatelessWidget {
  const _BookmarksSearchField({super.key, required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);

    return Transform.translate(
      offset: const Offset(0, 8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
              textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: text, fontSize: 14),
              cursorColor: accentColor(context),
                decoration: InputDecoration(
                  hintText: appText('search_hint'),
                  hintStyle: TextStyle(color: muted, fontSize: 13),
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
      ),
    );
  }
}

class _BookmarksHeaderButton extends StatelessWidget {
  const _BookmarksHeaderButton({super.key, required this.tooltip, required this.icon, required this.onTap, this.foreground});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        // shape: M3EButtonShape.round já produzia pílula perfeita (height/2
        // de raio); o problema de "não estar rounded" no botão de voltar
        // era borderRadius: 21 fixo competindo com fixedSize 42x42 — 21 é
        // exatamente metade de 42, então já estava correto, mas o
        // pressedRadius: 15 quebrava a redondeza plena durante o press.
        // Igualando pressedRadius a 21 garante pílula perfeita em todo
        // estado, inclusive pressionado.
        child: M3EButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: M3EButtonStyle.tonal,
          size: M3EButtonSize.sm,
          shape: M3EButtonShape.round,
          decoration: M3EButtonDecoration.styleFrom(
            backgroundColor: icon == AppIcons.arrowLeft ? Colors.transparent : pillColor(context),
            foregroundColor: foreground ?? mutedText(context),
            minimumSize: const Size(42, 42),
            fixedSize: const Size(42, 42),
            padding: EdgeInsets.zero,
            borderRadius: 21,
            pressedRadius: 21,
            motion: M3EMotion.expressiveSpatialDefault,
            haptic: M3EHapticFeedback.light,
          ),
          child: AppMaterialIcon(icon, color: foreground ?? mutedText(context), size: 20),
        ),
      );
}