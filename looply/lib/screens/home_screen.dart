import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import 'all_sites_screen.dart';
import 'search_screen.dart';
import 'auth_screen.dart';
import '../auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    // Mantém a estrutura de página original da Home (Scaffold + SafeArea).
    // O drawer push/drag pertence ao shell; o callback evita criar um
    // drawer interno e preserva o Container Transform de ecrã inteiro.
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          children: [
            LooplyBigSearchBox(onOpenDrawer: onOpenDrawer),
            const SizedBox(height: 25),
            const SizedBox(height: 18),
            const QuickSiteGridCard(),
            const SizedBox(height: 10),
            ValueListenableBuilder<LooplyUser?>(
              valueListenable: authController,
              builder: (context, user, _) => user == null
                  ? const _LoginButton()
                  : const SizedBox.shrink(),
            ),
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
              onTap: () => Navigator.of(context).push<void>(CupertinoPageRoute<void>(builder: (_) => const SearchScreen())),
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
    final secondRow = quickSites.sublist(5);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: firstRow.map((site) => QuickSiteTile(site: site)).toList()),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ...secondRow.map((site) => QuickSiteTile(site: site)),
            const _MoreSitesTile(),
          ],
        ),
      ]),
    );
  }
}

class _MoreSitesTile extends StatelessWidget {
  const _MoreSitesTile();

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final accent = accentColor(context);
    return Semantics(
      button: true,
      label: 'Mais sites',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push<void>(
          CupertinoPageRoute<void>(builder: (_) => const AllSitesScreen()),
        ),
        child: SizedBox(
          width: 54,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(40, 40),
                painter: _DashedCirclePainter(color: accent),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Symbols.add_rounded, size: 22, color: accent),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Mais',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()..addOval(rect.deflate(1.3));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 4.2).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 7.2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => oldDelegate.color != color;
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 390),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ));
              return SlideTransition(position: slide, child: child);
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.login_rounded, color: text, size: 18),
              const SizedBox(width: 8),
              Text('Log in / Sign in', style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
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
    final circleBg = isDark ? pillColor(context) : Colors.white;
    final isOrbitBrowserShortcut = site.name == 'Wikipedia';
    return GestureDetector(
      onTapDown: (_) => BrowserPreconnectHints.preconnect(site.url),
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
          Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: text)),
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
