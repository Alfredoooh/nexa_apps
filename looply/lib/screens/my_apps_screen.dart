import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';

/// My Apps apresenta apenas ícones circulares, sem legendas nem cartões largos.
class MyAppsScreen extends StatelessWidget {
  const MyAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = quickSites.where((site) => site.name != 'Mais').toList(growable: false);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(title: const Text('My Apps')),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        itemCount: sites.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 14,
          mainAxisSpacing: 18,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final site = sites[index];
          return Center(
            child: Material(
              color: pillColor(context),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => openOrbitTab(context, site.url, title: site.name),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: site.assetPath != null
                        ? Image.asset(site.assetPath!, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Symbols.public_rounded, color: accentColor(context), size: 24))
                        : Icon(Symbols.public_rounded, color: accentColor(context), size: 24),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
