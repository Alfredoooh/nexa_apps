import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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
  String _query = '';

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
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim().toLowerCase());
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
        title: Text(appText('bookmarks'), style: TextStyle(color: text, fontWeight: FontWeight.w600)),
        actions: [
          if (bookmarksController.entries.isNotEmpty)
            IconButton(
              tooltip: appText('clear_bookmarks'),
              onPressed: () => _confirmClear(context),
              icon: AppMaterialIcon(AppIcons.trash, color: text, size: 21),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: topInset + kToolbarHeight + 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: pillColor(context),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: lineColor(context).withOpacity(.65)),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: text, fontSize: 14),
                cursorColor: accentColor(context),
                decoration: InputDecoration(
                  hintText: appText('search_hint'),
                  hintStyle: TextStyle(color: muted, fontSize: 13),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(13),
                    child: AppMaterialIcon(AppIcons.magnifyingGlass, size: 20, color: muted),
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: appText('close_search'),
                          onPressed: _searchController.clear,
                          icon: AppMaterialIcon(AppIcons.x, size: 18, color: muted),
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
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
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                      return Material(
                        color: settingsCardColor(context),
                        borderRadius: BorderRadius.circular(15),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => openOrbitTab(context, entry.url, title: entry.title),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: pillColor(context), shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: favicon,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.title.isNotEmpty ? entry.title : entry.url,
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: muted, fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: appText('remove'),
                                  onPressed: () => bookmarksController.remove(entry.id),
                                  icon: AppMaterialIcon(AppIcons.x, color: muted, size: 20),
                                  constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                                ),
                              ],
                            ),
                          ),
                        ),
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
