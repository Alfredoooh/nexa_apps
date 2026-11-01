import 'package:flutter/material.dart';

import '../theme.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: pageBg(context),
        body: const SizedBox.expand(),
      );
}
