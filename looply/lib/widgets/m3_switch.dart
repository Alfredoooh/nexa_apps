import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Wrapper público mantido para não alterar as chamadas existentes do app;
/// o controlo visual agora é o componente Material 3 Expressive verdadeiro.
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
    return M3ESwitch(
      value: value,
      selectedIcon: const Icon(M3EIcons.check),
      onChanged: onChanged,
    );
  }
}
