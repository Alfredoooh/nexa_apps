import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LooplyApp());
}

const Color looplyBg = Color(0xFF0B0D11);
const Color looplyPanel = Color(0xFF151920);
const Color looplyPanel2 = Color(0xFF1B2028);
const Color looplyText = Color(0xFFF4F7FA);
const Color looplyMuted = Color(0xFF9AA4B2);
const Color looplyBlue = Color(0xFF05C8F2);
const Color looplyOrange = Color(0xFFFF7A20);

class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: looplyBlue,
      brightness: Brightness.dark,
      surface: looplyPanel,
    );
    return MaterialApp(
      title: 'Looply',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: looplyBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: looplyBg,
          foregroundColor: looplyText,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(color: looplyText, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: looplyText, fontWeight: FontWeight.w800),
          titleMedium: TextStyle(color: looplyText, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: looplyText),
          bodyMedium: TextStyle(color: looplyText),
          bodySmall: TextStyle(color: looplyMuted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: looplyPanel,
          hintStyle: const TextStyle(color: looplyMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF292F39)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: looplyBlue, width: 1.3),
          ),
        ),
      ),
      home: const LooplyShell(),
    );
  }
}

class LooplyGame {
  const LooplyGame({
    required this.title,
    required this.category,
    required this.players,
    required this.artColor,
    required this.index,
    required this.description,
  });

  final String title;
  final String category;
  final String players;
  final Color artColor;
  final int index;
  final String description;
}

const List<LooplyGame> looplyGames = [
  LooplyGame(
    title: 'Obby Rush', category: 'Obby', players: '8,4 mil',
    artColor: Color(0xFF1D76D2), index: 0,
    description: 'Corre, salta e supera percursos cheios de desafios.'),
  LooplyGame(
    title: 'Cidade Neon', category: 'Roleplay', players: '5,2 mil',
    artColor: Color(0xFF4B38A8), index: 1,
    description: 'Explora a cidade, conhece outros jogadores e cria a tua história.'),
  LooplyGame(
    title: 'Pet World', category: 'Simulação', players: '3,8 mil',
    artColor: Color(0xFF167F72), index: 2,
    description: 'Descobre criaturas, cuida dos teus animais e visita novos lugares.'),
  LooplyGame(
    title: 'Block Arena', category: 'Ação', players: '2,9 mil',
    artColor: Color(0xFFB84F2C), index: 3,
    description: 'Entra na arena e testa a tua estratégia em partidas rápidas.'),
  LooplyGame(
    title: 'Speed Legends', category: 'Corrida', players: '2,1 mil',
    artColor: Color(0xFF236E89), index: 4,
    description: 'Acelera, desbloqueia pistas e tenta chegar primeiro à meta.'),
  LooplyGame(
    title: 'Ilha Selvagem', category: 'Aventura', players: '1,7 mil',
    artColor: Color(0xFF497442), index: 5,
    description: 'Explora uma ilha cheia de segredos e recursos para descobrir.'),
  LooplyGame(
    title: 'Torre Impossível', category: 'Obby', players: '1,3 mil',
    artColor: Color(0xFF7852B7), index: 6,
    description: 'Sobe o mais alto que conseguires num percurso de precisão.'),
  LooplyGame(
    title: 'Mini Fazendas', category: 'Simulação', players: '920',
    artColor: Color(0xFF8A6E35), index: 7,
    description: 'Constrói a tua quinta, planta sementes e expande o teu terreno.'),
];

const List<String> gameCategories = [
  'Todos', 'Obby', 'Aventura', 'Roleplay', 'Simulação', 'Ação', 'Corrida'
];

class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});

  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> {
  int _selectedTab = 0;
  String _query = '';
  String _category = 'Todos';

  List<LooplyGame> get _filteredGames {
    final normalizedQuery = _query.trim().toLowerCase();
    return looplyGames.where((game) {
      final matchesQuery = normalizedQuery.isEmpty ||
          game.title.toLowerCase().contains(normalizedQuery) ||
          game.category.toLowerCase().contains(normalizedQuery);
      final matchesCategory = _category == 'Todos' || game.category == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  void _openGame(LooplyGame game) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameDetailsScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        games: _filteredGames,
        query: _query,
        category: _category,
        onQueryChanged: (value) => setState(() => _query = value),
        onCategoryChanged: (value) => setState(() => _category = value),
        onExploreTap: () => setState(() => _selectedTab = 1),
        onGameTap: _openGame,
      ),
      ExploreScreen(
        games: _filteredGames,
        query: _query,
        category: _category,
        onQueryChanged: (value) => setState(() => _query = value),
        onCategoryChanged: (value) => setState(() => _category = value),
        onGameTap: _openGame,
      ),
      const CreateScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedTab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: const Color(0xFF111419),
        indicatorColor: looplyBlue.withOpacity(0.16),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box_rounded), label: 'Criar'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.games,
    required this.query,
    required this.category,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onExploreTap,
    required this.onGameTap,
  });

  final List<LooplyGame> games;
  final String query;
  final String category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onExploreTap;
  final ValueChanged<LooplyGame> onGameTap;

  @override
  Widget build(BuildContext context) {
    final popular = games.take(4).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/looply_mark.png', width: 42, height: 42, fit: BoxFit.cover),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Looply', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                      SizedBox(height: 1),
                      Text('Joga. Cria. Explora.', style: TextStyle(color: looplyMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _showNotice(context, 'Notificações', 'As tuas notificações aparecerão aqui.'),
                  style: IconButton.styleFrom(backgroundColor: looplyPanel, foregroundColor: looplyText),
                  icon: const Icon(Icons.notifications_none_rounded),
                  tooltip: 'Notificações',
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: LooplySearchBox(
              value: query,
              onChanged: onQueryChanged,
              showFilterIcon: true,
            ),
          ),
        ),
        if (query.isEmpty && category == 'Todos') ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeading(title: 'Em destaque', actionLabel: 'Ver todos', onAction: onExploreTap),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
              child: FeaturedGameCard(onTap: () => onGameTap(looplyGames[0])),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SectionHeading(
              title: query.isEmpty ? 'Explora por categoria' : 'Resultados',
              actionLabel: query.isEmpty ? '' : 'Limpar',
              onAction: query.isEmpty ? null : () => onQueryChanged(''),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              scrollDirection: Axis.horizontal,
              itemCount: gameCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = gameCategories[index];
                final active = category == item;
                return ChoiceChip(
                  label: Text(item),
                  selected: active,
                  onSelected: (_) => onCategoryChanged(item),
                  showCheckmark: false,
                  labelStyle: TextStyle(color: active ? looplyBg : looplyText, fontWeight: FontWeight.w700, fontSize: 12),
                  selectedColor: looplyBlue,
                  backgroundColor: looplyPanel,
                  side: BorderSide(color: active ? looplyBlue : const Color(0xFF292F39)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 13),
            child: _SectionHeading(title: query.isEmpty ? 'Populares agora' : 'Jogos encontrados', actionLabel: 'Ver todos', onAction: onExploreTap),
          ),
        ),
        if (popular.isEmpty)
          const SliverToBoxAdapter(child: _EmptyResults())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => GameCard(game: popular[index], onTap: () => onGameTap(popular[index])),
                childCount: popular.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 15,
                childAspectRatio: 0.82,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
      ],
    );
  }
}

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({
    super.key,
    required this.games,
    required this.query,
    required this.category,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onGameTap,
  });

  final List<LooplyGame> games;
  final String query;
  final String category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<LooplyGame> onGameTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 25, 20, 4),
            child: Text('Explorar', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Text('Encontra a próxima experiência de que vais gostar.', style: TextStyle(color: looplyMuted, fontSize: 14)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: LooplySearchBox(value: query, onChanged: onQueryChanged),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: gameCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = gameCategories[index];
                final active = category == item;
                return ChoiceChip(
                  label: Text(item), selected: active, showCheckmark: false,
                  onSelected: (_) => onCategoryChanged(item),
                  selectedColor: looplyBlue, backgroundColor: looplyPanel,
                  side: BorderSide(color: active ? looplyBlue : const Color(0xFF292F39)),
                  labelStyle: TextStyle(color: active ? looplyBg : looplyText, fontWeight: FontWeight.w700, fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          sliver: games.isEmpty
              ? const SliverToBoxAdapter(child: _EmptyResults())
              : SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => GameCard(game: games[index], onTap: () => onGameTap(games[index])),
                    childCount: games.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 15, childAspectRatio: 0.82,
                  ),
                ),
        ),
      ],
    );
  }
}


class LooplySearchBox extends StatefulWidget {
  const LooplySearchBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.showFilterIcon = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool showFilterIcon;

  @override
  State<LooplySearchBox> createState() => _LooplySearchBoxState();
}

class _LooplySearchBoxState extends State<LooplySearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant LooplySearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Pesquisar jogos',
        prefixIcon: const Icon(Icons.search_rounded, color: looplyMuted),
        suffixIcon: widget.showFilterIcon
            ? const Icon(Icons.tune_rounded, color: looplyMuted)
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}

class FeaturedGameCard extends StatelessWidget {
  const FeaturedGameCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF14374A),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 204,
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: FeaturedArtPainter())),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: looplyBlue, borderRadius: BorderRadius.circular(7)),
                        child: const Text('ESCOLHA DA SEMANA', style: TextStyle(fontSize: 9, color: looplyBg, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                      ),
                      const Spacer(),
                      const Text('Obby Rush', style: TextStyle(fontSize: 25, height: 1.05, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 5),
                      const Text('Salta. Corre. Chega ao topo.', style: TextStyle(fontSize: 12, color: Color(0xFFE1F7FF))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 5),
                          const Text('8,4 mil a jogar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: looplyOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedArtPainter extends CustomPainter {
  const FeaturedArtPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    p.color = const Color(0xFF15506C);
    canvas.drawRect(Offset.zero & size, p);
    p.color = const Color(0xFF1A6B8B);
    canvas.drawCircle(Offset(size.width * .86, size.height * .25), size.height * .31, p);
    p.color = const Color(0xFF0E455E);
    canvas.drawRect(Rect.fromLTWH(size.width * .54, size.height * .65, size.width * .56, size.height * .45), p);
    p.color = const Color(0xFF26B8D5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .61, size.height * .31, size.width * .13, size.height * .25), const Radius.circular(8)), p);
    p.color = const Color(0xFFFF7A20);
    final path = Path()
      ..moveTo(size.width * .88, size.height * .48)
      ..lineTo(size.width * .97, size.height * .64)
      ..lineTo(size.width * .79, size.height * .64)
      ..close();
    canvas.drawPath(path, p);
    p.color = const Color(0xFF0B2C3B);
    canvas.drawRect(Rect.fromLTWH(size.width * .70, size.height * .76, size.width * .12, size.height * .24), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});
  final LooplyGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: looplyPanel,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: GameArtPainter(game: game)),
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xCC0B0D11), borderRadius: BorderRadius.circular(7)),
                        child: Text(game.category.toUpperCase(), style: const TextStyle(fontSize: 8, letterSpacing: 0.5, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const Positioned(
                      right: 9, bottom: 9,
                      child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 29),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 12, color: looplyMuted),
                      const SizedBox(width: 4),
                      Text(game.players, style: const TextStyle(fontSize: 10, color: looplyMuted)),
                      const Spacer(),
                      const Icon(Icons.circle, size: 5, color: Color(0xFF50D890)),
                      const SizedBox(width: 4),
                      const Text('Online', style: TextStyle(fontSize: 10, color: looplyMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    switch (game.index % 4) {
      case 0:
        p.color = const Color(0xFF56D8EB);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .18, size.height * .34, size.width * .23, size.height * .36), const Radius.circular(7)), p);
        p.color = const Color(0xFFFF7A20);
        canvas.drawRect(Rect.fromLTWH(size.width * .47, size.height * .47, size.width * .20, size.height * .22), p);
        p.color = const Color(0xFF183C82);
        canvas.drawRect(Rect.fromLTWH(size.width * .35, size.height * .70, size.width * .20, size.height * .16), p);
        break;
      case 1:
        p.color = const Color(0xFFFA8D45);
        canvas.drawCircle(Offset(size.width * .31, size.height * .38), size.width * .13, p);
        p.color = const Color(0xFF3BC4D6);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .48, size.height * .36, size.width * .24, size.height * .32), const Radius.circular(10)), p);
        p.color = const Color(0xFF20174E);
        canvas.drawRect(Rect.fromLTWH(size.width * .19, size.height * .72, size.width * .62, size.height * .13), p);
        break;
      case 2:
        p.color = const Color(0xFF8CE6A8);
        canvas.drawCircle(Offset(size.width * .35, size.height * .45), size.width * .16, p);
        p.color = const Color(0xFFFFD16A);
        canvas.drawCircle(Offset(size.width * .59, size.height * .51), size.width * .12, p);
        p.color = const Color(0xFF1A5B50);
        canvas.drawRect(Rect.fromLTWH(size.width * .14, size.height * .71, size.width * .72, size.height * .15), p);
        break;
      default:
        p.color = const Color(0xFFFFD15C);
        final path = Path()
          ..moveTo(size.width * .50, size.height * .25)
          ..lineTo(size.width * .72, size.height * .67)
          ..lineTo(size.width * .28, size.height * .67)
          ..close();
        canvas.drawPath(path, p);
        p.color = const Color(0xFF30264A);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .41, size.height * .48, size.width * .18, size.height * .31), const Radius.circular(6)), p);
    }
  }

  @override
  bool shouldRepaint(covariant GameArtPainter oldDelegate) => oldDelegate.game.index != game.index;
}

class GameDetailsScreen extends StatelessWidget {
  const GameDetailsScreen({super.key, required this.game});
  final LooplyGame game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Detalhes do jogo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(height: 230, child: CustomPaint(painter: GameArtPainter(game: game), child: const SizedBox.expand())),
          ),
          const SizedBox(height: 20),
          Text(game.title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoPill(icon: Icons.category_outlined, text: game.category),
            _InfoPill(icon: Icons.people_alt_outlined, text: '${game.players} jogadores'),
            const _InfoPill(icon: Icons.circle, text: 'Online', dotColor: Color(0xFF50D890)),
          ]),
          const SizedBox(height: 22),
          const Text('Sobre este jogo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(game.description, style: const TextStyle(color: looplyMuted, height: 1.5, fontSize: 14)),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: () => _showNotice(context, 'Jogo de demonstração', 'Esta versão do Looply contém a interface inicial. A ligação a jogos reais e servidores multiplayer ainda precisa de ser desenvolvida.'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Jogar agora'),
            style: FilledButton.styleFrom(backgroundColor: looplyBlue, foregroundColor: looplyBg, minimumSize: const Size.fromHeight(54), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, this.dotColor});
  final IconData icon;
  final String text;
  final Color? dotColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: looplyPanel, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: dotColor ?? looplyMuted),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
      children: [
        const Text('Cria no Looply', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
        const SizedBox(height: 7),
        const Text('A tua próxima ideia pode tornar-se um mundo.', style: TextStyle(color: looplyMuted, fontSize: 14)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: looplyPanel, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF292F39))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 58, height: 58, decoration: BoxDecoration(color: looplyBlue.withOpacity(.14), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.view_in_ar_rounded, color: looplyBlue, size: 30)),
            const SizedBox(height: 17),
            const Text('O teu próprio mundo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Imagina cenários, constrói níveis e prepara uma experiência para partilhar com outros jogadores.', style: TextStyle(color: looplyMuted, height: 1.5, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _showNotice(context, 'Editor de mundos', 'O editor 3D ainda não está implementado. Este espaço está preparado para receber as ferramentas de criação numa próxima etapa.'),
              icon: const Icon(Icons.add_rounded), label: const Text('Novo mundo'),
              style: FilledButton.styleFrom(backgroundColor: looplyBlue, foregroundColor: looplyBg, minimumSize: const Size.fromHeight(50), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _FeatureRow(icon: Icons.extension_rounded, title: 'Blocos e objetos', subtitle: 'Constrói cenários com peças modulares.'),
        _FeatureRow(icon: Icons.groups_rounded, title: 'Joga com amigos', subtitle: 'Prepara experiências para vários jogadores.'),
        _FeatureRow(icon: Icons.rocket_launch_rounded, title: 'Publica a tua criação', subtitle: 'Partilha o teu mundo com a comunidade.'),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Container(width: 45, height: 45, decoration: BoxDecoration(color: looplyPanel2, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: looplyMuted)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: looplyMuted, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
      children: [
        const Text('Perfil', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: looplyPanel, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            Container(width: 82, height: 82, decoration: BoxDecoration(color: looplyPanel2, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFF343B46))), child: const Icon(Icons.person_rounded, size: 43, color: looplyMuted)),
            const SizedBox(height: 14),
            const Text('Joga como tu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Inicia sessão para guardar os teus jogos e ligações.', textAlign: TextAlign.center, style: TextStyle(color: looplyMuted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => _showNotice(context, 'Conta Looply', 'O registo e a autenticação ainda precisam de ser ligados a um serviço de contas.'),
              style: FilledButton.styleFrom(backgroundColor: looplyBlue, foregroundColor: looplyBg, minimumSize: const Size.fromHeight(50), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
              child: const Text('Entrar ou criar conta'),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _SettingsTile(icon: Icons.bookmark_border_rounded, title: 'Jogos guardados', onTap: () => _showNotice(context, 'Jogos guardados', 'Os teus jogos favoritos aparecerão aqui quando esta funcionalidade estiver ligada.')),
        _SettingsTile(icon: Icons.shield_outlined, title: 'Privacidade e segurança', onTap: () => _showNotice(context, 'Segurança', 'As opções de segurança e controlos de conta serão configurados nesta secção.')),
        _SettingsTile(icon: Icons.settings_outlined, title: 'Definições', onTap: () => _showNotice(context, 'Definições', 'As definições da aplicação serão adicionadas aqui.')),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: looplyPanel,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: looplyMuted),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          trailing: const Icon(Icons.chevron_right_rounded, color: looplyMuted),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.actionLabel, this.onAction});
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.25))),
      if (actionLabel.isNotEmpty)
        TextButton(onPressed: onAction, style: TextButton.styleFrom(foregroundColor: looplyBlue, visualDensity: VisualDensity.compact), child: Text(actionLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
    ]);
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(children: [
        const Icon(Icons.search_off_rounded, size: 38, color: looplyMuted),
        const SizedBox(height: 12),
        const Text('Nenhum jogo encontrado', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 6),
        const Text('Experimenta outro nome ou categoria.', style: TextStyle(color: looplyMuted, fontSize: 12)),
      ]),
    );
  }
}

void _showNotice(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: looplyPanel,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message, style: const TextStyle(color: looplyMuted, height: 1.45)),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar'))],
    ),
  );
}
