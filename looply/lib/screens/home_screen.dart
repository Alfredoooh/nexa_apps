import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import 'all_sites_screen.dart';
import 'browser_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          children: [
            const LooplyBigSearchBox(),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Sites rápidos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
            ),
            const SizedBox(height: 14),
            const QuickSiteGridCard(),
            const SizedBox(height: 10),
            _ViewMoreSitesButton(),
            const SizedBox(height: 14),
            Text('Navegação simples, rápida e privada.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class LooplyBigSearchBox extends StatelessWidget {
  const LooplyBigSearchBox({super.key});
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Container(
      height: 54,
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        const SizedBox(width: 3),
        IconButton(
          tooltip: 'Abrir menu',
          style: IconButton.styleFrom(foregroundColor: muted, fixedSize: const Size(46, 46)),
          icon: const Icon(Icons.menu_rounded, size: 23),
          onPressed: () => showLooplyDrawer(context),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Pesquisar ou escrever um endereço',
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
              child: Align(alignment: Alignment.centerLeft, child: Text('Pesquisar ou escrever um URL', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 15))),
            ),
          ),
        ),
        const SizedBox(width: 15),
      ]),
    );
  }
}

class QuickSiteGridCard extends StatelessWidget {
  const QuickSiteGridCard({super.key});
  @override
  Widget build(BuildContext context) {
    final firstRow = quickSites.sublist(0, 5);
    final secondRow = quickSites.sublist(5, 10);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(28)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: firstRow.map((site) => QuickSiteTile(site: site)).toList()),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: secondRow.map((site) => QuickSiteTile(site: site)).toList()),
      ]),
    );
  }
}

class _ViewMoreSitesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllSitesScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Symbols.apps_rounded, color: text, size: 18),
            const SizedBox(width: 8),
            Text('Ver mais sites', style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// FIX: container aumentado de 50x50 para 56x56, padding reduzido de 2 para
// 1, para que o ícone .webp ocupe quase inteiramente a área circular
// visível — antes sobrava bastante espaço vazio em volta.
class QuickSiteTile extends StatelessWidget {
  const QuickSiteTile({super.key, required this.site});
  final QuickSite site;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    final circleBg = isDark ? looplyPanel2Dark : Colors.white;
    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openNewTab(context, site.url, title: site.name),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56, padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset(
                site.assetPath, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: text, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: text)),
        ]),
      ),
    );
  }
}

void openNewTab(BuildContext context, String url, {String? title}) {
  final tab = tabsController.createBrowserTab(url);
  tabsController.activate(tab.id);
  activityController.log(ActivityKind.site, title ?? url, url);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => BrowserScreen(tabId: tab.id, initialUrl: url)));
}