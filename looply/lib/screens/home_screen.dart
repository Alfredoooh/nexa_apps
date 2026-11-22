import 'package:material_ui/material_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui' show Rect;

import '../localization.dart';
import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;
import '../auth_service.dart';
import '../shell/shell_tab_request.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import '../widgets/material_symbols.dart';
import '../widgets/search_engine_pngs.dart';
import '../widgets/drawer_menu_button.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.onOpenDrawer,
    this.onOpenTabs,
    required this.recentTabPreviewKeys,
  });

  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenTabs;
  final Map<String, GlobalKey> recentTabPreviewKeys;

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
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(12, topInset > 0 ? 68 : 72, 12, 28),
              children: [
                const SizedBox(height: 12),
                const _HomeSearchInput(),
                const SizedBox(height: 12),
                const SizedBox(height: 4),
                RecentTabPreviewsCard(previewKeys: recentTabPreviewKeys),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LooplyHomeAppBar(onOpenDrawer: onOpenDrawer, onOpenTabs: onOpenTabs),
          ),
        ],
      ),
    );
  }
}

// Barra superior com drawer, logótipo, contador de abas e avatar PNG.
class LooplyHomeAppBar extends StatelessWidget {
  const LooplyHomeAppBar({super.key, this.onOpenDrawer, this.onOpenTabs});

  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenTabs;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(color: bg),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: LooplyDrawerMenuButton(
                  onPressed: onOpenDrawer ?? () => drawer_menu.showLooplyDrawer(context),
                ),
              ),
              // O canvas Lottie é quadrado; o recorte central conserva a
              // palavra BrowseIt numa escala legível, sem deformar o vetor.
              IgnorePointer(
                child: SizedBox(
                  width: 112,
                  height: 50,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 126,
                      maxWidth: 126,
                      minHeight: 126,
                      maxHeight: 126,
                      alignment: Alignment.center,
                      child: Lottie.asset(
                        'assets/animations/browseit_logo.json',
                        key: const ValueKey<String>('browseit-home-logo-lottie'),
                        width: 126,
                        height: 126,
                        fit: BoxFit.contain,
                        animate: true,
                        repeat: false,
                        delegates: LottieDelegates(
                          values: [
                            ValueDelegate.color(
                              const ['**', 'Black fill · Even-Odd'],
                              value: logoColor,
                            ),
                            ValueDelegate.strokeColor(
                              const ['**', 'Write-on stroke'],
                              value: logoColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HomeTabsButton(onPressed: onOpenTabs),
                    const SizedBox(width: 5),
                    const _HomeAvatarButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// O campo mantém a mesma geometria durante o Hero e sobe para a barra
// superior da página de pesquisa; não expande para preencher o ecrã.
class _HomeSearchInput extends StatefulWidget {
  const _HomeSearchInput();

  @override
  State<_HomeSearchInput> createState() => _HomeSearchInputState();
}

class _HomeSearchInputState extends State<_HomeSearchInput> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _engineLogo(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: aiSearchModeEnabled,
      builder: (context, aiEnabled, _) => ValueListenableBuilder<SearchEngine>(
        valueListenable: activeSearchEngine,
        builder: (context, engine, __) => Image.asset(
          searchEngineAsset(aiEnabled ? 'AI Search' : engine.name),
          width: 23,
          height: 23,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          // O motor já é identificado pelo seu PNG; não mostrar uma lupa
          // genérica por cima nem substituí-la por outro glifo.
          errorBuilder: (_, __, ___) => const SizedBox(width: 23, height: 23),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, {required bool readOnly}) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            _engineLogo(context),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _controller,
                readOnly: readOnly,
                showCursor: !readOnly,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: mainText(context), fontSize: 15),
                cursorColor: accentColor(context),
                decoration: InputDecoration(
                  hintText: appText('search_hint'),
                  hintStyle: TextStyle(color: mutedText(context), fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'browseit-home-search-field',
      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
        final hero = (direction == HeroFlightDirection.push ? toContext.widget : fromContext.widget) as Hero;
        return Material(
          color: pillColor(flightContext),
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: hero.child,
        );
      },
      child: Material(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
            CupertinoPageRoute<void>(
              builder: (_) => SearchScreen(
                controller: _controller,
                autoFocusDelay: Duration.zero,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(999),
          child: IgnorePointer(
            // O campo readonly não pode consumir o toque; a cápsula inteira abre a pesquisa.
            child: _field(context, readOnly: true),
          ),
        ),
      ),
    );
  }
}

class _HomeAvatarButton extends StatelessWidget {
  const _HomeAvatarButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LooplyUser?>(
      valueListenable: authController,
      builder: (context, user, _) => Tooltip(
        message: user == null ? appText('sign_in') : appText('profile'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).push<void>(
              CupertinoPageRoute<void>(
                builder: (_) => user == null ? const AuthScreen() : const ProfileScreen(),
              ),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: ClipOval(
                  child: Image.asset(
                    'images/avatar.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTabsButton extends StatelessWidget {
  const _HomeTabsButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: tabsController,
        builder: (context, _) {
          final color = mainText(context);
          final count = tabsController.count;
          return Tooltip(
            message: appText('tabs'),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: SizedBox(
                      width: 27,
                      height: 27,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/svg/regular/tabs-counter.svg',
                            width: 26,
                            height: 26,
                            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

// Até dez miniaturas, exclusivamente imagem. O toque envia a captura e a
// posição do cartão para o Container Transform já usado pela grelha de abas.
class RecentTabPreviewsCard extends StatefulWidget {
  const RecentTabPreviewsCard({
    super.key,
    required this.previewKeys,
  });

  final Map<String, GlobalKey> previewKeys;

  @override
  State<RecentTabPreviewsCard> createState() => _RecentTabPreviewsCardState();
}

class _RecentTabPreviewsCardState extends State<RecentTabPreviewsCard> {

  Rect? _rectFor(String id) {
    try {
      final box = widget.previewKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
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
          widget.previewKeys.removeWhere((id, _) => !tabs.any((tab) => tab.id == id));
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
                  final key = widget.previewKeys.putIfAbsent(tab.id, GlobalKey.new);
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

void openNewTab(BuildContext context, String url, {String? title}) {
  openOrbitTab(context, url, title: title);
}