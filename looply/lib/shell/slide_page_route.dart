import 'package:material_ui/material_ui.dart';

/// Horizontal slide route used by screens opened from Activity and Settings.
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required WidgetBuilder builder, super.settings})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(.12, 0),
              end: Offset.zero,
            ).animate(curved);
            return SlideTransition(position: slide, child: child);
          },
        );
}
