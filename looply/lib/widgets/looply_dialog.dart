import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

class LooplyDialogAction<T> {
  const LooplyDialogAction({required this.label, required this.value, this.isPrimary = false, this.isDestructive = false});
  final String label;
  final T value;
  final bool isPrimary;
  final bool isDestructive;
}

/// Diálogo próprio do BrowseIt: painel arredondado, contorno subtil e ações
/// compactas. Evita AlertDialog/Dialogs fornecidos pelo tema da plataforma.
Future<T?> showLooplyDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<LooplyDialogAction<T>> actions,
  IconData? icon,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Fechar diálogo',
    barrierColor: Colors.black.withOpacity(.42),
    transitionDuration: const Duration(milliseconds: 190),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final text = mainText(dialogContext);
      final muted = mutedText(dialogContext);
      final surface = panelColor(dialogContext);
      final outline = lineColor(dialogContext);
      return SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Material(
                  color: surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 18,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: outline, width: 1.2), borderRadius: BorderRadius.circular(26)),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (icon != null) ...[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: pillColor(dialogContext), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Icon(icon, color: accentColor(dialogContext), size: 19),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(child: Text(title, style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800))),
                          IconButton(
                            tooltip: 'Fechar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: Icon(Symbols.close_rounded, color: muted, size: 19),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        DefaultTextStyle.merge(
                          style: TextStyle(color: muted, fontSize: 13.5, height: 1.45),
                          child: content,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Spacer(),
                            for (var index = 0; index < actions.length; index++) ...[
                              if (index > 0) const SizedBox(width: 8),
                              _DialogActionButton<T>(
                                action: actions[index],
                                onPressed: () => Navigator.of(dialogContext).pop(actions[index].value),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: .94, end: 1).animate(curved), child: child),
      );
    },
  );
}

class _DialogActionButton<T> extends StatelessWidget {
  const _DialogActionButton({required this.action, required this.onPressed});
  final LooplyDialogAction<T> action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = action.isDestructive
        ? const Color(0xFFFF453A)
        : (action.isPrimary ? Colors.white : mutedText(context));
    return Material(
      color: action.isPrimary ? accentColor(context) : pillColor(context),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            action.label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Composer fiel ao HTML fornecido: input multiline, limite de 140 px,
/// botões circulares e botão enviar que muda de estado quando há texto.
class LooplyPromptComposer extends StatefulWidget {
  const LooplyPromptComposer({super.key, this.hintText = 'Pergunte, busque ou crie qualquer coisa', this.onSend});
  final String hintText;
  final ValueChanged<String>? onSend;

  @override
  State<LooplyPromptComposer> createState() => _LooplyPromptComposerState();
}

class _LooplyPromptComposerState extends State<LooplyPromptComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSend?.call(value);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: panelColor(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: lineColor(context), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 26, maxHeight: 140),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _send(),
            style: TextStyle(color: mainText(context), fontSize: 16, height: 1.4),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: muted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const SizedBox(width: 28, height: 28, child: Icon(Symbols.add_rounded, size: 22)),
          const SizedBox(width: 14),
          const SizedBox(width: 28, height: 28, child: Icon(Symbols.tune_rounded, size: 20)),
          const Spacer(),
          Material(
            color: _controller.text.trim().isNotEmpty ? accentColor(context) : pillColor(context),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _send,
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(Symbols.arrow_upward_rounded, size: 19,
                    color: _controller.text.trim().isNotEmpty ? Colors.white : muted),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
