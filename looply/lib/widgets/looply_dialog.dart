import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'material_symbols.dart';

class LooplyDialogAction<T> {
  const LooplyDialogAction({required this.label, required this.value, this.isPrimary = false, this.isDestructive = false});
  final String label;
  final T value;
  final bool isPrimary;
  final bool isDestructive;
}

/// Diálogo próprio do BrowseIt: painel arredondado e simples, sem contorno
/// nem botão de fechar — fecha-se através das ações ou do toque fora dele.
/// Evita AlertDialog/Dialogs fornecidos pelo tema da plataforma.
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
    transitionDuration: const Duration(milliseconds: 310),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final scheme = Theme.of(dialogContext).colorScheme;
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final surface = isDark ? settingsCardColor(dialogContext) : Colors.white;
      final screenHeight = MediaQuery.sizeOf(dialogContext).height;
      return SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: screenHeight * .86,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Material(
                  color: surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: mainText(dialogContext),
                              fontSize: 20,
                              height: 1.2,
                              letterSpacing: -.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              color: mutedText(dialogContext),
                              fontSize: 14,
                              height: 1.5,
                            ),
                            child: content,
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, constraints) => Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final action in actions)
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth
                                            .clamp(120.0, 240.0)
                                            .toDouble(),
                                      ),
                                      child: _DialogActionButton<T>(
                                        action: action,
                                        onPressed: () => Navigator.of(dialogContext).pop(action.value),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    // Entrada expressiva com mola suave, mantendo a superfície e as cores Looply.
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final spatial = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      final effects = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: effects,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(spatial),
          child: ScaleTransition(
            scale: Tween<double>(begin: .93, end: 1).animate(spatial),
            child: child,
          ),
        ),
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