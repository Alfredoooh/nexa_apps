import 'package:flutter/material.dart';

import '../theme.dart';

/// Ecrã Descobrir reservado para conteúdo futuro.
/// Por enquanto mantém apenas o título, sem listas, notícias ou ações.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: const Text('Descobrir'),
      ),
      body: const SizedBox.expand(),
    );
  }
}
