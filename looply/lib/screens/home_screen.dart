import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:ui' show Rect;

import '../localization.dart';
import '../models.dart';
import '../browser_library.dart';
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
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, topInset > 0 ? 68 : 72, 12, 28),
              children: const [
                SizedBox(height: 18),
                HomeCardsDeck(),
                SizedBox(height: 14),
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

// Sites recentes: favicon redondo e compacto, sobre cinza neutro,
// com o nome em peso regular. A faixa permite até dez entradas horizontais.
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
            if (recent.length >= 10) break;
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            decoration: BoxDecoration(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(29),
            ),
            child: recent.isEmpty
                ? SizedBox(
                    height: 92,
                    child: Center(
                      child: Text(
                        appText('no_recent_activity'),
                        style: TextStyle(color: mutedText(context), fontSize: 12),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: recent.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => SizedBox(
                        width: 70,
                        child: _RecentSiteTile(entry: recent[index]),
                      ),
                    ),
                  ),
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
    final label = entry.title.trim().isNotEmpty
        ? entry.title.trim()
        : host.replaceFirst(RegExp(r'^www\.'), '');
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openNewTab(context, entry.url, title: entry.title),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SiteFaviconForHome(url: entry.url),
            const SizedBox(height: 5),
            SizedBox(
              height: 25,
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mainText(context),
                  fontSize: 10.5,
                  height: 1.13,
                  fontWeight: FontWeight.w400,
                ),
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
    final cached = browserFaviconCache.forUrl(url);
    final Widget favicon = cached != null
        ? Image.memory(
            base64Decode(cached),
            width: 35,
            height: 35,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AppMaterialIcon(
              AppIcons.globe, size: 23, color: muted,
            ),
          )
        : Image.network(
            'https://www.google.com/s2/favicons?domain_url=${Uri.encodeComponent(url)}&sz=128',
            width: 35,
            height: 35,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AppMaterialIcon(
              AppIcons.globe, size: 23, color: muted,
            ),
          );
    final circleColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF383A3E)
        : const Color(0xFFE3E5E8);
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
      ),
      child: favicon,
    );
  }
}

// Dois cartões empilhados: as miniaturas das abas começam à frente e os
// sites recentes ficam ligeiramente visíveis por trás. A troca é vertical
// e só responde a gestos iniciados dentro desta área.
class HomeCardsDeck extends StatefulWidget {
  const HomeCardsDeck({super.key});

  @override
  State<HomeCardsDeck> createState() => _HomeCardsDeckState();
}

class _HomeCardsDeckState extends State<HomeCardsDeck> {
  bool _showTabs = true;
  double _verticalDrag = 0;

  void _finishVerticalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldChange = _verticalDrag.abs() >= 28 || velocity.abs() >= 260;
    if (!shouldChange) {
      _verticalDrag = 0;
      return;
    }
    final direction = _verticalDrag.abs() >= 28 ? _verticalDrag : velocity;
    setState(() => _showTabs = direction < 0);
    _verticalDrag = 0;
  }

  @override
  Widget build(BuildContext context) {
    final activeHeight = _showTabs ? 148.0 : 116.0;
    final backColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF34363A)
        : const Color(0xFFE7E9EC);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) => _verticalDrag += details.delta.dy,
            onVerticalDragEnd: _finishVerticalDrag,
            onVerticalDragCancel: () => _verticalDrag = 0,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: activeHeight + 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 13,
                      left: 6,
                      right: 6,
                      height: activeHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: backColor,
                          borderRadius: BorderRadius.circular(29),
                          border: Border.all(
                            color: lineColor(context).withOpacity(.42),
                            width: .7,
                          ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: Offset(0, _showTabs ? .08 : -.08),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: SizedBox(
                        key: ValueKey<bool>(_showTabs),
                        height: activeHeight,
                        child: _showTabs
                            ? const RecentTabPreviewsCard()
                            : const QuickSiteGridCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 4,
                height: _showTabs ? 17 : 6,
                decoration: BoxDecoration(
                  color: _showTabs ? accentColor(context) : mutedText(context).withOpacity(.48),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 4,
                height: _showTabs ? 6 : 17,
                decoration: BoxDecoration(
                  color: _showTabs ? mutedText(context).withOpacity(.48) : accentColor(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Até dez miniaturas, exclusivamente imagem. O toque envia a captura e a
// posição do cartão para o Container Transform já usado pela grelha de abas.
class RecentTabPreviewsCard extends StatefulWidget {
  const RecentTabPreviewsCard({super.key});

  @override
  State<RecentTabPreviewsCard> createState() => _RecentTabPreviewsCardState();
}

class _RecentTabPreviewsCardState extends State<RecentTabPreviewsCard> {
  final Map<String, GlobalKey> _previewKeys = <String, GlobalKey>{};

  Rect? _rectFor(String id) {
    try {
      final box = _previewKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return null;
      final origin = box.localToGlobal(Offset.zero);
      return origin & box.size;
    } catch (_) {
      return null;
    }
  }

  void _open(BrowserTab tab) {
    final image = tab.thumbnail;
    if (image == null || image.isEmpty) return;
    tabsController.activate(tab.id);
    ShellTabRequest.instance.requestBrowserFromPreview(
      tabId: tab.id,
      screenshot: image,
      sourceRect: _rectFor(tab.id),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: tabsController,
        builder: (context, _) {
          final visible = tabsController.tabs
              .where((tab) =>
                  tab.kind != TabKind.appScreen &&
                  !tab.isIncognito &&
                  tab.thumbnail != null &&
                  tab.thumbnail!.isNotEmpty)
              .toList()
            ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
          final tabs = visible.take(10).toList(growable: false);
          _previewKeys.removeWhere((id, _) => !tabs.any((tab) => tab.id == id));
          if (tabs.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(29),
            ),
            child: SizedBox(
              height: 122,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final key = _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
                  return Material(
                    key: key,
                    color: pillColor(context),
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(tab),
                      borderRadius: BorderRadius.circular(18),
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