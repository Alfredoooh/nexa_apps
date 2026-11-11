import 'package:flutter/material.dart';

/// Rota com transição exclusivamente em fade (sem slide), usada para dar
/// uma sensação mais suave ao abrir a tela de pesquisa.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  FadePageRoute({required WidgetBuilder builder, super.settings})
      : super(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(opacity: curved, child: child);
          },
        );
}