import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import 'all_sites_screen.dart';
import 'search_screen.dart';
import 'my_apps_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    // Mantém a estrutura de página original da Home (Scaffold + SafeArea).
    // O Drawer continua no Scaffold principal; o callback evita abrir um
    // Drawer interno e preserva o Container Transform de ecrã inteiro.
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          children: [
            LooplyBigSearchBox(onOpenDrawer: onOpenDrawer),
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
      ),
    );
  }

}

class LooplyBigSearchBox extends StatelessWidget {
  const LooplyBigSearchBox({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;
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
          onPressed: onOpenDrawer ?? () => showLooplyDrawer(context),
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
  static bool _hasPlayedThisLaunch = false;
  late final AnimationController _shimmerController;
  bool _isShimmerVisible = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    if (!_hasPlayedThisLaunch) {
      _hasPlayedThisLaunch = true;
      _isShimmerVisible = true;
      _shimmerController.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _isShimmerVisible = false);
        }
      });
      _shimmerController.forward();
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

    // Depois de terminar, devolve o botão sem ShaderMask. Assim o último
    // frame nunca fica congelado como um brilho permanente.
    if (!_isShimmerVisible) return button;
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
    final isOrbitBrowserShortcut = site.name == 'Wikipedia';
    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isOrbitBrowserShortcut) {
            openOrbitBrowserTab(context);
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
                // Aumenta apenas o conteúdo do círculo em 10%; o recipiente
                // continua rigorosamente com 40 x 40 px.
                scale: 1.232,
                child: _siteIcon(site, text),
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

Widget _siteIcon(QuickSite site, Color fallbackColor) {
  if (site.iconBase64 != null && site.iconBase64!.isNotEmpty) {
    try {
      return Image.memory(
        base64Decode(site.iconBase64!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: fallbackColor, size: 18),
      );
    } catch (_) {
      // Se um ícone importado ficar inválido, tenta o favicon do site.
    }
  }
  if (site.faviconUrl != null && site.faviconUrl!.isNotEmpty) {
    return Image.network(
      site.faviconUrl!,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: fallbackColor, size: 18),
    );
  }
  if (site.assetPath != null) {
    return Image.asset(
      site.assetPath!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(Icons.public_rounded, color: fallbackColor, size: 18),
    );
  }
  return Icon(Icons.public_rounded, color: fallbackColor, size: 18);
}

// Abre sites como páginas Orbit persistentes dentro do IndexedStack.
void openNewTab(BuildContext context, String url, {String? title}) {
  openOrbitTab(context, url, title: title);
}
