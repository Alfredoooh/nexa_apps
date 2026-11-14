import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as material_ui; // Required by M3E packages on Flutter 3.47+.
import 'package:m3e_buttons/m3e_buttons.dart';
import 'package:m3e_menu/m3e_menu.dart';

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
    final itemStyle = M3EMenuItemStyle(
      backgroundColor: surface,
      foregroundColor: text,
      leadingIconColor: muted,
      textStyle: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      spatialMotion: M3EMotion.expressiveSpatialDefault,
    );
    final children = <Widget>[
      if (widget.includeAiToggle)
        M3ECheckboxMenuButton(
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
        M3EMenuItemButton(
          itemStyle: itemStyle,
          leadingIcon: AppMaterialIcon(action.icon, size: 20, color: muted),
          onPressed: () => widget.onSelected(action.value),
          child: Text(action.label, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w500)),
        ),
    ];

    return M3EMenuAnchor(
      clipBehavior: Clip.antiAlias,
      alignmentOffset: Offset(0, 5),
      style: M3EMenuStyle(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(.20),
        elevation: 13,
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minWidth: width,
        maxWidth: width,
        position: M3EMenuPosition.under,
        animationStyle: M3EMenuAnimationStyle.popup,
        spatialMotion: M3EMotion.expressiveSpatialDefault,
        effectsMotion: M3EMotion.expressiveEffectsDefault,
      ),
      menuChildren: children,
      builder: (context, controller, child) => Tooltip(
        message: widget.tooltip,
        child: M3EButton(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: M3EButtonStyle.text,
          size: M3EButtonSize.md,
          shape: M3EButtonShape.round,
          decoration: M3EButtonDecoration.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: widget.iconColor ?? mainText(context),
            minimumSize: const Size(44, 44),
            fixedSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            borderRadius: 22,
            pressedRadius: 15,
            motion: M3EMotion.expressiveSpatialDefault,
            haptic: M3EHapticFeedback.light,
          ),
          child: AppMaterialIcon(widget.icon, color: widget.iconColor ?? mainText(context)),
        ),
      ),
    );
  }
}
