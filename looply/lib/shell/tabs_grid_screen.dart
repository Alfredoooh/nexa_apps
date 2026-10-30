import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';

class TabsGridScreen extends StatefulWidget {
  const TabsGridScreen({
    super.key,
    required this.onSelectTab,
    required this.onClose,
    required this.onNewTab,
    required this.previewKeys,
    required this.cardKeys,
  });
  final ValueChanged<BrowserTab> onSelectTab;
  final VoidCallback onClose;
  final VoidCallback onNewTab;
  final Map<String, GlobalKey> previewKeys;
  final Map<String, GlobalKey> cardKeys;
  @override
  State<TabsGridScreen> createState() => _TabsGridScreenState();
}

class _TabsGridScreenState extends State<TabsGridScreen> {
  @override
  void initState() {
    super.initState();
    tabsController.addListener(_onChanged);
  }
  @override
  void dispose() {
    tabsController.removeListener(_onChanged);
    super.dispose();
  }
  void _onChanged() { if (mounted) setState(() {}); }

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fechar separadores',
                    style: IconButton.styleFrom(backgroundColor: pillColor(context), foregroundColor: text, fixedSize: const Size(42, 42)),
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Separadores', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800)),
                    Text('${tabs.length} ${tabs.length == 1 ? 'aba aberta' : 'abas abertas'}', style: TextStyle(color: muted, fontSize: 12)),
                  ])),
                  IconButton(
                    tooltip: 'Nova aba',
                    style: IconButton.styleFrom(backgroundColor: accentColor(context), foregroundColor: isDark ? const Color(0xFF17181A) : Colors.white, fixedSize: const Size(46, 46)),
                    icon: const Icon(Symbols.add_rounded),
                    onPressed: widget.onNewTab,
                  ),
                ],
              ),
            ),
            Expanded(
              child: tabs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Symbols.tab_rounded, size: 44, color: muted), const SizedBox(height: 10), Text('Nenhuma aba aberta', style: TextStyle(color: text, fontWeight: FontWeight.w600))]))
                  : LayoutBuilder(builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
                        itemCount: tabs.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .77,
                        ),
                        itemBuilder: (context, index) {
                          final tab = tabs[index];
                          final previewKey = widget.previewKeys.putIfAbsent(tab.id, GlobalKey.new);
                          final cardKey = widget.cardKeys.putIfAbsent(tab.id, GlobalKey.new);
                          return RepaintBoundary(
                            key: cardKey,
                            child: TabGridCard(
                              tab: tab,
                              previewKey: previewKey,
                              onTap: () => widget.onSelectTab(tab),
                              onClose: tab.kind == TabKind.browser ? () => tabsController.closeTab(tab.id) : null,
                            ),
                          );
                        },
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

class TabGridCard extends StatelessWidget {
  const TabGridCard({
    super.key,
    required this.tab,
    required this.previewKey,
    required this.onTap,
    this.onClose,
  });
  final BrowserTab tab;
  final GlobalKey previewKey;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplySoftLight;
    final muted = mutedText(context);
    final text = mainText(context);
    final isApp = tab.kind == TabKind.appScreen;
    final host = Uri.tryParse(tab.url)?.host ?? '';
    final label = isApp ? (tab.appScreenLabel ?? 'Looply') : ((tab.title?.trim().isNotEmpty ?? false) ? tab.title! : (host.isEmpty ? tab.url : host));

    return Material(
      color: panel,
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
                  CachedNetworkImage(
                    imageUrl: 'https://www.google.com/s2/favicons?domain=$host&sz=64', width: 17, height: 17, fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => Icon(Symbols.public_rounded, color: muted, size: 17),
                    placeholder: (_, __) => const SizedBox.shrink(),
                  ),
                const SizedBox(width: 7),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600))),
                if (onClose != null)
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
                        ? Image.memory(tab.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => Center(child: Icon(Symbols.public_rounded, size: 32, color: muted.withOpacity(.55))))
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
