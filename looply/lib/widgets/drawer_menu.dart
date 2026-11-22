import 'package:material_ui/material_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

import '../screens/history_screen.dart';
import '../screens/activity_screen.dart';
import '../screens/games_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/settings_screen.dart';
import '../models.dart';
import '../browser_library.dart';
import '../theme.dart';
import '../session_store.dart';
import '../localization.dart';
import '../shell/shell_tab_request.dart';
import 'material_symbols.dart';
import 'looply_dialog.dart';

/// Ponte entre os botões da interface e o drawer push/drag do shell.
/// O progresso do gesto é controlado pelo AnimationController do LooplyShell.
class LooplyDrawerBridge {
  static VoidCallback? open;
  static VoidCallback? close;
  static final ValueNotifier<bool> showHomeAction = ValueNotifier<bool>(false);
}

void showLooplyDrawer(BuildContext context) {
  LooplyDrawerBridge.open?.call();
}

/// Abre o mesmo drawer por cima de rotas que foram empilhadas no Navigator
/// raiz (por exemplo, AI Search). O drawer do Shell fica atrás dessas rotas,
/// por isso esta variante usa uma rota de overlay real.
Future<void> showLooplyDrawerFromRoute(BuildContext context) {
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final screenWidth = MediaQuery.sizeOf(context).width;
  final drawerWidth = math.min(320.0, math.min(screenWidth * .82, screenWidth - 24)).toDouble();

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: appText('close'),
    barrierColor: Colors.black.withOpacity(.22),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SizedBox.expand(
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: drawerWidth,
            height: MediaQuery.sizeOf(dialogContext).height,
            child: LooplyDrawer(
              width: drawerWidth,
              onClose: () => Navigator.of(dialogContext).pop(),
              onHomeTapOverride: () {
                Navigator.of(dialogContext).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!rootNavigator.mounted) return;
                  rootNavigator.popUntil((route) => route.isFirst);
                  ShellTabRequest.instance.request(0);
                });
              },
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class LooplyDrawer extends StatelessWidget {
  const LooplyDrawer({super.key, required this.onClose, this.width = 304, this.onHomeTapOverride});

  final VoidCallback onClose;
  final double width;
  final VoidCallback? onHomeTapOverride;

  @override
  Widget build(BuildContext context) {
    final drawerBackground = pageBg(context);

    // Superfície explícita para o drawer não herdar o surface tint cinzento
    // padrão do Material 3. O painel mantém a mesma largura e o mesmo layout.
    return Material(
      color: drawerBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withOpacity(.18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: ColoredBox(
          color: drawerBackground,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: LooplyDrawerBridge.showHomeAction,
                    builder: (context, showHome, _) => _DrawerHeader(
                      showHome: showHome,
                      onHomeTap: showHome
                          ? (onHomeTapOverride ?? () {
                              onClose();
                              Future<void>.delayed(const Duration(milliseconds: 520), () {
                                ShellTabRequest.instance.request(0);
                              });
                            })
                          : null,
                      onSettingsTap: () => _openDrawerPage(context, const SettingsScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                        _DrawerOption(
                          icon: AppIcons.moon,
                          label: appText('change_theme'),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                            bottom: Radius.circular(8),
                          ),
                          onTap: () {
                            final navigator = Navigator.of(context);
                            onClose();
                            Future<void>.delayed(const Duration(milliseconds: 520), () {
                              if (navigator.mounted) showThemeSheet(navigator.context);
                            });
                          },
                        ),
                        const SizedBox(height: 2),
                        _DrawerOption(
                          icon: AppIcons.statistics,
                          label: appText('activity'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openDrawerPage(context, const ActivityScreen()),
                        ),
                        const SizedBox(height: 2),
                        _DrawerOption(
                          icon: AppIcons.sportsEsports,
                          label: appText('games'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openDrawerPage(context, const GamesScreen()),
                        ),
                        const SizedBox(height: 2),
                        AnimatedBuilder(
                          animation: activityController,
                          builder: (context, _) => _DrawerOption(
                            icon: AppIcons.clockCounterClockwise,
                            label: appText('history'),
                            borderRadius: BorderRadius.circular(8),
                            badge: activityController.entries.length,
                            onTap: () => _openDrawerPage(context, const HistoryScreen()),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedBuilder(
                          animation: downloadsController,
                          builder: (context, _) => _DrawerOption(
                            icon: AppIcons.downloadSimple,
                            label: appText('downloads'),
                            borderRadius: BorderRadius.circular(8),
                            badge: downloadsController.entries.length,
                            onTap: () => _openDrawerPage(context, const DownloadsScreen()),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedBuilder(
                          animation: bookmarksController,
                          builder: (context, _) => _DrawerOption(
                            icon: AppIcons.bookmarkSimple,
                            label: appText('bookmarks'),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(20),
                            ),
                            badge: bookmarksController.entries.length,
                            onTap: () => _openDrawerPage(context, const BookmarksScreen()),
                          ),
                        ),
                        ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDrawerPage(BuildContext context, Widget page) async {
    final navigator = Navigator.of(context);
    final previous = await SessionStore.instance.getLastActivity() ??
        <String, dynamic>{'type': 'shell', 'screenIndex': 0};
    final routeKey = _drawerRouteKey(page);
    if (routeKey != null) {
      await SessionStore.instance.saveLastActivity({
        'type': 'drawer_page',
        'page': routeKey,
        'returnTo': previous,
      });
    }
    if (!context.mounted || !navigator.mounted) return;

    onClose();
    // Espera o movimento push terminar antes de apresentar a página.
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!navigator.mounted) return;
    await navigator.push<void>(CupertinoPageRoute<void>(builder: (_) => page));
    if (routeKey != null) {
      await SessionStore.instance.saveLastActivity(previous);
    }
  }
}


String? _drawerRouteKey(Widget page) {
  if (page is ActivityScreen) return 'activity';
  if (page is GamesScreen) return 'games';
  if (page is HistoryScreen) return 'history';
  if (page is DownloadsScreen) return 'downloads';
  if (page is BookmarksScreen) return 'bookmarks';
  if (page is SettingsScreen) return 'settings';
  return null;
}

Widget? _drawerPageForKey(String key) {
  switch (key) {
    case 'activity':
      return const ActivityScreen();
    case 'games':
      return const GamesScreen();
    case 'history':
      return const HistoryScreen();
    case 'downloads':
      return const DownloadsScreen();
    case 'bookmarks':
      return const BookmarksScreen();
    case 'settings':
      return const SettingsScreen();
    default:
      return null;
  }
}

/// Reabre uma tela do Drawer que era a atividade visível quando o app foi
/// encerrado. O destino anterior volta a ser gravado quando o utilizador sai.
Future<void> restoreDrawerPageActivity(
  BuildContext context, {
  required String pageKey,
  required Map<String, dynamic> returnTo,
}) async {
  final page = _drawerPageForKey(pageKey);
  if (page == null || !context.mounted) {
    await SessionStore.instance.saveLastActivity(returnTo);
    return;
  }
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(builder: (_) => page),
  );
  await SessionStore.instance.saveLastActivity(returnTo);
}

// Cabeçalho do drawer: título "Menu" com M maiúsculo, alinhado à esquerda
// e verticalmente centrado dentro da área do cabeçalho.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({this.showHome = false, this.onHomeTap, required this.onSettingsTap});

  final bool showHome;
  final VoidCallback? onHomeTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final raw = appText('menu');
    final label = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.2,
                  height: 1.15,
                ),
              ),
            ),
            if (showHome)
              Semantics(
                button: true,
                label: appText('home'),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onHomeTap,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(
                        child: AppMaterialIcon(AppIcons.house, color: text, size: 23),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: appText('settings'),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSettingsTap,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/svg/regular/settings.svg',
                        width: 23,
                        height: 23,
                        colorFilter: ColorFilter.mode(text, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerOption extends StatelessWidget {
  const _DrawerOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    required this.borderRadius,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    // Mesma geometria agrupada dos cartões da tela Configurações:
    // primeiro cartão com topo mais curvo, cartões centrais discretos,
    // último cartão com base mais curvada.
    final radius = borderRadius;
    return Material(
      color: settingsCardColor(context),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          // Mesmos insets, altura natural e caixa de ícone dos _SettingsTile.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
              child: AppMaterialIcon(icon, color: text, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (badge > 0)
              Container(
                height: 20,
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor(context),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge > 999 ? '999+' : '$badge',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

void showThemeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (sheetContext) => LooplyModalSystemBar(
      child: LooplyFloatingModalFrame(
        child: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => ValueListenableBuilder<bool>(
        valueListenable: themeController.pureDark,
        builder: (context, pureBlack, __) {
          final surface = panelForMode(context, mode);
          final text = textForMode(context, mode);
          final accent = accentForMode(context, mode);
          Widget option({required String label, required bool selected, required VoidCallback onTap}) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? accent.withOpacity(.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                dense: true,
                leading: AppMaterialIcon(
                  selected ? AppIcons.circleDot : AppIcons.circle,
                  color: selected ? accent : mutedForMode(context, mode),
                ),
                title: Text(label, style: TextStyle(color: text)),
                onTap: () { HapticFeedback.selectionClick(); onTap(); },
              ),
              );

          return Material(
            color: surface,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(28),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 12),
                  Container(width: 32, height: 4, decoration: BoxDecoration(color: mutedForMode(context, mode).withOpacity(.45), borderRadius: BorderRadius.circular(99))),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(appText('theme'), style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)))),
                  option(label: appText('light'), selected: mode == ThemeMode.light, onTap: () => themeController.setMode(ThemeMode.light)),
                  if (mode == ThemeMode.dark) ...[
                    option(label: appText('dark'), selected: !pureBlack, onTap: () => themeController.setMode(ThemeMode.dark)),
                    option(label: appText('deep_dark'), selected: pureBlack, onTap: () => themeController.setPureDark(true)),
                  ] else
                    option(label: appText('dark'), selected: false, onTap: () => themeController.setMode(ThemeMode.dark)),
                  option(label: appText('automatic'), selected: mode == ThemeMode.system, onTap: () => themeController.setMode(ThemeMode.system)),
                ]),
              ),
            ),
          );
        },
      ),
      ),
    ),
    ),
  );
}