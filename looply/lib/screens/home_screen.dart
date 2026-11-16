import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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
import '../widgets/search_engine_pngs.dart';
import '../shell/fade_page_route.dart';
import 'search_screen.dart';
import 'site_usage_detail_screen.dart';

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
              children: [
                const SizedBox(height: 12),
                const _HomeSearchInput(),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: QuickSiteGridCard()),
                    SizedBox(width: 10),
                    Expanded(child: _AiSearchHomeCard()),
                  ],
                ),
                const SizedBox(height: 16),
                const RecentTabPreviewsCard(),
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
      decoration: BoxDecoration(color: bg),
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

// Barra de pesquisa no topo da Home. A abertura usa fade (sem deslocamento).
class _HomeSearchInput extends StatelessWidget {
  const _HomeSearchInput();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          FadePageRoute<void>(builder: (_) => const SearchScreen()),
        ),
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: aiSearchModeEnabled,
                  builder: (context, aiEnabled, _) {
                    if (aiEnabled) {
                      return Image.memory(searchEnginePng('AI Search')!, width: 23, height: 23, fit: BoxFit.contain);
                    }
                    return ValueListenableBuilder<SearchEngine>(
                      valueListenable: activeSearchEngine,
                      builder: (context, engine, _) {
                        final png = searchEnginePng(engine.name);
                        return png == null
                            ? AppMaterialIcon(AppIcons.magnifyingGlass, size: 23, color: mutedText(context))
                            : Image.memory(png, width: 23, height: 23, fit: BoxFit.contain);
                      },
                    );
                  },
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    appText('search_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mutedText(context), fontSize: 15),
                  ),
                ),
                AppMaterialIcon(AppIcons.magnifyingGlass, size: 21, color: mutedText(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Recent sites e AI Search ocupam a mesma linha e a mesma altura.
class QuickSiteGridCard extends StatelessWidget {
  const QuickSiteGridCard({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([activityController, browserFaviconCache]),
        builder: (context, _) {
          final recent = <ActivityEntry>[];
          final hosts = <String>{};
          for (final entry in activityController.entries) {
            if (entry.kind != ActivityKind.site) continue;
            final host = Uri.tryParse(entry.url)?.host.toLowerCase() ?? '';
            if (host.isEmpty || !hosts.add(host)) continue;
            recent.add(entry);
            if (recent.length >= 3) break;
          }
          return Material(
            color: settingsCardColor(context),
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: recent.isEmpty
                  ? null
                  : () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(builder: (_) => const SiteUsageDetailScreen()),
                      ),
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 76,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 40,
                        child: recent.isEmpty
                            ? CircleAvatar(
                                backgroundColor: pillColor(context),
                                child: AppMaterialIcon(AppIcons.globe, size: 22, color: mutedText(context)),
                              )
                            : Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (var i = 0; i < recent.length; i++)
                                    Positioned(
                                      left: i * 11,
                                      top: 3,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: pillColor(context),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: settingsCardColor(context), width: 2),
                                        ),
                                        child: ClipOval(
                                          child: _MiniSiteFavicon(url: recent[i].url),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          appText('recent'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: mainText(context), fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _MiniSiteFavicon extends StatelessWidget {
  const _MiniSiteFavicon({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final encoded = browserFaviconCache.forUrl(url);
    if (encoded != null) {
      try {
        return Image.memory(base64Decode(encoded), fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallback(context));
      } catch (_) {}
    }
    unawaited(browserFaviconCache.fetchForUrl(url));
    return Image.network(
      'https://www.google.com/s2/favicons?domain_url=${Uri.encodeComponent(url)}&sz=64',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) => Center(
        child: AppMaterialIcon(AppIcons.globe, size: 19, color: mutedText(context)),
      );
}

class _AiSearchHomeCard extends StatelessWidget {
  const _AiSearchHomeCard();

  void _open(BuildContext context) {
    final tab = tabsController.createBrowserTab('looply://ai-search', title: 'AI Search');
    tabsController.activate(tab.id);
    ShellTabRequest.instance.requestBrowser(tab.id);
  }

  @override
  Widget build(BuildContext context) => Material(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Image.memory(searchEnginePng('AI Search')!, width: 28, height: 28, fit: BoxFit.contain),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('AI Search', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: mainText(context), fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class SiteFaviconForHome extends StatelessWidget {
  const SiteFaviconForHome({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    final cached = browserFaviconCache.forUrl(url);
    final Widget favicon = cached != null
        ? Image.memory(base64Decode(cached), width: 35, height: 35, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, size: 24, color: muted))
        : Image.network(
            'https://www.google.com/s2/favicons?domain_url=${Uri.encodeComponent(url)}&sz=128',
            width: 35, height: 35, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.globe, size: 24, color: muted),
          );
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: pillColor(context), shape: BoxShape.circle),
      child: ClipOval(child: favicon),
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