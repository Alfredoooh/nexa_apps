import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
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
    this.url,
  });

  final String title;
  final String category;
  final String players;
  final Color artColor;
  final int index;
  final String description;
  final String? url;
}

const List<LooplyGame> looplyGames = [
  LooplyGame(
    title: 'Zombie Rush',
    category: 'Ação',
    players: '—',
    artColor: Color(0xFF1D76D2),
    index: 0,
    description: 'Sobrevive à horda de zombies nesta experiência jogável diretamente na app.',
    url: 'https://raw.githubusercontent.com/CoolDude2349/Offline-HTML-Games-Pack/refs/heads/master/offline/zombie-rush.html',
  ),
];

class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});

  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> {
  int _selectedTab = 0;

  void _openGame(LooplyGame game) {
    if (game.url == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameWebViewScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onGameTap: _openGame),
      const EmptyTabScreen(title: 'Explorar'),
      const EmptyTabScreen(title: 'Criar'),
      const EmptyTabScreen(title: 'Perfil'),
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
          NavigationDestination(icon: Icon(Symbols.home_rounded), selectedIcon: Icon(Symbols.home_rounded, fill: 1), label: 'Início'),
          NavigationDestination(icon: Icon(Symbols.explore_rounded), selectedIcon: Icon(Symbols.explore_rounded, fill: 1), label: 'Explorar'),
          NavigationDestination(icon: Icon(Symbols.add_box_rounded), selectedIcon: Icon(Symbols.add_box_rounded, fill: 1), label: 'Criar'),
          NavigationDestination(icon: Icon(Symbols.person_rounded), selectedIcon: Icon(Symbols.person_rounded, fill: 1), label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onGameTap});

  final ValueChanged<LooplyGame> onGameTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          const LooplySearchBox(showFilterIcon: true),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: looplyGames.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 15,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final game = looplyGames[index];
              return GameCard(game: game, onTap: () => onGameTap(game));
            },
          ),
        ],
      ),
    );
  }
}

class EmptyTabScreen extends StatelessWidget {
  const EmptyTabScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: const SizedBox.shrink(),
    );
  }
}

class LooplySearchBox extends StatefulWidget {
  const LooplySearchBox({
    super.key,
    this.showFilterIcon = false,
  });

  final bool showFilterIcon;

  @override
  State<LooplySearchBox> createState() => _LooplySearchBoxState();
}

class _LooplySearchBoxState extends State<LooplySearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Pesquisar jogos',
        prefixIcon: const Icon(Symbols.search_rounded, color: looplyMuted),
        suffixIcon: widget.showFilterIcon
            ? const Icon(Symbols.tune_rounded, color: looplyMuted)
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});
  final LooplyGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: looplyPanel,
      borderRadius: BorderRadius.circular(24),
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
                        decoration: BoxDecoration(color: const Color(0xCC0B0D11), borderRadius: BorderRadius.circular(10)),
                        child: Text(game.category.toUpperCase(), style: const TextStyle(fontSize: 8, letterSpacing: 0.5, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const Positioned(
                      right: 9, bottom: 9,
                      child: Icon(Symbols.play_circle_rounded, fill: 1, color: Colors.white, size: 29),
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
                      const Icon(Symbols.circle_rounded, fill: 1, size: 5, color: Color(0xFF50D890)),
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

class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key, required this.game});
  final LooplyGame game;

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.title),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.game.url!)),
            onLoadStart: (controller, url) {
              setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              setState(() => _isLoading = false);
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: looplyBlue),
            ),
        ],
      ),
    );
  }
}