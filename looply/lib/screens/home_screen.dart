import 'dart:convert';

import 'package:flutter/material.dart';

import '../localization.dart';
import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;
import '../auth_service.dart';
import 'all_sites_screen.dart';
import 'auth_screen.dart';
import '../widgets/material_symbols.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, topInset > 0 ? 68 : 72, 12, 28),
              children: [
                const SizedBox(height: 18),
                const QuickSiteGridCard(),
                const SizedBox(height: 14),
                Text(
                  'Navegação simples, rápida e privada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LooplyHomeAppBar(onOpenDrawer: onOpenDrawer),
          ),
        ],
      ),
    );
  }
}

// Barra superior: à esquerda, o botão do drawer (ícone de hambúrguer
// customizado, duas linhas só — a de cima mais longa que a de baixo).
// À direita, onde antes ficava o avatar de perfil, agora fica o botão
// de Entrar (compacto, sem ícone) — só aparece sem sessão ativa.
class LooplyHomeAppBar extends StatelessWidget {
  const LooplyHomeAppBar({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg, bg.withOpacity(0.0)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _DrawerMenuButton(
                onTap: onOpenDrawer ?? () => drawer_menu.showLooplyDrawer(context),
              ),
              const Spacer(),
              ValueListenableBuilder<LooplyUser?>(
                valueListenable: authController,
                builder: (context, user, _) => user == null
                    ? const _CompactSignInButton()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Botão do drawer: círculo com o mesmo tamanho/toque do antigo avatar,
// mas com um ícone próprio de duas linhas (sem usar AppIcons nem Symbols),
// desenhado via CustomPaint. Linha de cima mais longa que a de baixo.
class _DrawerMenuButton extends StatelessWidget {
  const _DrawerMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = mainText(context);
    return Semantics(
      button: true,
      label: appText('open_menu'),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 14,
                child: CustomPaint(
                  painter: _TwoLineMenuPainter(color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TwoLineMenuPainter extends CustomPainter {
  const _TwoLineMenuPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Linha de cima: comprimento total da largura disponível.
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, 0),
      paint,
    );

    // Linha de baixo: mais curta, centralizada, cerca de 62% da largura
    // da linha de cima.
    final bottomWidth = size.width * 0.62;
    final bottomStart = (size.width - bottomWidth) / 2;
    canvas.drawLine(
      Offset(bottomStart, size.height),
      Offset(bottomStart + bottomWidth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TwoLineMenuPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Linha única, deslizável horizontalmente, com bordas totalmente curvas
// (formato pill). Mostra todos os quickSites em sequência; ao arrastar,
// revela mais itens. O botão "Mais sites" é o último item dentro da
// mesma linha de rolagem, não um elemento separado fora dela.
class QuickSiteGridCard extends StatelessWidget {
  const QuickSiteGridCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final site in quickSites) QuickSiteTile(site: site),
          const _MoreSitesTile(),
        ],
      ),
    );
  }
}

class _MoreSitesTile extends StatelessWidget {
  const _MoreSitesTile();

  @override
  Widget build(BuildContext context) {
    final accent = accentColor(context);
    return Semantics(
      button: true,
      label: appText('more_sites'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AllSitesScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: CustomPaint(
            size: const Size(40, 40),
            painter: _DashedCirclePainter(color: accent),
            child: SizedBox(
              width: 40,
              height: 40,
              child: AppMaterialIcon(AppIcons.plus, size: 22, color: accent),
            ),
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

// Botão de Entrar compacto: sem ícone, sem largura cheia — encolhe ao
// conteúdo do texto. Fica no canto direito do appbar.
class _CompactSignInButton extends StatelessWidget {
  const _CompactSignInButton();

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(999),
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            appText('sign_in'),
            style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// Sem label (nome do site) embaixo do ícone — só o ícone, já que estes
// serão sites próprios da empresa exibidos direto na tela inicial.
class QuickSiteTile extends StatelessWidget {
  const QuickSiteTile({super.key, required this.site});
  final QuickSite site;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    final circleBg = isDark ? pillColor(context) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: GestureDetector(
        onTapDown: (_) => BrowserPreconnectHints.preconnect(site.url),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => openNewTab(context, site.url, title: site.name),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: ClipOval(
              child: Transform.scale(
                scale: 1.232,
                child: _siteIcon(site, text),
              ),
            ),
          ),
        ),
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
        errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: fallbackColor, size: 18),
      );
    } catch (_) {
      // Se um ícone importado ficar inválido, tenta o favicon do site.
    }
  }
  if (site.faviconUrl != null && site.faviconUrl!.isNotEmpty) {
    return Image.network(
      site.faviconUrl!,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: fallbackColor, size: 18),
    );
  }
  if (site.assetPath != null) {
    return Image.asset(
      site.assetPath!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, color: fallbackColor, size: 18),
    );
  }
  return AppMaterialIcon(AppIcons.globe, color: fallbackColor, size: 18);
}

void openNewTab(BuildContext context, String url, {String? title}) {
  openOrbitTab(context, url, title: title);
}