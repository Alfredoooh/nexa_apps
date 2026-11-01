import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../browser_library.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';

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
        backgroundColor: Colors.transparent,
        flexibleSpace: appBarSoftFade(context),
        title: const Text('Marcadores'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Limpar marcadores',
              icon: Icon(Symbols.delete_sweep_rounded, color: text),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Symbols.bookmarks_rounded, size: 48, color: muted),
              const SizedBox(height: 12),
              Text('Ainda não há marcadores', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('Guarda páginas pelo menu do Orbit Browser.', style: TextStyle(color: muted, fontSize: 12)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final iconData = browserFaviconCache.forUrl(entry.url);
                Widget leading = Icon(Symbols.public_rounded, color: accentColor(context), size: 20);
                if (iconData != null) {
                  try {
                    leading = Image.memory(base64Decode(iconData), width: 23, height: 23, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Symbols.public_rounded, color: accentColor(context), size: 20));
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
                          tooltip: 'Remover marcador',
                          onPressed: () => bookmarksController.remove(entry.id),
                          icon: Icon(Symbols.close_rounded, color: muted, size: 20),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar marcadores?'),
        content: const Text('Esta ação remove todos os marcadores guardados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (confirmed == true) bookmarksController.clear();
  }
}
