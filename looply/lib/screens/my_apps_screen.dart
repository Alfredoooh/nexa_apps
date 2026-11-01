import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme.dart';
import '../session_store.dart';
import 'games_screen.dart';

/// Sinaliza à Shell que o modal está aberto para empurrar a tela anterior.
/// O sheet usa a rota nativa do showModalBottomSheet: entra por baixo e sai
/// pelo mesmo percurso, sem fade no conteúdo.
final ValueNotifier<bool> myAppsModalOpen = ValueNotifier<bool>(false);

Future<void> openMyAppsAndGames(
  BuildContext context, {
  bool persistActivity = true,
  Map<String, dynamic>? returnTo,
}) async {
  final previous = returnTo ??
      await SessionStore.instance.getLastActivity() ??
      <String, dynamic>{'type': 'shell', 'screenIndex': 0};

  if (persistActivity) {
    await SessionStore.instance.saveLastActivity({
      'type': 'my_apps',
      'returnTo': previous,
    });
  }
  if (!context.mounted) {
    await SessionStore.instance.saveLastActivity(previous);
    return;
  }

  myAppsModalOpen.value = true;
  try {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.28),
      elevation: 0,
      showDragHandle: true,
      routeSettings: const RouteSettings(name: '/my-apps-games'),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * .88;
        return SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Material(
              color: pageBg(sheetContext),
              surfaceTintColor: Colors.transparent,
              child: const MyAppsScreen(),
            ),
          ),
        );
      },
    );
  } finally {
    myAppsModalOpen.value = false;
    await SessionStore.instance.saveLastActivity(previous);
  }
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
        backgroundColor: Colors.transparent,
        flexibleSpace: appBarSoftFade(context),
        surfaceTintColor: Colors.transparent,
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
