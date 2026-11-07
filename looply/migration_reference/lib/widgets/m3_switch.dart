import 'package:flutter/material.dart';

/// Interruptor compacto alinhado ao tema Material 3 do Looply.
class M3ExpressiveSwitch extends StatelessWidget {
  const M3ExpressiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: const Color(0xFF2596BE),
      inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF42484D)
          : const Color(0xFFD9DEE2),
      inactiveThumbColor: Colors.white,
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF596168)
            : const Color(0xFFB9C0C5);
      }),
    );
  }
}
