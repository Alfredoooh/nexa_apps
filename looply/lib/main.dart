import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:animations/animations.dart';

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
const Color looplyBottomBar = Color(0xFF0D0F14);

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
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
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
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoSwipeBackCupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: NoSwipeBackCupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LooplyShell(),
    );
  }
}

/// Transição Cupertino nativa (slide horizontal), sem o gesto de
/// "arrastar para voltar" (swipe back desativado).
class NoSwipeBackCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoSwipeBackCupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}

/// Rota customizada equivalente ao CupertinoPageRoute, mas que bloqueia
/// o PopGestureDetector (sem slide to go back), usada nas navegações manuais.
class NoSwipeCupertinoPageRoute<T> extends PageRoute<T> {
  NoSwipeCupertinoPageRoute({
    required this.builder,
    RouteSettings? settings,
    this.maintainState = true,
  }) : super(settings: settings, fullscreenDialog: false);

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const GamesScreen(),
      const EmptyTabScreen(title: 'Criar'),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedTab, children: pages),
      ),
      bottomNavigationBar: LooplyBottomBar(
        selectedIndex: _selectedTab,
        onSelect: (index) => setState(() => _selectedTab = index),
      ),
    );
  }
}

/// Bottom bar customizado: sem feedback de splash/ripple ao trocar de tab,
/// com indicador "pill" no item selecionado, cor quase igual ao fundo do app.
class LooplyBottomBar extends StatelessWidget {
  const LooplyBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (icon: Symbols.home_rounded, label: 'Início'),
    (icon: Symbols.sports_esports_rounded, label: 'Jogos'),
    (icon: Symbols.add_box_rounded, label: 'Criar'),
    (icon: Symbols.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10, top: 10),
      decoration: const BoxDecoration(
        color: looplyBottomBar,
        border: Border(top: BorderSide(color: Color(0xFF13161B), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(index),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? looplyBlue.withOpacity(0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        fill: selected ? 1 : 0,
                        color: selected ? looplyBlue : looplyMuted,
                        size: 23,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: selected
                            ? Padding(
                                padding: const EdgeInsets.only(left: 7),
                                child: Text(
                                  item.label,
                                  style: const TextStyle(
                                    color: looplyBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// AppBar da Home: sem título, com a search box embutida.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const LooplySearchBox(showFilterIcon: true),
        titleSpacing: 16,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
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
              return GameCard(game: game);
            },
          ),
        ],
      ),
    );
  }
}

/// Aba "Jogos" (antiga "Explorar"), com o jogo listado.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text('Jogos'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
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
              return GameCard(game: game);
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

/// Search box que, ao ser tocada, abre a tela de pesquisa usando
/// Container Transform nativo (OpenContainer do pacote animations).
class LooplySearchBox extends StatelessWidget {
  const LooplySearchBox({
    super.key,
    this.showFilterIcon = false,
  });

  final bool showFilterIcon;

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 400),
      closedElevation: 0,
      openElevation: 0,
      closedColor: looplyPanel,
      openColor: looplyBg,
      middleColor: looplyPanel,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      closedBuilder: (context, openContainer) {
        return InkWell(
          onTap: openContainer,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: looplyPanel,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const Icon(Symbols.search_rounded, color: looplyMuted, size: 21),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pesquisar jogos',
                    style: TextStyle(color: looplyMuted, fontSize: 14),
                  ),
                ),
                if (showFilterIcon)
                  const Icon(Symbols.tune_rounded, color: looplyMuted, size: 19),
              ],
            ),
          ),
        );
      },
      openBuilder: (context, closeContainer) {
        return SearchScreen(onClose: closeContainer);
      },
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: looplyBg,
      appBar: AppBar(
        toolbarHeight: 68,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: widget.onClose,
        ),
        title: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: looplyPanel,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              const Icon(Symbols.search_rounded, color: looplyMuted, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: looplyText, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar jogos',
                    hintStyle: TextStyle(color: looplyMuted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Resultados para "${_controller.text}"',
          style: const TextStyle(color: looplyMuted),
        ),
      ),
    );
  }
}

/// Card do jogo: ao tocar, abre o InAppWebView direto via Container Transform.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game});
  final LooplyGame game;

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 420),
      closedElevation: 0,
      openElevation: 0,
      closedColor: looplyPanel,
      openColor: looplyBg,
      middleColor: looplyPanel,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      closedBuilder: (context, openContainer) {
        return Material(
          color: looplyPanel,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: game.url == null ? null : openContainer,
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
      },
      openBuilder: (context, closeContainer) {
        return GameWebViewScreen(game: game, onClose: closeContainer);
      },
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

/// Tela do jogo: corre o InAppWebView diretamente (sem exibir HTML cru),
/// com indicador de carregamento nativo.
class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key, required this.game, required this.onClose});
  final LooplyGame game;
  final VoidCallback onClose;

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: looplyBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: widget.onClose,
        ),
        title: Text(widget.game.title),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.game.url!)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
            ),
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

/// Aba de Perfil: capa com gradiente + avatar sobreposto (estilo da imagem),
/// com as cores do app, e popup menu no topo (Settings, Theme, Idioma).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
      color: looplyPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: const [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Symbols.settings_rounded, color: looplyText, size: 19),
              SizedBox(width: 10),
              Text('Settings', style: TextStyle(color: looplyText)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(Symbols.dark_mode_rounded, color: looplyText, size: 19),
              SizedBox(width: 10),
              Text('Theme', style: TextStyle(color: looplyText)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'idiom',
          child: Row(
            children: [
              Icon(Symbols.language_rounded, color: looplyText, size: 19),
              SizedBox(width: 10),
              Text('Idioma', style: TextStyle(color: looplyText)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: looplyBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 210,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [looplyBlue, Color(0xFF6A5BD6), looplyPanel],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 6,
                  right: 12,
                  child: Builder(
                    builder: (menuContext) {
                      return IconButton(
                        icon: const Icon(Symbols.more_vert_rounded, color: Colors.white),
                        onPressed: () {
                          final box = menuContext.findRenderObject() as RenderBox;
                          final position = box.localToGlobal(Offset(box.size.width, box.size.height));
                          _openMenu(context, position);
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: -46,
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: looplyBg, width: 4),
                      color: looplyPanel2,
                    ),
                    child: const Icon(Symbols.person_rounded, color: looplyMuted, size: 42),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Utilizador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: looplyText)),
                  SizedBox(height: 4),
                  Text('@utilizador', style: TextStyle(fontSize: 13, color: looplyMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}