import 'package:flutter/material.dart';

import '../localization.dart';
import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;
import '../auth_service.dart';
import '../shell/shell_tab_request.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
                const SizedBox(height: 12),
                const RecentTabPreviewsCard(),
                const SizedBox(height: 14),
                Text(
                  appText('home_tagline'),
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

// Botão do drawer usa o SVG oficial do conjunto regular.
class _DrawerMenuButton extends StatelessWidget {
  const _DrawerMenuButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = mainText(context);
    return Semantics(
      button: true, label: appText('open_menu'),
      child: Material(
        color: Colors.transparent, shape: const CircleBorder(), clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(
            child: SvgPicture.asset(
              'assets/icons/svg/regular/menu-options.svg', width: 23, height: 23,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          )),
        ),
      ),
    );
  }
}

// Quatro sites distintos mais recentemente visitados, sem catálogo adicional.
class QuickSiteGridCard extends StatelessWidget {
  const QuickSiteGridCard({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: activityController,
    builder: (context, _) {
      final recent = <ActivityEntry>[];
      final hosts = <String>{};
      for (final entry in activityController.entries) {
        if (entry.kind != ActivityKind.site) continue;
        final host = Uri.tryParse(entry.url)?.host.toLowerCase() ?? '';
        if (host.isEmpty || !hosts.add(host)) continue;
        recent.add(entry);
        if (recent.length == 4) break;
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        decoration: BoxDecoration(color: settingsCardColor(context), borderRadius: BorderRadius.circular(17)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appText('recent_sites'), style: TextStyle(color: mainText(context), fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            SizedBox(height: 64, child: Center(child: Text(appText('no_recent_activity'), style: TextStyle(color: mutedText(context), fontSize: 12))))
          else
            Row(children: [
              for (final entry in recent) Expanded(child: _RecentSiteTile(entry: entry)),
              for (var i = recent.length; i < 4; i++) const Expanded(child: SizedBox()),
            ]),
        ]),
      );
    },
  );
}

class _RecentSiteTile extends StatelessWidget {
  const _RecentSiteTile({required this.entry});
  final ActivityEntry entry;
  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(entry.url)?.host ?? entry.url;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openNewTab(context, entry.url, title: entry.title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SiteFaviconForHome(url: entry.url),
          const SizedBox(height: 6),
          Text(host.replaceFirst(RegExp(r'^www\.'), ''), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: mainText(context), fontSize: 10.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class SiteFaviconForHome extends StatelessWidget {
  const SiteFaviconForHome({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Container(
      width: 39, height: 39, alignment: Alignment.center,
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(
        'https://www.google.com/s2/favicons?domain_url=${Uri.encodeComponent(url)}&sz=64',
        width: 23, height: 23, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, size: 20, color: muted),
      )),
    );
  }
}

// Pré-visualizações exclusivamente visuais das abas já abertas.
class RecentTabPreviewsCard extends StatelessWidget {
  const RecentTabPreviewsCard({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: tabsController,
    builder: (context, _) {
      final tabs = tabsController.tabs
          .where((tab) => tab.kind != TabKind.appScreen && !tab.isIncognito && tab.thumbnail != null)
          .toList()..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      final visible = tabs.take(5).toList();
      if (visible.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(color: settingsCardColor(context), borderRadius: BorderRadius.circular(17)),
        child: SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final tab = visible[index];
              return Material(
                color: pillColor(context), borderRadius: BorderRadius.circular(10), clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    tabsController.activate(tab.id);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    ShellTabRequest.instance.requestBrowser(tab.id);
                  },
                  child: SizedBox(width: 82, child: Image.memory(tab.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.low)),
                ),
              );
            },
          ),
        ),
      );
    },
  );
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

void openNewTab(BuildContext context, String url, {String? title}) {
  openOrbitTab(context, url, title: title);
}