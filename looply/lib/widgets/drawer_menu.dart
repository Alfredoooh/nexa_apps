import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';

// Novo drawer: topo com ícone+nome do app, lista de opções (tema,
// histórico, downloads, marcadores), e o botão de Configurações no
// rodapé com o avatar embutido no canto direito do próprio botão
// (sem ícone de engrenagem, sem texto "Utilizador").
void showLooplyDrawer(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Fechar menu',
    barrierColor: Colors.black.withOpacity(.46),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final slideAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(slideAnimation),
                child: _DrawerPanel(
                  child: SafeArea(
                    child: Column(
                      children: [
                        _DrawerHeader(),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            children: [
                              _DrawerOption(
                                icon: Symbols.dark_mode_rounded,
                                label: 'Alterar tema',
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (context.mounted) showThemeSheet(context);
                                  });
                                },
                              ),
                              _DrawerOption(
                                icon: Symbols.history_rounded,
                                label: 'Histórico',
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (context.mounted) {
                                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
                                    }
                                  });
                                },
                              ),
                              _DrawerOption(
                                icon: Symbols.download_rounded,
                                label: 'Downloads',
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Ainda não há downloads.')),
                                      );
                                    }
                                  });
                                },
                              ),
                              _DrawerOption(
                                icon: Symbols.bookmark_rounded,
                                label: 'Marcadores',
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Ainda não há marcadores.')),
                                      );
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                          child: _SettingsButtonWithAvatar(
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(opacity: fadeAnimation, child: child);
    },
  );
}

class _DrawerPanel extends StatefulWidget {
  const _DrawerPanel({required this.child});
  final Widget child;

  @override
  State<_DrawerPanel> createState() => _DrawerPanelState();
}

class _DrawerPanelState extends State<_DrawerPanel> {
  double _dragOffset = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * .82;
    final slide = width == 0 ? 0.0 : _dragOffset / width;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: AnimatedSlide(
          offset: Offset(slide, 0),
          duration: _dragging ? Duration.zero : const Duration(milliseconds: 210),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (details) {
              if (details.delta.dx >= 0) return;
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx).clamp(-width, 0).toDouble();
              });
            },
            onHorizontalDragEnd: (details) {
              final shouldClose = _dragOffset < -width * .24 ||
                  details.velocity.pixelsPerSecond.dx < -560;
              if (shouldClose) {
                Navigator.of(context).maybePop();
              } else {
                setState(() {
                  _dragging = false;
                  _dragOffset = 0;
                });
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: pageBg(context),
                elevation: 18,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          child: Row(children: [
            Icon(icon, color: text, size: 22),
            const SizedBox(width: 18),
            Text(label, style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600)),
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
      color: pillColor(context),
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
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
