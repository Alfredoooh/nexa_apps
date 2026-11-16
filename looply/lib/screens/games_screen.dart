import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../localization.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';

const MethodChannel _nativeGameChannel = MethodChannel('looply/native_ui');

class _GameEntry {
  const _GameEntry({
    required this.title,
    required this.fileName,
    required this.icon,
  });

  final String title;
  final String fileName;
  final IconData icon;
}

// Dez jogos casuais e de puzzle existentes na pasta offline/ do repositório
// indicado. O código dos jogos não é copiado para o projeto: o WebView nativo
// carrega o HTML diretamente da origem, preservando a atribuição ao repositório.
const List<_GameEntry> _games = <_GameEntry>[
  _GameEntry(
    title: '2048',
    fileName: '2048.html',
    icon: AppIcons.squaresFour,
  ),
  _GameEntry(
    title: 'Wordle Unlimited',
    fileName: 'wordle-unlimited.html',
    icon: AppIcons.listChecks,
  ),
  _GameEntry(
    title: 'Doodle Jump',
    fileName: 'doodle-jump.html',
    icon: AppIcons.arrowUp,
  ),
  _GameEntry(
    title: 'Stack',
    fileName: 'stack.html',
    icon: AppIcons.squaresFour,
  ),
  _GameEntry(
    title: 'Candy Crush',
    fileName: 'candy-crush.html',
    icon: AppIcons.palette,
  ),
  _GameEntry(
    title: 'Idle Breakout',
    fileName: 'idle-breakout.html',
    icon: AppIcons.playCircle,
  ),
  _GameEntry(
    title: 'Google Baseball',
    fileName: 'google-baseball.html',
    icon: AppIcons.circleDot,
  ),
  _GameEntry(
    title: 'Chess',
    fileName: 'chess.html',
    icon: AppIcons.compass,
  ),
  _GameEntry(
    title: 'Table Tennis World Tour',
    fileName: 'table-tennis-world-tour.html',
    icon: AppIcons.globe,
  ),
  _GameEntry(
    title: 'Pac-Man',
    fileName: 'pac-man.html',
    icon: AppIcons.circle,
  ),
];

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String? _openingGame;

  Future<void> _openGame(_GameEntry game) async {
    if (_openingGame != null) return;
    setState(() => _openingGame = game.fileName);
    try {
      await _nativeGameChannel.invokeMethod<bool>('openGame', <String, Object>{
        'fileName': game.fileName,
        'title': game.title,
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? appText('game_open_failed'))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText('game_open_failed'))),
      );
    } finally {
      if (mounted) setState(() => _openingGame = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    AppBackButton(tooltip: appText('back')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appText('games'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: settingsCardColor(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '10',
                        style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 18),
              sliver: SliverToBoxAdapter(
                child: Text(
                  appText('games_intro'),
                  style: TextStyle(color: muted, fontSize: 13.5, height: 1.35),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
              sliver: SliverList.separated(
                itemCount: _games.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final game = _games[index];
                  final isOpening = _openingGame == game.fileName;
                  return _GameListCard(
                    game: game,
                    isOpening: isOpening,
                    accent: isDark ? const Color(0xFFB7C8FF) : const Color(0xFF356AC3),
                    onTap: () => _openGame(game),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Text(
                  appText('games_source_note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 11.5, height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameListCard extends StatelessWidget {
  const _GameListCard({
    required this.game,
    required this.isOpening,
    required this.accent,
    required this.onTap,
  });

  final _GameEntry game;
  final bool isOpening;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isOpening ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pillColor(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: AppMaterialIcon(game.icon, size: 24, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appText('tap_to_play'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12.5, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isOpening
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: accent,
                      ),
                    )
                  : AppMaterialIcon(AppIcons.arrowRight, color: muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
