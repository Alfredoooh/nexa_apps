import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../localization.dart';
import 'material_symbols.dart';

class LooplyDialogAction<T> {
  const LooplyDialogAction({required this.label, required this.value, this.isPrimary = false, this.isDestructive = false});
  final String label;
  final T value;
  final bool isPrimary;
  final bool isDestructive;
}

/// Usa a rota padrão showDialog e o AlertDialog Material 3 do tema do BrowseIt.
/// Não define transições próprias; a rota mantém a animação Material nativa.
/// A status bar não é mais escurecida manualmente: o comportamento padrão
/// do Flutter (barrier escurece só o conteúdo, status bar fica como estava)
/// foi restaurado.
Future<T?> showLooplyDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<LooplyDialogAction<T>> actions,
  IconData? icon,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(.18),
    builder: (dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final surface = isDark ? settingsCardColor(dialogContext) : Colors.white;
      final media = MediaQuery.of(dialogContext);
      final availableHeight = (media.size.height - media.viewInsets.bottom - 48)
          .clamp(240.0, media.size.height)
          .toDouble();
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              AppMaterialIcon(icon, color: mainText(dialogContext), size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.start,
                softWrap: true,
                style: TextStyle(
                  color: mainText(dialogContext),
                  fontSize: 20,
                  height: 1.25,
                  letterSpacing: -.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: availableHeight),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: mutedText(dialogContext), fontSize: 14, height: 1.5),
              child: content,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          for (final action in actions)
            _DialogActionButton<T>(
              action: action,
              onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(action.value),
            ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
    if (action.isPrimary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text(action.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: action.isDestructive ? scheme.error : scheme.primary,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: shape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(action.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
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
          const SizedBox(width: 28, height: 28, child: AppMaterialIcon(AppIcons.plus, size: 22)),
          const SizedBox(width: 14),
          const SizedBox(width: 28, height: 28, child: AppMaterialIcon(AppIcons.slidersHorizontal, size: 20)),
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
                child: AppMaterialIcon(AppIcons.arrowUp, size: 19,
                    color: _controller.text.trim().isNotEmpty ? Colors.white : muted),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}


/// Envolve conteúdo de bottom sheets num painel flutuante, afastado de todas
/// as margens da janela, com a mesma família de cantos do AssistiveTouch.
class LooplyFloatingModalFrame extends StatelessWidget {
  const LooplyFloatingModalFrame({super.key, required this.child, this.margin = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: child,
        ),
      );
}

/// Keeps Android system-bar icon contrast aligned with Looply's active theme
/// while a modal surface is displayed.
class LooplyModalSystemBar extends StatelessWidget {
  const LooplyModalSystemBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemBarStyle = (isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: pageBg(context),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarStyle,
      child: child,
    );
  }
}
