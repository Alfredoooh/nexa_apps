import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';

/// Abre My Apps & Games com uma transição vertical nativa e reversível.
/// Ao fechar, a página desliza para baixo com a mesma curva suave.
void openMyAppsAndGames(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => const MyAppsScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  ));
}

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        backgroundColor: pageBg(context),
        elevation: 0,
        title: const Text('My Apps & Games'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: _AppsGamesSlideTab(
              selectedIndex: _selected,
              onChanged: (index) => setState(() => _selected = index),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _selected == 0 ? 'Ainda sem aplicações' : 'Ainda sem jogos',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cápsula com indicador que desliza entre Apps e Games.
class _AppsGamesSlideTab extends StatelessWidget {
  const _AppsGamesSlideTab({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Container(
      width: 224,
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(99),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            AnimatedAlign(
              alignment: selectedIndex == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              child: Container(
                width: constraints.maxWidth / 2,
                height: constraints.maxHeight,
                decoration: BoxDecoration(
                  color: settingsCardColor(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _AppsGamesSegmentLabel(
                    label: 'Apps',
                    icon: Symbols.apps_rounded,
                    color: text,
                    onTap: () => onChanged(0),
                  ),
                ),
                Expanded(
                  child: _AppsGamesSegmentLabel(
                    label: 'Games',
                    icon: Symbols.sports_esports_rounded,
                    color: text,
                    onTap: () => onChanged(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppsGamesSegmentLabel extends StatelessWidget {
  const _AppsGamesSegmentLabel({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
