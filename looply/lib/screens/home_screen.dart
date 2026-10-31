import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import 'all_sites_screen.dart';
import 'wikipedia_browser_screen.dart';
import 'search_screen.dart';
import 'my_apps_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
        children: [
          const LooplyBigSearchBox(),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AllSitesScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  children: [
                    Text(
                      'Sites populares',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Symbols.arrow_forward_rounded,
                      color: muted,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const QuickSiteGridCard(),
          const SizedBox(height: 10),
          _ViewMoreSitesButton(),
          const SizedBox(height: 14),
          Text(
            'Navegação simples, rápida e privada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
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

class _ViewMoreSitesButton extends StatefulWidget {
  @override
  State<_ViewMoreSitesButton> createState() => _ViewMoreSitesButtonState();
}

class _ViewMoreSitesButtonState extends State<_ViewMoreSitesButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(count: 2);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final button = Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyAppsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.apps_rounded, color: text, size: 18),
              const SizedBox(width: 8),
              Text('My Apps', style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _shimmerController,
      child: button,
      builder: (context, child) {
        final progress = _shimmerController.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.2 + 2.4 * progress, -0.15),
            end: Alignment(-0.2 + 2.4 * progress, 0.15),
            colors: [
              Colors.transparent,
              Colors.white.withOpacity(.34),
              Colors.transparent,
            ],
            stops: const [0, .5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
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
    final isWikipediaTile = site.name == 'Wikipedia';
    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isWikipediaTile) {
            // A Wikipédia vive no IndexedStack da shell, tal como a Home.
            // Se o clique vier de Todos os sites, regressa primeiro à shell.
            Navigator.of(context).popUntil((route) => route.isFirst);
            ShellTabRequest.instance.requestWikipedia();
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