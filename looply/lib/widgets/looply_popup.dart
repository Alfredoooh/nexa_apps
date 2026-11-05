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

/// No Android, os menus são desenhados com um PopupMenu nativo real
/// (androidx.appcompat.widget.PopupMenu), com a animação, elevação e ripple
/// do próprio sistema. O Flutter apenas envia os itens e os ícones.
class LooplyPopupMenuButton<T> extends StatelessWidget {
  const LooplyPopupMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip = 'Mais opções',
    this.icon = Symbols.more_vert_rounded,
    this.iconColor,
    this.menuWidth = 252,
    this.includeAiToggle = false,
    this.onAiToggleChanged,
  });

  final List<LooplyPopupAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;
  final Color? iconColor;
  final double menuWidth;

  /// Quando ativo, o popup inclui um item fixo no topo ("Pesquisa com IA")
  /// com um interruptor. No Android esse interruptor é nativo (SwitchCompat
  /// dentro de um actionView do PopupMenu); no fallback Flutter é desenhado
  /// com o mesmo componente usado na tela de Definições.
  final bool includeAiToggle;
  final ValueChanged<bool>? onAiToggleChanged;

  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');

  Future<void> _show(BuildContext buttonContext) async {
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize || actions.isEmpty) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final anchor = topLeft & renderObject.size;

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
              'left': anchor.left,
              'top': anchor.top,
              'right': anchor.right,
              'bottom': anchor.bottom,
              'width': anchor.width,
              'height': anchor.height,
            },
            'width': menuWidth,
            'items': nativeItems,
            'includeAiToggle': includeAiToggle,
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
        anchor.top,
        MediaQuery.sizeOf(buttonContext).width - anchor.right,
        MediaQuery.sizeOf(buttonContext).height - anchor.bottom,
      ),
      items: [
        if (includeAiToggle)
          PopupMenuItem<T>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: _AiToggleRow<T>(onChanged: onAiToggleChanged),
          ),
        ...actions.map(
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
        ),
      ],
    );
    if (selected != null) onSelected(selected);
  }


  Future<Uint8List?> _renderRoundedIcon(IconData icon, Color color) async {
    // 20 logical px coincide com o tamanho de ícone usado nos controlos Flutter.
    // A imagem é enviada em alta densidade e apresentada pelo Android num slot de 20 dp.
    const logicalSize = 20.0;
    const pixelRatio = 3.0;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: logicalSize,
          height: 1,
          fontWeight: FontWeight.w400,
          fontVariations: const <ui.FontVariation>[
            ui.FontVariation('wght', 400),
            ui.FontVariation('GRAD', -25),
            ui.FontVariation('FILL', 0),
          ],
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

/// Linha com o interruptor "Pesquisa com IA", usada apenas no fallback
/// Flutter (plataformas sem o PopupMenu nativo do Kotlin).
class _AiToggleRow<T> extends StatefulWidget {
  const _AiToggleRow({this.onChanged});

  final ValueChanged<bool>? onChanged;

  @override
  State<_AiToggleRow<T>> createState() => _AiToggleRowState<T>();
}

class _AiToggleRowState<T> extends State<_AiToggleRow<T>> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return InkWell(
      onTap: () {
        setState(() => _value = !_value);
        widget.onChanged?.call(_value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Symbols.auto_awesome_rounded, size: 20, color: muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Pesquisa com IA', style: TextStyle(color: text, fontSize: 14)),
            ),
            Switch.adaptive(
              value: _value,
              onChanged: (value) {
                setState(() => _value = value);
                widget.onChanged?.call(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}