import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: firstRow.map((site) => QuickSiteTile(site: site)).toList()),
        const SizedBox(height: 12),
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

class QuickSiteTile extends StatelessWidget {
  const QuickSiteTile({super.key, required this.site});
  final QuickSite site;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    final circleBg = isDark ? looplyPanel2Dark : Colors.white;
    // O tile "Wikipedia" continua especial (abre WikipediaBrowserScreen em
    // vez de BrowserScreen), mas agora passa pelo MESMO canal que o botão
    // "Abas" dentro dela usa para voltar: regista/reaproveita a aba via
    // tabsController.upsertWikipediaTab() e pede ao shell (main.dart) para
    // empurrar a rota dessa aba diretamente, via
    // ShellTabRequest.instance.requestTab(tab.id). Isto faz a tela Home
    // NUNCA ganhar o container/transform do sistema de abas aqui — quem
    // passa a ser "aba" com Rect/viewportKey válidos é a própria tela da
    // Wikipédia, exatamente como qualquer site aberto via openNewTab. A
    // Home só se torna aba quando o utilizador abre a grelha de
    // Separadores a partir da própria Home (fluxo inalterado).
    final isWikipediaTestTile = site.name == 'Wikipedia';
    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isWikipediaTestTile) {
            final existing = tabsController.getWikipediaTab();
            final tab = existing ?? tabsController.upsertWikipediaTab(null);
            tabsController.activate(tab.id);
            ShellTabRequest.instance.requestTab(tab.id);
            return;
          }
          openNewTab(context, site.url, title: site.name);
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: ClipOval(
              child: Transform.scale(
                scale: 1.12,
                child: Image.asset(
                  site.assetPath, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: text, size: 17),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: text)),
        ]),
      ),
    );
  }
}

// FIX: usa openBrowserRoute() (Duration.zero) em vez de MaterialPageRoute.
// É esta troca que elimina o flash cinzento — o ZoomPageTransitionsBuilder
// nativo do Android (usado por padrão em MaterialPageRoute) é o que expõe
// a janela de composição onde o InAppWebView ainda não está anexado.
void openNewTab(BuildContext context, String url, {String? title}) {
  final tab = tabsController.createBrowserTab(url);
  tabsController.activate(tab.id);
  activityController.log(ActivityKind.site, title ?? url, url);
  Navigator.of(context).push(openBrowserRoute(tabId: tab.id, initialUrl: url));
}