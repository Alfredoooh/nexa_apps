import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../localization.dart';
import '../theme.dart';

/// Shared menu control used by Home and AI Search.
/// Uses the exact regular SVG already used by the Home toolbar.
class LooplyDrawerMenuButton extends StatelessWidget {
  const LooplyDrawerMenuButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = mainText(context);
    return Semantics(
      button: true,
      label: appText('open_menu'),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/svg/regular/menu-options.svg',
                width: 23,
                height: 23,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
