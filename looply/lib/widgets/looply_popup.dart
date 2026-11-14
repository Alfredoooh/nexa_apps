import 'package:material_ui/material_ui.dart';
import 'package:m3e_buttons/m3e_buttons.dart' as m3e_buttons;
import 'package:m3e_menu/m3e_menu.dart' as m3e_menu;

import '../theme.dart';
import 'material_symbols.dart';

class LooplyPopupAction<T> {
  const LooplyPopupAction({required this.value, required this.label, required this.icon});
  final T value;
  final String label;
  final IconData icon;
}

/// Shared app menu built with M3 Expressive spring-driven menu components.
/// The existing Looply palette remains the source for menu, text and icon colors.
class LooplyPopupMenuButton<T> extends StatefulWidget {
  const LooplyPopupMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip = 'Mais opções',
    this.icon = AppIcons.dotsThreeVertical,
    this.iconColor,
    this.menuWidth = 252,
    this.includeAiToggle = false,
    this.aiToggleValue = false,
    this.aiToggleLabel = 'Modo IA',
    this.onAiToggleChanged,
  });

  final List<LooplyPopupAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;
  final Color? iconColor;
  final double menuWidth;
  final bool includeAiToggle;
  final bool aiToggleValue;
  final String aiToggleLabel;
  final ValueChanged<bool>? onAiToggleChanged;

  @override
  State<LooplyPopupMenuButton<T>> createState() => _LooplyPopupMenuButtonState<T>();
}

class _LooplyPopupMenuButtonState<T> extends State<LooplyPopupMenuButton<T>> {
  late bool _aiValue = widget.aiToggleValue;

  @override
  void didUpdateWidget(covariant LooplyPopupMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aiToggleValue != widget.aiToggleValue) _aiValue = widget.aiToggleValue;
  }

  @override
  Widget build(BuildContext context) {
    final surface = panelColor(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final width = widget.menuWidth.clamp(210.0, 320.0).toDouble();
    final itemStyle = m3e_menu.M3EMenuItemStyle(
      backgroundColor: surface,
      foregroundColor: text,
      leadingIconColor: muted,
      textStyle: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      spatialMotion: m3e_menu.M3EMotion.expressiveSpatialDefault,
    );
    final children = <Widget>[
      if (widget.includeAiToggle)
        m3e_menu.M3ECheckboxMenuButton(
          value: _aiValue,
          closeOnActivate: false,
          leadingIcon: AppMaterialIcon(AppIcons.sparkles, size: 20, color: accentColor(context)),
          itemStyle: itemStyle,
          onChanged: (value) {
            final next = value ?? false;
            setState(() => _aiValue = next);
            widget.onAiToggleChanged?.call(next);
          },
          child: Text(widget.aiToggleLabel, style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      if (widget.includeAiToggle && widget.actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 9, color: muted.withOpacity(.18)),
        ),
      for (final action in widget.actions)
        m3e_menu.M3EMenuItemButton(
          itemStyle: itemStyle,
          leadingIcon: AppMaterialIcon(action.icon, size: 20, color: muted),
          onPressed: () => widget.onSelected(action.value),
          child: Text(action.label, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w500)),
        ),
    ];

    return m3e_menu.M3EMenuAnchor(
      clipBehavior: Clip.antiAlias,
      alignmentOffset: Offset(0, 5),
      style: m3e_menu.M3EMenuStyle(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(.20),
        elevation: 13,
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minWidth: width,
        maxWidth: width,
        position: m3e_menu.M3EMenuPosition.under,
        animationStyle: m3e_menu.M3EMenuAnimationStyle.popup,
        spatialMotion: m3e_menu.M3EMotion.expressiveSpatialDefault,
        effectsMotion: m3e_menu.M3EMotion.expressiveEffectsDefault,
      ),
      menuChildren: children,
      builder: (context, controller, child) => Tooltip(
        message: widget.tooltip,
        child: m3e_buttons.M3EButton(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: m3e_buttons.M3EButtonStyle.text,
          size: m3e_buttons.M3EButtonSize.md,
          shape: m3e_buttons.M3EButtonShape.round,
          decoration: m3e_buttons.M3EButtonDecoration.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: widget.iconColor ?? mainText(context),
            minimumSize: const Size(44, 44),
            fixedSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            borderRadius: 22,
            pressedRadius: 15,
            motion: m3e_buttons.M3EMotion.expressiveSpatialDefault,
            haptic: m3e_buttons.M3EHapticFeedback.light,
          ),
          child: AppMaterialIcon(widget.icon, color: widget.iconColor ?? mainText(context)),
        ),
      ),
    );
  }
}
