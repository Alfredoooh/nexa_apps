import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _searchActive = false;

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
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim().toLowerCase());
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
    if (mounted) setState(() => _searchActive = false);
  }

  List<dynamic> get _filtered => bookmarksController.entries.where((entry) {
        if (_query.isEmpty) return true;
        return entry.title.toLowerCase().contains(_query) ||
            entry.url.toLowerCase().contains(_query);
      }).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = _filtered;
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 6,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 230),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: _searchActive
              ? _BookmarksSearchField(
                  key: const ValueKey<String>('bookmarks-search-field'),
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                )
              : Text(
                  appText('bookmarks'),
                  key: const ValueKey<String>('bookmarks-title'),
                  style: TextStyle(color: text, fontWeight: FontWeight.w600),
                ),
        ),
        actions: [
          if (bookmarksController.entries.isNotEmpty && !_searchActive)
            M3EButton(
              tooltip: appText('clear_bookmarks'),
              onPressed: () => _confirmClear(context),
              style: M3EButtonStyle.tonal,
              size: M3EButtonSize.sm,
              shape: M3EButtonShape.round,
              decoration: M3EButtonDecoration.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: text,
                minimumSize: const Size(42, 42),
                fixedSize: const Size(42, 42),
                padding: EdgeInsets.zero,
                borderRadius: 21,
                pressedRadius: 15,
                motion: M3EMotion.expressiveSpatialDefault,
                haptic: M3EHapticFeedback.light,
              ),
              child: AppMaterialIcon(AppIcons.trash, color: text, size: 20),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 2),
            child: M3EButton(
              tooltip: _searchActive ? appText('close_search') : appText('search_hint'),
              onPressed: _searchActive ? _closeSearch : _openSearch,
              style: M3EButtonStyle.tonal,
              size: M3EButtonSize.sm,
              shape: M3EButtonShape.round,
              decoration: M3EButtonDecoration.styleFrom(
                backgroundColor: pillColor(context),
                foregroundColor: text,
                minimumSize: const Size(42, 42),
                fixedSize: const Size(42, 42),
                padding: EdgeInsets.zero,
                borderRadius: 21,
                pressedRadius: 15,
                motion: M3EMotion.expressiveSpatialDefault,
                haptic: M3EHapticFeedback.light,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                child: AppMaterialIcon(
                  _searchActive ? AppIcons.x : AppIcons.magnifyingGlass,
                  key: ValueKey<bool>(_searchActive),
                  color: text,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: topInset + kToolbarHeight + 8),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
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
                            Text(appText('bookmark_help'), textAlign: TextAlign.center,
                                style: TextStyle(color: muted, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  )
                : M3ESegmentedList.builder(
                    itemCount: entries.length,
                    listPadding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                    color: settingsCardColor(context),
                    outerRadius: 22,
                    innerRadius: 8,
                    gap: 3,
                    onTap: (index) {
                      final entry = entries[index];
                      openOrbitTab(context, entry.url, title: entry.title);
                    },
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final encoded = browserFaviconCache.forUrl(entry.url);
                      Widget favicon = AppMaterialIcon(AppIcons.globe, color: muted, size: 22);
                      if (encoded != null) {
                        try {
                          favicon = Image.memory(
                            base64Decode(encoded),
                            width: 25,
                            height: 25,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: muted, size: 22),
                          );
                        } catch (_) {}
                      }
                      return M3EListItem(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: pillColor(context), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: favicon,
                        ),
                        headline: Text(
                          entry.title.isNotEmpty ? entry.title : entry.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        supportingText: Text(
                          entry.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.5),
                        ),
                        trailing: IconButton(
                          tooltip: appText('remove'),
                          onPressed: () => bookmarksController.remove(entry.id),
                          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                          icon: AppMaterialIcon(AppIcons.x, color: muted, size: 20),
                        ),
                        minHeight: 72,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('clear_bookmarks_question'),
      icon: AppIcons.trash,
      content: Text(appText('clear_bookmarks_confirm')),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('clear'), value: true, isDestructive: true),
      ],
    );
    if (confirmed == true) bookmarksController.clear();
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
    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(22),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
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
