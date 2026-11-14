import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'material_symbols.dart';

class LooplyPopupAction<T> {
  const LooplyPopupAction({required this.value, required this.label, required this.icon});

  final T value;
  final String label;
  final IconData icon;
}

/// Menu flutuante totalmente desenhado em Flutter. Não depende de PopupMenu
/// Kotlin nem de canais nativos, e conserva a posição do botão acionador.
class LooplyPopupMenuButton<T> extends StatelessWidget {
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

  Future<void> _show(BuildContext buttonContext) async {
    if (actions.isEmpty && !includeAiToggle) return;
    final object = buttonContext.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return;

    final origin = object.localToGlobal(Offset.zero);
    final anchor = origin & object.size;
    final screen = MediaQuery.sizeOf(buttonContext);
    final availableWidth = (screen.width - 24).clamp(1.0, screen.width).toDouble();
    final width = availableWidth < 210
        ? availableWidth
        : menuWidth.clamp(210.0, availableWidth).toDouble();
    // Os rótulos podem ocupar duas linhas em alguns idiomas. Reservamos uma
    // altura mais realista e deixamos o conteúdo rolar quando necessário.
    final maxMenuHeight = (screen.height * .68).clamp(1.0, screen.height).toDouble();
    final estimatedHeight = ((actions.length * 66.0) + (includeAiToggle ? 66.0 : 0.0) + 16.0)
        .clamp(1.0, maxMenuHeight)
        .toDouble();
    final maxLeft = (screen.width - width - 12).clamp(12.0, screen.width).toDouble();
    final left = (anchor.right - width).clamp(12.0, maxLeft).toDouble();
    final preferredTop = anchor.bottom + 7;
    final bottomLimit = (screen.height - estimatedHeight - 12).clamp(12.0, screen.height).toDouble();
    final top = preferredTop + estimatedHeight > screen.height - 16
        ? (anchor.top - estimatedHeight - 7).clamp(12.0, bottomLimit).toDouble()
        : preferredTop.clamp(12.0, bottomLimit).toDouble();

    final selected = await showGeneralDialog<T>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: 'Fechar menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final surface = panelColor(dialogContext);
        final muted = mutedText(dialogContext);
        final text = mainText(dialogContext);
        var localAiValue = aiToggleValue;
        return StatefulBuilder(
          builder: (context, setLocalState) => Stack(
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
                  color: surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 14,
                  borderRadius: BorderRadius.circular(19),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxMenuHeight),
                      child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (includeAiToggle) ...[
                            InkWell(
                              onTap: () {
                                localAiValue = !localAiValue;
                                setLocalState(() {});
                                onAiToggleChanged?.call(localAiValue);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(15, 7, 10, 7),
                                child: Row(children: [
                                  AppMaterialIcon(AppIcons.sparkles, size: 20, color: accentColor(context)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(aiToggleLabel, style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w600))),
                                  Switch.adaptive(
                                    value: localAiValue,
                                    onChanged: (value) {
                                      localAiValue = value;
                                      setLocalState(() {});
                                      onAiToggleChanged?.call(value);
                                    },
                                  ),
                                ]),
                              ),
                            ),
                            if (actions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Divider(height: 9, color: muted.withOpacity(.16)),
                              ),
                          ],
                          for (final action in actions)
                            InkWell(
                              onTap: () => Navigator.of(dialogContext).pop(action.value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                child: Row(children: [
                                  AppMaterialIcon(action.icon, size: 20, color: muted),
                                  const SizedBox(width: 13),
                                  Expanded(child: Text(action.label, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: text, fontSize: 13.5, fontWeight: FontWeight.w500))),
                                ]),
                              ),
                            ),
                        ]),
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
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => Builder(
        builder: (buttonContext) => IconButton(
          tooltip: tooltip,
          icon: AppMaterialIcon(icon, color: iconColor ?? mainText(buttonContext)),
          onPressed: () => _show(buttonContext),
        ),
      );
}