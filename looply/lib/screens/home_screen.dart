import 'package:material_ui/material_ui.dart';
import 'package:animations/animations.dart';
import 'dart:ui' show Rect;

import '../localization.dart';
import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;
import '../auth_service.dart';
import '../shell/shell_tab_request.dart';
import 'auth_screen.dart';
import '../widgets/material_symbols.dart';
import '../widgets/search_engine_pngs.dart';
import '../widgets/drawer_menu_button.dart';
import 'search_screen.dart';

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
                const SizedBox(height: 4),
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
              LooplyDrawerMenuButton(
                onPressed: onOpenDrawer ?? () => drawer_menu.showLooplyDrawer(context),
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

// A mesma instância do controlador acompanha o campo durante o Container Transform.
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
          errorBuilder: (_, __, ___) => AppMaterialIcon(
            AppIcons.magnifyingGlass,
            size: 23,
            color: mutedText(context),
          ),
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
            AppMaterialIcon(AppIcons.magnifyingGlass, size: 21, color: mutedText(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OpenContainer<void>(
      transitionType: ContainerTransitionType.fade,
      transitionDuration: const Duration(milliseconds: 480),
      closedElevation: 0,
      openElevation: 0,
      closedColor: pillColor(context),
      openColor: pageBg(context),
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      openShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.antiAlias,
      tappable: false,
      openBuilder: (context, closeContainer) => SearchScreen(
        controller: _controller,
        autoFocusDelay: const Duration(milliseconds: 480),
      ),
      closedBuilder: (context, openContainer) => Material(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openContainer,
          borderRadius: BorderRadius.circular(999),
          child: _field(context, readOnly: true),
        ),
      ),
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