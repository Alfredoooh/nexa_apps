import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:animations/animations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge real: deixa status bar e navigation bar transparentes,
  // sem o Android pintar um overlay escuro por cima.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LooplyApp());
}

const Color looplyBgDark = Color(0xFF0B0D11);
const Color looplyPanelDark = Color(0xFF151920);
const Color looplyPanel2Dark = Color(0xFF1B2028);
const Color looplyBottomBarDark = Color(0xFF0D0F14);

const Color looplyBgLight = Color(0xFFF5F7FA);
const Color looplyPanelLight = Color(0xFFFFFFFF);
const Color looplyPanel2Light = Color(0xFFE9EDF2);
const Color looplyBottomBarLight = Color(0xFFFFFFFF);

const Color looplyTextDark = Color(0xFFF4F7FA);
const Color looplyMutedDark = Color(0xFF9AA4B2);
const Color looplyTextLight = Color(0xFF14181F);
const Color looplyMutedLight = Color(0xFF5C6572);

const Color looplyBlue = Color(0xFF05C8F2);
const Color looplyOrange = Color(0xFFFF7A20);

/// Controlador de tema global, real: muda o MaterialApp inteiro ao vivo.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  void setMode(ThemeMode mode) => value = mode;

  void toggle() {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final ThemeController themeController = ThemeController();

class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: looplyBlue,
      brightness: brightness,
      surface: panel,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Garante que a status bar herde o estilo certo por trás de cada AppBar.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: looplyBottomBarDark,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: looplyBottomBarLight,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(color: text, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        hintStyle: TextStyle(color: muted),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Looply',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const LooplyShell(),
        );
      },
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

/// Rota customizada equivalente ao CupertinoPageRoute, sem swipe-to-go-back,
/// usada para navegações manuais (Navigator.push direto).
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

    // Scaffold raiz único: body + bottomNavigationBar no mesmo nível,
    // garantindo que o bottom bar fique ancorado ao fundo real da tela.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedTab, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: LooplyBottomBar(
          selectedIndex: _selectedTab,
          onSelect: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }
}

/// Bottom bar customizado: altura FIXA (corrige o bug de colapso/flutuação),
/// sem splash/ripple ao trocar de tab, indicador "pill" no item selecionado,
/// cor adaptada ao tema ativo.
class LooplyBottomBar extends StatelessWidget {
  const LooplyBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const double _barHeight = 64;

  static const _items = [
    (icon: Symbols.home_rounded, label: 'Início'),
    (icon: Symbols.sports_esports_rounded, label: 'Jogos'),
    (icon: Symbols.add_box_rounded, label: 'Criar'),
    (icon: Symbols.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? looplyBottomBarDark : looplyBottomBarLight;
    final borderColor = isDark ? const Color(0xFF13161B) : const Color(0xFFE4E8EE);
    final mutedColor = isDark ? looplyMutedDark : looplyMutedLight;

    return Container(
      height: _barHeight,
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
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
                        color: selected ? looplyBlue : mutedColor,
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

/// Aba "Jogos", com o jogo listado.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 400),
      closedElevation: 0,
      openElevation: 0,
      closedColor: panel,
      openColor: bg,
      middleColor: panel,
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
              color: panel,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Icon(Symbols.search_rounded, color: muted, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pesquisar jogos',
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                ),
                if (showFilterIcon)
                  Icon(Symbols.tune_rounded, color: muted, size: 19),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return Scaffold(
      backgroundColor: bg,
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
            color: panel,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(Symbols.search_rounded, color: muted, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar jogos',
                    hintStyle: TextStyle(color: muted, fontSize: 14),
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
          style: TextStyle(color: muted),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 420),
      closedElevation: 0,
      openElevation: 0,
      closedColor: panel,
      openColor: bg,
      middleColor: panel,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      closedBuilder: (context, openContainer) {
        return Material(
          color: panel,
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
                      Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: text)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Symbols.circle_rounded, fill: 1, size: 5, color: Color(0xFF50D890)),
                          const SizedBox(width: 4),
                          Text('Online', style: TextStyle(fontSize: 10, color: muted)),
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

/// Tela do jogo: corre o InAppWebView diretamente, com loading nativo.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;

    return Scaffold(
      backgroundColor: bg,
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

/// Aba de Perfil: capa com gradiente + avatar sobreposto, popup menu
/// no topo com Settings, Theme (real) e Idioma.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openMenu(BuildContext context, Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
      color: panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Symbols.settings_rounded, color: text, size: 19),
              const SizedBox(width: 10),
              Text('Settings', style: TextStyle(color: text)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            children: [
              Icon(Symbols.dark_mode_rounded, color: text, size: 19),
              const SizedBox(width: 10),
              Text('Theme', style: TextStyle(color: text)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'idiom',
          child: Row(
            children: [
              Icon(Symbols.language_rounded, color: text, size: 19),
              const SizedBox(width: 10),
              Text('Idioma', style: TextStyle(color: text)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'theme') {
        _showThemeSheet(context);
      }
      // 'settings' e 'idiom' ainda sem tela própria — me diz o que deve abrir em cada um.
    });
  }

  void _showThemeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Row(
                        children: [
                          Text('Tema', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: mode,
                      activeColor: looplyBlue,
                      title: Text('Claro', style: TextStyle(color: text)),
                      onChanged: (value) {
                        if (value != null) themeController.setMode(value);
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: mode,
                      activeColor: looplyBlue,
                      title: Text('Escuro', style: TextStyle(color: text)),
                      onChanged: (value) {
                        if (value != null) themeController.setMode(value);
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: mode,
                      activeColor: looplyBlue,
                      title: Text('Automático (sistema)', style: TextStyle(color: text)),
                      onChanged: (value) {
                        if (value != null) themeController.setMode(value);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel2 = isDark ? looplyPanel2Dark : looplyPanel2Light;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return Scaffold(
      backgroundColor: bg,
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
                      colors: [looplyBlue, Color(0xFF6A5BD6), looplyPanelDark],
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
                      border: Border.all(color: bg, width: 4),
                      color: panel2,
                    ),
                    child: Icon(Symbols.person_rounded, color: muted, size: 42),
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
                children: [
                  Text('Utilizador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: text)),
                  const SizedBox(height: 4),
                  Text('@utilizador', style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}