import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

// Thumb recentrado verticalmente dentro da track em todos os estados.
// O centro vertical é calculado a partir da altura real disponível
// dentro do border (que antes era ignorada no cálculo).
class M3ExpressiveSwitch extends StatelessWidget {
  const M3ExpressiveSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _trackHeight = 32;
  static const double _trackWidth = 52;
  static const double _borderWidth = 2;
  static const double _thumbOn = 24;
  static const double _thumbOff = 16;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor(context);
    final outline = isDark ? const Color(0xFF938F99) : const Color(0xFF79747E);
    final offThumb = outline;
    final onThumb = isDark ? const Color(0xFF17181A) : Colors.white;

    final innerHeight = _trackHeight - (_borderWidth * 2);
    final innerWidth = _trackWidth - (_borderWidth * 2);
    final thumbSize = value ? _thumbOn : _thumbOff;
    final topOffset = _borderWidth + (innerHeight - thumbSize) / 2;
    final leftOffsetOn = _borderWidth + (innerWidth - thumbSize);
    final leftOffsetOff = _borderWidth + (innerHeight - _thumbOff) / 2;
    final leftOffset = value ? leftOffsetOn : leftOffsetOff;

    return Semantics(
      label: 'Ativar ou desativar opção',
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: _trackWidth,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: const Cubic(0.2, 0, 0, 1),
              width: _trackWidth,
              height: _trackHeight,
              decoration: BoxDecoration(
                color: value ? accent : Colors.transparent,
                border: Border.all(color: value ? accent : outline, width: _borderWidth),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(clipBehavior: Clip.none, children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: const Cubic(0.34, 1.4, 0.4, 1),
                  left: leftOffset,
                  top: topOffset,
                  width: thumbSize,
                  height: thumbSize,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: const Cubic(0.2, 0, 0, 1),
                    decoration: BoxDecoration(color: value ? onThumb : offThumb, shape: BoxShape.circle),
                    child: AnimatedOpacity(
                      opacity: value ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Symbols.check_rounded, color: accent, size: 15),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
