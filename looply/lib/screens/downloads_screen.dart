import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../browser_library.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';

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
        title: const Text('Downloads'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(tooltip: 'Limpar lista', icon: Icon(Symbols.delete_sweep_rounded, color: text), onPressed: downloadsController.clear),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Symbols.download_rounded, size: 48, color: muted),
              const SizedBox(height: 12),
              Text('Nenhum download ainda', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('Os pedidos de transferência aparecem aqui.', style: TextStyle(color: muted, fontSize: 12)),
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
                        Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: Icon(Symbols.download_rounded, color: accentColor(context), size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(entry.mimeType?.isNotEmpty == true ? entry.mimeType! : entry.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('Pedido recebido · ${_date(entry.createdAt)}', style: TextStyle(color: muted, fontSize: 10)),
                        ])),
                        IconButton(tooltip: 'Remover', onPressed: () => downloadsController.remove(entry.id), icon: Icon(Symbols.close_rounded, color: muted, size: 19)),
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
