import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../localization.dart';
import 'material_symbols.dart';

/// Mantém os ícones da barra de estado legíveis e aplica o mesmo escurecimento
/// ao abrir qualquer modal (diálogo ou bottom sheet) do BrowseIt.
class LooplyModalSystemBar extends StatefulWidget {
  const LooplyModalSystemBar({super.key, required this.child});

  final Widget child;

  @override
  State<LooplyModalSystemBar> createState() => _LooplyModalSystemBarState();
}

class _LooplyModalSystemBarState extends State<LooplyModalSystemBar> {
  static int _openOverlays = 0;
  static SystemUiOverlayStyle? _restoreStyle;
  bool _registered = false;
  late SystemUiOverlayStyle _modalStyle;

  SystemUiOverlayStyle _baseStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    return (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: bg,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final base = _baseStyle(context);
    final dimmedStatusBar = Color.alphaBlend(Colors.black.withOpacity(.30), pageBg(context));
    _modalStyle = base.copyWith(statusBarColor: dimmedStatusBar);
    if (!_registered) {
      _registered = true;
      if (_openOverlays == 0) _restoreStyle = base;
      _openOverlays++;
    }
    // AnnotatedRegion alone misses modal routes whose SafeArea starts below
    // the status bar. Set the native overlay explicitly as well.
    SystemChrome.setSystemUIOverlayStyle(_modalStyle);
  }

  @override
  void dispose() {
    if (_registered) {
      _openOverlays = (_openOverlays - 1).clamp(0, 1000).toInt();
      if (_openOverlays == 0) {
        final restore = _restoreStyle;
        if (restore != null) SystemChrome.setSystemUIOverlayStyle(restore);
        _restoreStyle = null;
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _modalStyle,
        child: widget.child,
      );
}

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
    barrierLabel: appText('close'),
    barrierColor: Colors.black.withOpacity(.42),
    transitionDuration: const Duration(milliseconds: 310),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final surface = isDark ? settingsCardColor(dialogContext) : Colors.white;
      final media = MediaQuery.of(dialogContext);
      final availableHeight = (media.size.height - media.viewInsets.bottom - 32)
          .clamp(240.0, media.size.height)
          .toDouble();
      return LooplyModalSystemBar(
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + media.viewInsets.bottom),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: availableHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 3,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                          const SizedBox(height: 16),
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              color: mutedText(dialogContext),
                              fontSize: 14,
                              height: 1.5,
                            ),
                            child: content,
                          ),
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, constraints) => Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final action in actions)
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth.clamp(112.0, 240.0).toDouble(),
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