import 'package:material_ui/material_ui.dart';

/// Navegação push lateral: a página atual desloca-se para a esquerda enquanto
/// a nova página entra pela direita, em vez de animar apenas o conteúdo novo.
class LooplyPushPageRoute<T> extends PageRouteBuilder<T> {
  LooplyPushPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final incoming = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            final outgoing = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-.18, 0),
            ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: outgoing,
              child: SlideTransition(position: incoming, child: child),
            );
          },
        );
}
