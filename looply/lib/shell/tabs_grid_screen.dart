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
    required this.onHome,
    required this.onNewTab,
    required this.previewKeys,
    required this.cardKeys,
  });
  final ValueChanged<BrowserTab> onSelectTab;
  final VoidCallback onClose;
  final VoidCallback onHome;
  final VoidCallback onNewTab;
  // Keys geridas pelo shell (main.dart), uma por id de aba. previewKeys
  // marca a área da thumbnail dentro do card (destino/origem do morph ao
  // abrir/fechar a grelha); cardKeys marca o card inteiro, usado como
  // alternativa quando a aba ainda não tem thumbnail renderizada.
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
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = mainText(context);
    final muted = mutedText(context);
    final tabs = tabsController.tabs;
    return Material(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
              child: Row(
                children: [
                  // Botão de voltar simples e totalmente circular, sem título.
                  IconButton(
                    tooltip: 'Voltar',
                    style: IconButton.styleFrom(
                      backgroundColor: pillColor(context),
                      foregroundColor: text,
                      fixedSize: const Size(46, 46),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Symbols.arrow_back_rounded, size: 23),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 12),
                  // Grupo compacto inspirado na barra da imagem: início e
                  // contador de separadores dentro de uma única cápsula.
                  Material(
                    color: pillColor(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Página inicial',
                            style: IconButton.styleFrom(
                              foregroundColor: text,
                              fixedSize: const Size(42, 42),
                              shape: const CircleBorder(),
                            ),
                            icon: const Icon(Symbols.home_rounded, size: 23),
                            onPressed: widget.onHome,
                          ),
                          const SizedBox(width: 2),
                          Container(
                            width: 52,
                            height: 42,
                            decoration: BoxDecoration(
                              color: panel,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(child: _TabsCountBadge(count: tabs.length, color: text)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Nova aba',
                    style: IconButton.styleFrom(
                      foregroundColor: text,
                      fixedSize: const Size(46, 46),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Symbols.add_rounded, size: 27),
                    onPressed: widget.onNewTab,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Mais opções',
                    icon: Icon(Symbols.more_vert_rounded, color: text, size: 24),
                    color: pillColor(context),
                    surfaceTintColor: Colors.transparent,
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    onSelected: (value) {
                      if (value == 'new') widget.onNewTab();
                      if (value == 'home') widget.onHome();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'new', child: _TabsMenuItem(icon: Symbols.add_rounded, label: 'Novo separador')),
                      PopupMenuItem(value: 'home', child: _TabsMenuItem(icon: Symbols.home_rounded, label: 'Página inicial')),
                    ],
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
                          // As keys são criadas/geridas pelo shell (main.dart);
                          // aqui só as reutilizamos se já existirem para esta
                          // aba, para não perder a referência entre rebuilds.
                          final previewKey = widget.previewKeys.putIfAbsent(tab.id, GlobalKey.new);
                          final cardKey = widget.cardKeys.putIfAbsent(tab.id, GlobalKey.new);
                          return TabGridCard(
                            key: ValueKey(tab.id),
                            tab: tab,
                            previewKey: previewKey,
                            cardKey: cardKey,
                            onTap: () => widget.onSelectTab(tab),
                            onClose: tab.kind != TabKind.appScreen ? () => tabsController.closeTab(tab.id) : null,
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


class _TabsCountBadge extends StatelessWidget {
  const _TabsCountBadge({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.tab_rounded, size: 17, color: color),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      );
}

class _TabsMenuItem extends StatelessWidget {
  const _TabsMenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: mainText(context)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: mainText(context))),
        ],
      );
}

class TabGridCard extends StatelessWidget {
  const TabGridCard({
    super.key,
    required this.tab,
    required this.onTap,
    required this.previewKey,
    required this.cardKey,
    this.onClose,
  });
  final BrowserTab tab;
  final VoidCallback onTap;
  // Key na área da thumbnail — Rect de origem/destino preferencial do morph.
  final GlobalKey previewKey;
  // Key no card inteiro — usado pelo shell como fallback quando o Rect da
  // thumbnail ainda não pôde ser medido (ex. card acabado de entrar na
  // árvore e ainda sem layout).
  final GlobalKey cardKey;
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
      key: cardKey,
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