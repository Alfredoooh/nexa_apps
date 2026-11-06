import 'package:flutter/material.dart';

import '../localization.dart';
import '../browser_library.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/phosphor_svg_icon.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() { super.initState(); downloadsController.addListener(_refresh); }
  @override
  void dispose() { downloadsController.removeListener(_refresh); super.dispose(); }
  void _refresh() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final entries = downloadsController.entries;
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: Text(appText('downloads')),
        actions: [
          if (entries.isNotEmpty)
            IconButton(tooltip: appText('clear_list'), icon: PhosphorSvgIcon(PhosphorIcons.trash, color: text), onPressed: downloadsController.clear),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              PhosphorSvgIcon(PhosphorIcons.downloadSimple, size: 48, color: muted),
              const SizedBox(height: 12),
              Text(appText('no_downloads'), style: TextStyle(color: text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(appText('downloads_intro'), style: TextStyle(color: muted, fontSize: 12)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Material(
                  color: settingsCardColor(context),
                  borderRadius: BorderRadius.circular(15),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openOrbitTab(context, entry.url, title: entry.filename),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: PhosphorSvgIcon(PhosphorIcons.downloadSimple, color: accentColor(context), size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(entry.mimeType?.isNotEmpty == true ? entry.mimeType! : entry.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('${appText('download_received')} · ${_date(entry.createdAt)}', style: TextStyle(color: muted, fontSize: 10)),
                        ])),
                        IconButton(tooltip: appText('remove'), onPressed: () => downloadsController.remove(entry.id), icon: PhosphorSvgIcon(PhosphorIcons.x, color: muted, size: 19)),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
