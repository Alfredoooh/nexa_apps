import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../screens/history_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';

// Abre o Drawer gerido pelo próprio Scaffold. Assim o Flutter controla
// a animação Material, o gesto de arrastar da borda e o fecho por swipe.
void showLooplyDrawer(BuildContext context) {
  Scaffold.maybeOf(context)?.openDrawer();
}

class LooplyDrawer extends StatelessWidget {
  const LooplyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final drawerBackground = pageBg(context);
    return Drawer(
      backgroundColor: drawerBackground,
      elevation: 16,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _DrawerOption(
                      icon: Symbols.dark_mode_rounded,
                      label: 'Alterar tema',
                      onTap: () {
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) showThemeSheet(context);
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerOption(
                      icon: Symbols.history_rounded,
                      label: 'Histórico',
                      onTap: () => _openDrawerPage(context, const HistoryScreen()),
                    ),
                    const SizedBox(height: 8),
                    _DrawerOption(
                      icon: Symbols.download_rounded,
                      label: 'Downloads',
                      onTap: () => _openDrawerPage(context, const DownloadsScreen()),
                    ),
                    const SizedBox(height: 8),
                    _DrawerOption(
                      icon: Symbols.bookmark_rounded,
                      label: 'Marcadores',
                      onTap: () => _openDrawerPage(context, const BookmarksScreen()),
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

  void _openDrawerPage(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      }
    });
  }
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/looply_icon.png', width: 34, height: 34, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Text('Looply', style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _DrawerOption extends StatelessWidget {
  const _DrawerOption({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final radius = BorderRadius.circular(14);
    return Material(
      color: settingsCardColor(context),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
              child: Icon(icon, color: accentColor(context), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600))),
            Icon(Symbols.chevron_right_rounded, color: muted, size: 18),
          ]),
        ),
      ),
    );
  }
}

// Botão de Configurações com o avatar embutido no canto direito do
// próprio botão — sem ícone de engrenagem e sem o texto "Utilizador".
class _SettingsButtonWithAvatar extends StatelessWidget {
  const _SettingsButtonWithAvatar({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 9, 8),
          child: Row(children: [
            Expanded(child: Text('Configurações', style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700))),
            Container(
              width: 32, height: 32, alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? looplyPanel2Dark : Colors.white),
              child: Icon(Symbols.person_rounded, size: 20, color: mutedText(context)),
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
      builder: (context, mode, _) {
        final surface = panelForMode(context, mode);
        final text = textForMode(context, mode);
        final accent = accentForMode(context, mode);
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
                Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Tema', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)))),
                RadioListTile<ThemeMode>(value: ThemeMode.light, groupValue: mode, activeColor: accent, title: Text('Claro', style: TextStyle(color: text)), onChanged: (value) { if (value != null) themeController.setMode(value); }),
                RadioListTile<ThemeMode>(value: ThemeMode.dark, groupValue: mode, activeColor: accent, title: Text('Escuro', style: TextStyle(color: text)), onChanged: (value) { if (value != null) themeController.setMode(value); }),
                RadioListTile<ThemeMode>(value: ThemeMode.system, groupValue: mode, activeColor: accent, title: Text('Automático', style: TextStyle(color: text)), onChanged: (value) { if (value != null) themeController.setMode(value); }),
              ]),
            ),
          ),
        );
      },
    ),
  );
}
