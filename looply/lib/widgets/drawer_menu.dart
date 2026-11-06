import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../screens/history_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/settings_screen.dart';
import '../models.dart';
import '../browser_library.dart';
import '../theme.dart';
import '../session_store.dart';
import '../auth_service.dart';
import '../localization.dart';
import 'phosphor_svg_icon.dart';

/// Ponte entre os botões da interface e o drawer push/drag do shell.
/// O progresso do gesto é controlado pelo AnimationController do LooplyShell.
class LooplyDrawerBridge {
  static VoidCallback? open;
  static VoidCallback? close;
}

void showLooplyDrawer(BuildContext context) {
  LooplyDrawerBridge.open?.call();
}

class LooplyDrawer extends StatelessWidget {
  const LooplyDrawer({super.key, required this.onClose, this.width = 304});

  final VoidCallback onClose;
  final double width;

  @override
  Widget build(BuildContext context) {
    final drawerBackground = pageBg(context);
    return Drawer(
      width: width,
      backgroundColor: drawerBackground,
      elevation: 16,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        // A barra de estado herda a mesma SystemUiOverlayStyle do Scaffold
        // principal. Não há AnnotatedRegion local a mudar a cor ao abrir o drawer.
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Column(
            children: [
              _DrawerHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _DrawerOption(
                      icon: PhosphorIcons.moon,
                      label: appText('change_theme'),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(8)),
                      onTap: () {
                        final navigator = Navigator.of(context);
                        onClose();
                        Future<void>.delayed(const Duration(milliseconds: 470), () {
                          if (navigator.mounted) showThemeSheet(navigator.context);
                        });
                      },
                    ),
                    const SizedBox(height: 2),
                    AnimatedBuilder(
                      animation: activityController,
                      builder: (context, _) => _DrawerOption(
                        icon: PhosphorIcons.clockCounterClockwise,
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
                        icon: PhosphorIcons.downloadSimple,
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
                        icon: PhosphorIcons.bookmarkSimple,
                        label: appText('bookmarks'),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(20)),
                        badge: bookmarksController.entries.length,
                        onTap: () => _openDrawerPage(context, const BookmarksScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: _SettingsButtonWithAvatar(
                  onTap: () => _openDrawerPage(context, const SettingsScreen()),
                ),
              ),
            ],
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
    await Future<void>.delayed(const Duration(milliseconds: 470));
    if (!navigator.mounted) return;
    await navigator.push<void>(CupertinoPageRoute<void>(builder: (_) => page));
    if (routeKey != null) {
      await SessionStore.instance.saveLastActivity(previous);
    }
  }
}


String? _drawerRouteKey(Widget page) {
  if (page is HistoryScreen) return 'history';
  if (page is DownloadsScreen) return 'downloads';
  if (page is BookmarksScreen) return 'bookmarks';
  if (page is SettingsScreen) return 'settings';
  return null;
}

Widget? _drawerPageForKey(String key) {
  switch (key) {
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

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(children: [
        SvgPicture.asset(
          'assets/images/logo_text.svg',
          width: 38,
          height: 38,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(text, BlendMode.srcIn),
          placeholderBuilder: (_) => SizedBox(width: 38, height: 38),
        ),
        const SizedBox(width: 10),
        Text('BrowseIt', style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w800)),
      ]),
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
              child: PhosphorSvgIcon(icon, color: accentColor(context), size: 19),
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

// Botão de Configurações com o avatar embutido no canto direito do
// próprio botão — sem ícone de engrenagem e sem o texto "Utilizador".
// Mostra a foto da conta logada; sem sessão, cai no asset local
// images/avatar.png em vez do ícone genérico de pessoa.
class _SettingsButtonWithAvatar extends StatelessWidget {
  const _SettingsButtonWithAvatar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
          child: Row(children: [
            Expanded(child: Text(appText('settings'), style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700))),
            ValueListenableBuilder<LooplyUser?>(
              valueListenable: authController,
              builder: (context, user, _) => Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? pillColor(context) : Colors.white,
                ),
                child: ClipOval(
                  child: user?.photoUrl != null
                      ? Image.network(
                          user!.photoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/avatar.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/avatar.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
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
    builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => ValueListenableBuilder<bool>(
        valueListenable: themeController.pureDark,
        builder: (context, pureBlack, __) {
          final surface = panelForMode(context, mode);
          final text = textForMode(context, mode);
          final accent = accentForMode(context, mode);
          Widget option({required String label, required bool selected, required VoidCallback onTap}) =>
              ListTile(
                dense: true,
                leading: PhosphorSvgIcon(
                  selected ? PhosphorIcons.circleDot : PhosphorIcons.circle,
                  color: selected ? accent : mutedForMode(context, mode),
                ),
                title: Text(label, style: TextStyle(color: text)),
                onTap: onTap,
              );

          return Material(
            color: surface,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 12),
                  Container(width: 32, height: 4, decoration: BoxDecoration(color: mutedForMode(context, mode).withOpacity(.45), borderRadius: BorderRadius.circular(99))),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(appText('theme'), style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)))),
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
  );
}