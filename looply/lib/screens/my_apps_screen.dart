import 'package:flutter/material.dart';

import '../theme.dart';

/// Espaço reservado para as aplicações do utilizador.
/// A tela permanece vazia até o utilizador adicionar aplicações.
class MyAppsScreen extends StatelessWidget {
  const MyAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        backgroundColor: pageBg(context),
        elevation: 0,
        title: const Text('My Apps'),
      ),
      body: const SizedBox.expand(),
    );
  }
}
