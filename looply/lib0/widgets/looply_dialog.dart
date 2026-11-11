import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LooplyDialogAction<T> {
  const LooplyDialogAction({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final bool isPrimary;
  final bool isDestructive;
}

const MethodChannel _nativeUiDialogChannel = MethodChannel('looply/native_ui');

/// Android AlertDialog desenhado em Kotlin. O conteúdo é texto simples para
/// manter o desenho e a hierarquia das Views inteiramente no lado nativo.
Future<T?> showLooplyDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  String? secondaryMessage,
  required List<LooplyDialogAction<T>> actions,
  IconData? icon,
  bool barrierDismissible = true,
}) async {
  final actionMaps = actions
      .map((action) => <String, Object?>{
            'label': action.label,
            'value': action.value,
            'isPrimary': action.isPrimary,
            'isDestructive': action.isDestructive,
          })
      .toList(growable: false);

  try {
    final result = await _nativeUiDialogChannel.invokeMethod<Object?>(
      'showNativeDialog',
      <String, Object?>{
        'title': title,
        'message': message,
        'secondaryMessage': secondaryMessage,
        'actions': actionMaps,
        'barrierDismissible': barrierDismissible,
        // O IconData do conjunto SVG não é um recurso Android; não é enviado
        // como se fosse um PNG. A conversão visual fica separada deste bridge.
      },
    );
    return result as T?;
  } on MissingPluginException {
    return _showFlutterFallback<T>(
      context,
      title: title,
      message: message,
      secondaryMessage: secondaryMessage,
      actions: actions,
      icon: icon,
      barrierDismissible: barrierDismissible,
    );
  } on PlatformException {
    return null;
  }
}

Future<T?> _showFlutterFallback<T>(
  BuildContext context, {
  required String title,
  required String message,
  String? secondaryMessage,
  required List<LooplyDialogAction<T>> actions,
  IconData? icon,
  required bool barrierDismissible,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(message),
          if (secondaryMessage != null && secondaryMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(secondaryMessage),
          ],
        ],
      ),
      actions: actions
          .map((action) => TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(action.value),
                child: Text(action.label),
              ))
          .toList(growable: false),
    ),
  );
}
