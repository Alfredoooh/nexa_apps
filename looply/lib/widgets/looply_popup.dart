import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

class LooplyPopupAction<T> {
  const LooplyPopupAction({required this.value, required this.label, required this.icon});

  final T value;
  final String label;
  final IconData icon;
}

/// Menu flutuante do Looply. Todos os menus usam a mesma geometria, curva e
/// duração, sem depender da animação nativa inconsistente do PopupMenuButton.
class LooplyPopupMenuButton<T> extends StatelessWidget {
  const LooplyPopupMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip = 'Mais opções',
    this.icon = Symbols.more_vert_rounded,
    this.iconColor,
    this.menuWidth = 252,
  });

  final List<LooplyPopupAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;
  final Color? iconColor;
  final double menuWidth;

  Future<void> _show(BuildContext buttonContext) async {
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final anchor = topLeft & renderObject.size;
    final screen = MediaQuery.sizeOf(buttonContext);
    final safePadding = MediaQuery.paddingOf(buttonContext);
    final width = menuWidth.clamp(190.0, screen.width - 16).toDouble();
    final estimatedHeight = (actions.length * 48.0 + 12).clamp(60.0, screen.height - safePadding.vertical - 20).toDouble();
    final left = (anchor.right - width).clamp(8.0, screen.width - width - 8).toDouble();
    final preferredTop = anchor.bottom + 7;
    final top = (preferredTop + estimatedHeight <= screen.height - safePadding.bottom - 8)
        ? preferredTop
        : (anchor.top - estimatedHeight - 7).clamp(safePadding.top + 8, screen.height - estimatedHeight - 8).toDouble();

    final selected = await showGeneralDialog<T>(
      context: buttonContext,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Fechar menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, __) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Material(
              color: settingsCardColor(dialogContext),
              surfaceTintColor: Colors.transparent,
              elevation: 12,
              shadowColor: Colors.black.withOpacity(.18),
              borderRadius: BorderRadius.circular(19),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(action.value),
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Icon(action.icon, size: 20, color: mutedText(dialogContext)),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Text(
                                    action.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: mainText(dialogContext), fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) => FadeScaleTransition(
        animation: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      ),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => Builder(
        builder: (buttonContext) => IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: iconColor ?? mainText(context)),
          onPressed: () => _show(buttonContext),
        ),
      );
}
