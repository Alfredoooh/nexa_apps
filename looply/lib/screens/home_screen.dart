import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show TickerCanceled;
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import 'all_sites_screen.dart';
import 'browser_screen.dart';
import 'my_apps_screen.dart';
import 'search_screen.dart';
import 'wikipedia_browser_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.wikipediaViewportKey});

  final GlobalKey? wikipediaViewportKey;

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
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AllSitesScreen(wikipediaViewportKey: wikipediaViewportKey),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('Sites populares', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
                      const SizedBox(width: 5),
                      Icon(Symbols.chevron_right_rounded, size: 19, color: muted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            QuickSiteGridCard(wikipediaViewportKey: wikipediaViewportKey),
            const SizedBox(height: 10),
            const _MyAppsButton(),
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
  const QuickSiteGridCard({super.key, this.wikipediaViewportKey});

  final GlobalKey? wikipediaViewportKey;
  @override
  Widget build(BuildContext context) {
    final firstRow = quickSites.sublist(0, 5);
    final secondRow = quickSites.sublist(5, 10);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: firstRow.map((site) => QuickSiteTile(site: site, wikipediaViewportKey: wikipediaViewportKey)).toList()),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: secondRow.map((site) => QuickSiteTile(site: site, wikipediaViewportKey: wikipediaViewportKey)).toList()),
      ]),
    );
  }
}

class _MyAppsButton extends StatefulWidget {
  const _MyAppsButton();

  @override
  State<_MyAppsButton> createState() => _MyAppsButtonState();
}

class _MyAppsButtonState extends State<_MyAppsButton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _playLaunchShimmer();
  }

  Future<void> _playLaunchShimmer() async {
    for (var pass = 0; pass < 2; pass++) {
      if (!mounted) return;
      try {
        await _shimmerController.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
      if (pass == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 140));
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyAppsScreen()),
        ),
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, _) {
            final progress = _shimmerController.value;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(-1.8 + (progress * 3.6), 0),
                end: Alignment(-0.8 + (progress * 3.6), 0),
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(.26),
                  Colors.white.withOpacity(0),
                ],
                stops: const [0, .5, 1],
              ).createShader(bounds),
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
            );
          },
        ),
      ),
    );
  }
}

class QuickSiteTile extends StatelessWidget {
  const QuickSiteTile({super.key, required this.site, this.wikipediaViewportKey});
  final QuickSite site;
  final GlobalKey? wikipediaViewportKey;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    final circleBg = isDark ? looplyPanel2Dark : Colors.white;
    // A mesma GlobalKey do shell identifica o viewport desta WebView para
    // que a captura e a transformação de abas partam da própria Wikipédia.
    final isWikipediaTestTile = site.name == 'Wikipedia';
    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isWikipediaTestTile) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => WikipediaBrowserScreen(viewportKey: wikipediaViewportKey)));
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