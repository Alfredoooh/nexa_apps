import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';
import '../session_store.dart';
import 'games_screen.dart';

/// Abre My Apps & Games como uma tela normal usando a transição Cupertino.
/// A atividade anterior é restaurada quando o utilizador regressa.
Future<void> openMyAppsAndGames(
  BuildContext context, {
  bool persistActivity = true,
  Map<String, dynamic>? returnTo,
}) async {
  final navigator = Navigator.of(context);
  final previous = returnTo ??
      await SessionStore.instance.getLastActivity() ??
      <String, dynamic>{'type': 'shell', 'screenIndex': 0};

  if (persistActivity) {
    await SessionStore.instance.saveLastActivity({
      'type': 'my_apps',
      'returnTo': previous,
    });
  }

  if (!context.mounted || !navigator.mounted) {
    await SessionStore.instance.saveLastActivity(previous);
    return;
  }

  await navigator.push<void>(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/my-apps-games'),
      builder: (_) => const MyAppsScreen(),
    ),
  );

  await SessionStore.instance.saveLastActivity(previous);
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Apps & Games'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: _AppsGamesSlideTab(
                selectedIndex: _selected,
                onChanged: (index) => setState(() => _selected = index),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _selected == 0
                ? Center(
                    child: Text(
                      'Ainda sem aplicações',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  )
                : const GamesScreen(),
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
      width: 176,
      height: 40,
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
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
