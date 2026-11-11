import 'dart:convert';

import 'package:flutter/material.dart';

import '../browser_library.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/looply_dialog.dart';
import '../localization.dart';
import '../widgets/svg_icon.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});
  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    bookmarksController.addListener(_refresh);
    browserFaviconCache.addListener(_refresh);
  }

  @override
  void dispose() {
    bookmarksController.removeListener(_refresh);
    browserFaviconCache.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final entries = bookmarksController.entries;
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: Text(appText('bookmarks')),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: appText('clear_bookmarks'),
              icon: AppSvgIcon(AppIcons.trash, color: text),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppSvgIcon(AppIcons.bookmarksSimple, size: 48, color: muted),
              const SizedBox(height: 12),
              Text(appText('no_bookmarks'), style: TextStyle(color: text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(appText('bookmark_help'), style: TextStyle(color: muted, fontSize: 12)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final iconData = browserFaviconCache.forUrl(entry.url);
                Widget leading = AppSvgIcon(AppIcons.globe, color: accentColor(context), size: 20);
                if (iconData != null) {
                  try {
                    leading = Image.memory(base64Decode(iconData), width: 23, height: 23, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => AppSvgIcon(AppIcons.globe, color: accentColor(context), size: 20));
                  } catch (_) {}
                }
                return Material(
                  color: settingsCardColor(context),
                  borderRadius: BorderRadius.circular(15),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openOrbitTab(context, entry.url, title: entry.title),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: Center(child: leading)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 11)),
                        ])),
                        IconButton(
                          tooltip: appText('remove'),
                          onPressed: () => bookmarksController.remove(entry.id),
                          icon: AppSvgIcon(AppIcons.x, color: muted, size: 20),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('clear_bookmarks_question'),
      icon: AppIcons.trash,
      message: appText('clear_bookmarks_confirm'),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('clear'), value: true, isDestructive: true),
      ],
    );
    if (confirmed == true) bookmarksController.clear();
  }
}
