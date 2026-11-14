// ══════════════════════════════════════════════════════════════
// FILE: lib/core/navigation/app_page_route.dart
// ══════════════════════════════════════════════════════════════
//
// Rota de navegação nativa customizada:
//  - Fade curto e suave, seguindo a transição de navegação do BrowseIt.
//  - Sem deslocamento horizontal nem parallax do CupertinoPageRoute.
//  - Sem glow de overscroll do Android (tratado à parte via
//    AppScrollBehavior, aplicado uma única vez no MaterialApp).
//  - PopScope(canPop: true) explícito em cada rota: garante que o
//    gesto/botão de voltar do Android nunca é interceptado por esta
//    rota, sempre fazendo pop natural para a tela anterior.
//
// Uso:
//   Navigator.of(context).push(AppPageRoute(builder: (_) => const Foo()));

import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    this.fullscreenDialog = false,
    Duration duration = const Duration(milliseconds: 260),
    Duration reverseDuration = const Duration(milliseconds: 200),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => PopScope(
            canPop: true,
            child: builder(context),
          ),
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          opaque: true,
          barrierDismissible: false,
          transitionsBuilder: _buildTransition,
        );

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  final bool fullscreenDialog;

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(opacity: curved, child: child);
  }
}

// ── ScrollBehavior sem glow de overscroll ──────────────────────
//
// Aplicar uma única vez no MaterialApp:
//   MaterialApp(scrollBehavior: const AppScrollBehavior(), ...)
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}