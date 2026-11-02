import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

class LooplyPopupAction<T> {
  const LooplyPopupAction({required this.value, required this.label, required this.icon});

  final T value;
  final String label;
  final IconData icon;
}

/// No Android, os menus são exibidos pelo PopupMenu nativo do Kotlin/Android.
/// Assim a animação de abertura/fecho, a ancoragem e o posicionamento são os
/// próprios do sistema, em vez de um overlay Flutter simulado.
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

  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');

  Future<void> _show(BuildContext buttonContext) async {
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize || actions.isEmpty) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final anchor = topLeft & renderObject.size;
    final screen = MediaQuery.sizeOf(buttonContext);

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final iconColor = mutedText(buttonContext);
        final nativeItems = <Map<String, Object>>[];
        for (final action in actions) {
          final iconBytes = await _renderRoundedIcon(action.icon, iconColor);
          nativeItems.add(<String, Object>{
            'label': action.label,
            'value': action.value as Object,
            if (iconBytes != null) 'icon': iconBytes,
          });
        }
        final selected = await _nativeUi.invokeMethod<dynamic>(
          'showNativePopup',
          <String, Object>{
            'anchor': <String, double>{
              'right': anchor.right,
              'bottom': anchor.bottom,
            },
            'items': nativeItems,
          },
        );
        if (selected != null) onSelected(selected as T);
      } on PlatformException {
        // Não substitui o menu Android por um popup Flutter: mantém apenas
        // o comportamento nativo quando o canal da plataforma está disponível.
      } on MissingPluginException {
        // Não existe PopupMenu Kotlin noutras plataformas.
      }
      return;
    }

    // Fallback nativo da plataforma para builds que não sejam Android.
    final selected = await showMenu<T>(
      context: buttonContext,
      position: RelativeRect.fromLTRB(
        anchor.left,
        anchor.bottom,
        screen.width - anchor.right,
        screen.height - anchor.bottom,
      ),
      items: actions
          .map(
            (action) => PopupMenuItem<T>(
              value: action.value,
              child: Row(
                children: [
                  Icon(action.icon, size: 20, color: mutedText(buttonContext)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
    if (selected != null) onSelected(selected);
  }


  Future<Uint8List?> _renderRoundedIcon(IconData icon, Color color) async {
    const logicalSize = 24.0;
    const pixelRatio = 3.0;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: logicalSize,
          height: 1,
          fontFamily: icon.fontFamily,
          fontFamilyFallback: icon.fontFamilyFallback,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(pixelRatio);
    painter.paint(
      canvas,
      Offset(
        (logicalSize - painter.width) / 2,
        (logicalSize - painter.height) / 2,
      ),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (logicalSize * pixelRatio).round(),
      (logicalSize * pixelRatio).round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Builder(
        builder: (buttonContext) => IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: iconColor ?? mainText(buttonContext)),
          onPressed: () => _show(buttonContext),
        ),
      );
}
