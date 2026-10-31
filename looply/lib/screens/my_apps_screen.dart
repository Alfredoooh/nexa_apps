import 'package:flutter/material.dart';

import '../theme.dart';

class MyAppsScreen extends StatelessWidget {
  const MyAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: const Text('My Apps'),
        backgroundColor: pageBg(context),
        elevation: 0,
      ),
    );
  }
}
