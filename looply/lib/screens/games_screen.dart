import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import 'game_webview_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final games = looplyGames;
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Row(children: [
                Expanded(child: Text('Jogos', style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.w800))),
                IconButton(tooltip: 'Pesquisar jogos', icon: Icon(Symbols.search_rounded, color: text), onPressed: () => showSearch<void>(context: context, delegate: _GameSearchDelegate(games))),
              ]),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  _GameCategoryChip(label: 'Para si', selected: true),
                  _GameCategoryChip(label: 'Em destaque'),
                  _GameCategoryChip(label: 'Ação'),
                  _GameCategoryChip(label: 'Jogos web'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Row(children: [
                Expanded(child: Text('Recomendado para si', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800))),
                Icon(Symbols.arrow_forward_rounded, color: muted),
              ]),
            ),
            ...games.map((game) => _RecommendedGameRow(game: game)),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Text('Em destaque', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800)),
            ),
            if (games.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FeaturedGameCard(game: games.first),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameCategoryChip extends StatelessWidget {
  const _GameCategoryChip({required this.label, this.selected = false});
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accentColor(context).withOpacity(.18) : pillColor(context),
            borderRadius: BorderRadius.circular(24),
            border: selected ? Border.all(color: accentColor(context).withOpacity(.6)) : null,
          ),
          child: Text(label, style: TextStyle(color: selected ? accentColor(context) : mainText(context), fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _RecommendedGameRow extends StatelessWidget {
  const _RecommendedGameRow({required this.game});
  final LooplyGame game;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 7, 18, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(width: 88, height: 88, child: CustomPaint(painter: GameArtPainter(game: game), child: const Center(child: Icon(Symbols.sports_esports_rounded, color: Colors.white, size: 32)))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(game.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 13, height: 1.3)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 5, children: [
              _GameMetaPill(label: game.category),
              const _GameMetaPill(label: 'Jogo web'),
            ]),
          ]))),
          const SizedBox(width: 4),
          Icon(Symbols.chevron_right_rounded, color: muted, size: 20),
        ]),
      ),
    );
  }
}

class _GameMetaPill extends StatelessWidget {
  const _GameMetaPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: mutedText(context), fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _FeaturedGameCard extends StatelessWidget {
  const _FeaturedGameCard({required this.game});
  final LooplyGame game;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Material(
      color: const Color(0xFF20202A),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 154, width: double.infinity, child: CustomPaint(painter: GameArtPainter(game: game), child: Stack(children: [
            Positioned(right: -12, top: -20, child: Container(width: 135, height: 135, decoration: const BoxDecoration(color: Color(0x55FFFFFF), shape: BoxShape.circle))),
            Positioned(left: 16, bottom: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: const Color(0xDD14151B), borderRadius: BorderRadius.circular(18)), child: const Text('JOGO EM DESTAQUE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4)))),
          ]))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game.title, style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Abra os detalhes e comece a jogar.', style: TextStyle(color: mutedText(context), fontSize: 12)),
            ])),
            Icon(Symbols.arrow_forward_rounded, color: text),
          ])),
        ]),
      ),
    );
  }
}

class _GameSearchDelegate extends SearchDelegate<void> {
  _GameSearchDelegate(this.games);
  final List<LooplyGame> games;
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Symbols.close_rounded), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);
  Widget _buildMatches(BuildContext context) {
    final matches = games.where((game) => game.title.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(children: matches.map((game) => ListTile(
      leading: SizedBox(width: 44, height: 44, child: CustomPaint(painter: GameArtPainter(game: game))),
      title: Text(game.title),
      subtitle: Text(game.category),
      onTap: () { close(context, null); Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game))); },
    )).toList());
  }
}

class GameDetailsScreen extends StatelessWidget {
  const GameDetailsScreen({super.key, required this.game});
  final LooplyGame game;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final bg = pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Detalhes do jogo')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 10, 18, 28), children: [
        ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(height: 220, child: CustomPaint(painter: GameArtPainter(game: game), child: const Center(child: Icon(Symbols.sports_esports_rounded, color: Colors.white, size: 70))))),
        const SizedBox(height: 20),
        Text(game.title, style: TextStyle(color: text, fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [_GameMetaPill(label: game.category), const _GameMetaPill(label: 'Jogo web')]),
        const SizedBox(height: 22),
        Text('Sobre este jogo', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(game.description, style: TextStyle(color: muted, fontSize: 15, height: 1.5)),
        const SizedBox(height: 16),
        Text('O jogo é aberto dentro do Looply através do navegador integrado.', style: TextStyle(color: muted, fontSize: 13, height: 1.4)),
      ]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: lineColor(context)))),
        child: SizedBox(height: 52, child: FilledButton.icon(
          onPressed: game.url == null ? null : () {
            activityController.log(ActivityKind.game, game.title, game.url!);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameWebViewScreen(game: game)));
          },
          icon: const Icon(Symbols.play_arrow_rounded),
          label: const Text('Jogar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        )),
      ),
    );
  }
}

class GameArtPainter extends CustomPainter {
  const GameArtPainter({required this.game});
  final LooplyGame game;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    p.color = game.artColor;
    canvas.drawRect(Offset.zero & size, p);
    p.color = Colors.white.withOpacity(.09);
    canvas.drawCircle(Offset(size.width * .82, size.height * .18), size.width * .23, p);
    p.color = Colors.black.withOpacity(.12);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .74, size.width, size.height * .26), p);
    p.color = const Color(0xFF56D8EB);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .18, size.height * .34, size.width * .23, size.height * .36), const Radius.circular(7)), p);
    p.color = const Color(0xFFFF7A20);
    canvas.drawRect(Rect.fromLTWH(size.width * .47, size.height * .47, size.width * .20, size.height * .22), p);
    p.color = const Color(0xFF183C82);
    canvas.drawRect(Rect.fromLTWH(size.width * .35, size.height * .70, size.width * .20, size.height * .16), p);
  }
  @override
  bool shouldRepaint(covariant GameArtPainter oldDelegate) => oldDelegate.game.index != game.index;
}
