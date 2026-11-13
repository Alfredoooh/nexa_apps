import 'dart:ui' show Rect, Offset;

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

// Sites recentemente utilizados: conteúdo horizontal, sem título redundante.
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
            if (recent.length == 10) break;
          }
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: recent.isEmpty
                ? SizedBox(
                    height: 82,
                    child: Center(
                      child: Text(
                        appText('no_recent_activity'),
                        style: TextStyle(color: mutedText(context), fontSize: 12),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 99,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: recent.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 15),
                      itemBuilder: (context, index) => SizedBox(
                        width: 72,
                        child: _RecentSiteTile(entry: recent[index]),
                      ),
                    ),
                  ),
          );
        },
      );

class _RecentSiteTile extends StatelessWidget {
  const _RecentSiteTile({required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final host = (Uri.tryParse(entry.url)?.host ?? entry.url)
        .replaceFirst(RegExp(r'^www\.'), '');
    final title = entry.title.trim();
    final hostLabel = host.split('.').first;
    final label = title.isNotEmpty && title.length <= 22 ? title : hostLabel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openNewTab(context, entry.url, title: entry.title),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SiteFaviconForHome(url: entry.url),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedText(context),
                fontSize: 11.2,
                fontWeight: FontWeight.w400,
                height: 1.15,
              ),
            ),
          ],
        ),
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
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pillColor(context),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF303236)
              : Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Image.network(
          'https://www.google.com/s2/favicons?domain_url=${Uri.encodeComponent(url)}&sz=128',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => AppMaterialIcon(
            AppIcons.globe,
            size: 24,
            color: muted,
          ),
        ),
      ),
    );
  }
}

// Capturas puramente visuais: no máximo dez miniaturas, sem rótulos.
class RecentTabPreviewsCard extends StatelessWidget {
  const RecentTabPreviewsCard({super.key});

  Rect? _sourceRect(BuildContext context) {
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      final overlayBox = overlay.context.findRenderObject() as RenderBox?;
      final box = context.findRenderObject() as RenderBox?;
      if (overlayBox == null || box == null || !box.attached) return null;
      final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
      return origin & box.size;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: tabsController,
        builder: (context, _) {
          final tabs = tabsController.tabs
              .where((tab) => tab.kind != TabKind.appScreen && !tab.isIncognito && tab.thumbnail != null)
              .toList()
            ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
          final visible = tabs.take(10).toList(growable: false);
          if (visible.isEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(25),
            ),
            child: SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final tab = visible[index];
                  return Builder(
                    builder: (tileContext) => Material(
                      color: pillColor(context),
                      borderRadius: BorderRadius.circular(15),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          final rect = _sourceRect(tileContext);
                          tabsController.activate(tab.id);
                          ShellTabRequest.instance.requestBrowserFromPreview(
                            tabId: tab.id,
                            screenshot: tab.thumbnail!,
                            sourceRect: rect,
                          );
                        },
                        child: SizedBox(
                          width: 92,
                          child: Image.memory(
                            tab.thumbnail!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
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