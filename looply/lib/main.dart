import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LooplyApp());
}

// ============================================================
// CORES / TEMA
// ============================================================

const Color looplyPrimary = Color(0xFF5B4FE5);

const Color looplyBgDark = Color(0xFF1A1A1A);
const Color looplyBgLight = Color(0xFFFFFFFF);

const Color looplyPanelDark = Color(0xFF232323);
const Color looplyPanel2Dark = Color(0xFF2A2A2A);
const Color looplyPanelLight = Color(0xFFF4F4F4);
const Color looplyPanel2Light = Color(0xFFE9E9E9);

const Color looplyTextDark = Color(0xFFF4F7FA);
const Color looplyMutedDark = Color(0xFF9AA4B2);
const Color looplyTextLight = Color(0xFF14181F);
const Color looplyMutedLight = Color(0xFF5C6572);

const Color looplyOrange = Color(0xFFFF7A20);

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);
  void setMode(ThemeMode mode) => value = mode;
}

final ThemeController themeController = ThemeController();

// ============================================================
// AD BLOCK
// ============================================================

const Set<String> adBlockDomains = {
  'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
  'google-analytics.com', 'googletagmanager.com', 'googletagservices.com',
  'adservice.google.com', 'adsystem.com', 'amazon-adsystem.com',
  'facebook.net', 'connect.facebook.net', 'fbcdn.net', 'ads.facebook.com',
  'taboola.com', 'outbrain.com', 'criteo.com', 'criteo.net', 'adroll.com',
  'adnxs.com', 'rubiconproject.com', 'pubmatic.com', 'openx.net',
  'casalemedia.com', 'smartadserver.com', 'advertising.com', 'adform.net',
  'adtech.com', 'media.net', 'yieldmo.com', 'bidswitch.net',
  'contextweb.com', 'exoclick.com', 'popads.net', 'propellerads.com',
  'revcontent.com', 'mgid.com', 'zedo.com', 'adblade.com', 'adcolony.com',
  'applovin.com', 'chartboost.com', 'unityads.unity3d.com', 'vungle.com',
  'inmobi.com', 'mopub.com', 'scorecardresearch.com', 'quantserve.com',
  'hotjar.com', 'mixpanel.com', 'segment.io', 'segment.com',
  'amplitude.com', 'crazyegg.com', 'optimizely.com', 'newrelic.com',
  'nr-data.net', 'bugsnag.com', 'sentry.io', 'intercom.io', 'drift.com',
  'onesignal.com', 'pushwoosh.com', 'branch.io', 'adjust.com',
  'appsflyer.com', 'kochava.com', 'tapjoy.com', 'ironsrc.com',
  'smaato.net', 'sharethrough.com', 'teads.tv', 'triplelift.com',
  'spotxchange.com', 'adsrvr.org', 'turn.com', 'mathtag.com', 'bluekai.com',
  'krxd.net', 'demdex.net', 'everesttech.net', 'serving-sys.com',
  'atdmt.com', 'adbrite.com', 'adtechus.com', 'burstnet.com', 'chitika.com',
  'clicksor.com', 'infolinks.com', 'kontera.com', 'lijit.com',
  'media6degrees.com', 'pointroll.com', 'quantcast.com', 'rlcdn.com',
  'simpli.fi', 'tribalfusion.com', 'tremorhub.com', 'undertone.com',
  'yieldlab.net', 'zergnet.com', 'popcash.net', 'adsterra.com',
  'propellerclick.com', 'clickadu.com', 'galaksion.com', 'adspyglass.com',
  'hilltopads.net', 'juicyads.com', 'trafficjunky.com', 'exosrv.com',
  'moatads.com', 'adsafeprotected.com', 'doubleverify.com',
  'ensighten.com', 'tynt.com', 'addthis.com', 'sharethis.com',
  'disqus.com', 'gemius.pl', 'histats.com', 'statcounter.com',
  'clicky.com', 'getclicky.com', 'woopra.com', 'kissmetrics.com',
  'heap.io', 'fullstory.com', 'luckyorange.com', 'mouseflow.com',
  'smartlook.com', 'clarity.ms',
};

bool isAdBlockedUrl(String url) {
  try {
    final host = Uri.parse(url).host.toLowerCase();
    if (host.isEmpty) return false;
    for (final domain in adBlockDomains) {
      if (host == domain || host.endsWith('.$domain')) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

// ============================================================
// MOTORES DE PESQUISA
// ============================================================

class SearchEngine {
  const SearchEngine({required this.name, required this.domain, required this.urlTemplate});
  final String name;
  final String domain;
  final String urlTemplate;

  String buildUrl(String query) => urlTemplate.replaceAll('{q}', Uri.encodeQueryComponent(query));
  String get faviconUrl => 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
}

const List<SearchEngine> searchEngines = [
  SearchEngine(name: 'Google', domain: 'google.com', urlTemplate: 'https://www.google.com/search?q={q}'),
  SearchEngine(name: 'Bing', domain: 'bing.com', urlTemplate: 'https://www.bing.com/search?q={q}'),
  SearchEngine(name: 'DuckDuckGo', domain: 'duckduckgo.com', urlTemplate: 'https://duckduckgo.com/?q={q}'),
  SearchEngine(name: 'Yahoo', domain: 'yahoo.com', urlTemplate: 'https://search.yahoo.com/search?p={q}'),
  SearchEngine(name: 'Brave', domain: 'search.brave.com', urlTemplate: 'https://search.brave.com/search?q={q}'),
  SearchEngine(name: 'Ecosia', domain: 'ecosia.org', urlTemplate: 'https://www.ecosia.org/search?q={q}'),
];

class SearchEngineController extends ValueNotifier<SearchEngine> {
  SearchEngineController() : super(searchEngines.first);
}

final SearchEngineController activeSearchEngine = SearchEngineController();

class QuickSite {
  const QuickSite({required this.name, required this.domain, required this.url});
  final String name;
  final String domain;
  final String url;
  String get faviconUrl => 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
}

const List<QuickSite> quickSites = [
  QuickSite(name: 'Google', domain: 'google.com', url: 'https://www.google.com'),
  QuickSite(name: 'YouTube', domain: 'youtube.com', url: 'https://www.youtube.com'),
  QuickSite(name: 'Facebook', domain: 'facebook.com', url: 'https://www.facebook.com'),
  QuickSite(name: 'Instagram', domain: 'instagram.com', url: 'https://www.instagram.com'),
  QuickSite(name: 'X', domain: 'x.com', url: 'https://www.x.com'),
  QuickSite(name: 'Wikipedia', domain: 'wikipedia.org', url: 'https://www.wikipedia.org'),
];

// ============================================================
// ACELERADOR DE NAVEGAÇÃO
// ============================================================

class NavAccelerator {
  NavAccelerator._();
  static final NavAccelerator instance = NavAccelerator._();

  final Set<String> _preconnected = {};
  final Map<String, String> _pageCache = {};
  final List<String> _cacheOrder = [];
  static const int _maxCacheEntries = 25;

  Future<void> preconnect(String url) async {
    try {
      final uri = Uri.parse(url);
      final origin = '${uri.scheme}://${uri.host}';
      if (_preconnected.contains(origin)) return;
      _preconnected.add(origin);
      unawaited(
        http.head(Uri.parse(origin)).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 0)),
      );
    } catch (_) {}
  }

  void cachePage(String url, String html) {
    if (_pageCache.containsKey(url)) {
      _cacheOrder.remove(url);
    } else if (_cacheOrder.length >= _maxCacheEntries) {
      final oldest = _cacheOrder.removeAt(0);
      _pageCache.remove(oldest);
    }
    _pageCache[url] = html;
    _cacheOrder.add(url);
  }

  String? getCachedPage(String url) => _pageCache[url];
}

// ============================================================
// TABS CONTROLLER
// ============================================================

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.url,
    this.title,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  final String id;
  String url;
  String? title;
  bool canGoBack = false;
  bool canGoForward = false;
  DateTime lastActivity;

  void touch() => lastActivity = DateTime.now();
}

class TabsController extends ChangeNotifier {
  final List<BrowserTab> _tabs = [];
  int _counter = 0;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get count => _tabs.length;

  BrowserTab createTab(String url) {
    final tab = BrowserTab(id: 'tab_${_counter++}', url: url);
    _tabs.insert(0, tab);
    notifyListeners();
    return tab;
  }

  void updateTab(String id, {String? url, String? title, bool? canGoBack, bool? canGoForward}) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final tab = _tabs[index];
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (canGoBack != null) tab.canGoBack = canGoBack;
    if (canGoForward != null) tab.canGoForward = canGoForward;
    tab.touch();
    notifyListeners();
  }

  void closeTab(String id) {
    _tabs.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  BrowserTab? getTab(String id) {
    try {
      return _tabs.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

final TabsController tabsController = TabsController();

// ============================================================
// APP ROOT
// ============================================================

class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: looplyPrimary,
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
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: bg,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor: bg,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: looplyPrimary.withOpacity(0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? looplyPrimary : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? looplyPrimary : muted,
            fill: selected ? 1 : 0,
          );
        }),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
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

// ============================================================
// JOGOS
// ============================================================

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

// ============================================================
// SHELL PRINCIPAL
//
// A tab "Abas" NÃO é um destino de navegação normal: é um botão que
// aciona o OpenContainer envolvendo a página atualmente visível,
// fazendo-a encolher em Container Transform até virar um card na
// grade de abas (igual Chrome/Safari).
// ============================================================

class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});

  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> {
  int _selectedTab = 0;

  // Cada página do shell expõe um callback para abrir seu próprio
  // OpenContainer "de fora" (a partir do botão Abas no NavigationBar).
  final List<VoidCallback?> _openTabsCallbacks = [null, null, null];

  @override
  void initState() {
    super.initState();
    tabsController.addListener(_onTabsChanged);
  }

  @override
  void dispose() {
    tabsController.removeListener(_onTabsChanged);
    super.dispose();
  }

  void _onTabsChanged() {
    if (mounted) setState(() {});
  }

  void _handleTabsButtonTap() {
    final callback = _openTabsCallbacks[_selectedTab];
    callback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ShellPageToTab(
        registerOpenCallback: (cb) => _openTabsCallbacks[0] = cb,
        child: const HomeScreen(),
      ),
      ShellPageToTab(
        registerOpenCallback: (cb) => _openTabsCallbacks[1] = cb,
        child: const GamesScreen(),
      ),
      ShellPageToTab(
        registerOpenCallback: (cb) => _openTabsCallbacks[2] = cb,
        child: const ProfileScreen(),
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedTab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          // index 2 é o botão "Abas" — não navega, só abre o container.
          if (index == 2) {
            _handleTabsButtonTap();
            return;
          }
          // Reindexar: 0=Início, 1=Jogos, 3=Perfil viram 0,1,2 no IndexedStack.
          setState(() => _selectedTab = index < 2 ? index : index - 1);
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _selectedTab < 2 ? _selectedTab : _selectedTab + 1,
        destinations: [
          const NavigationDestination(
            icon: Icon(Symbols.home_rounded),
            selectedIcon: Icon(Symbols.home_rounded, fill: 1),
            label: 'Início',
          ),
          const NavigationDestination(
            icon: Icon(Symbols.sports_esports_rounded),
            selectedIcon: Icon(Symbols.sports_esports_rounded, fill: 1),
            label: 'Jogos',
          ),
          NavigationDestination(
            // Ícone desenhado: retângulo com o número de abas dentro,
            // igual à referência (quadrado com "2" dentro).
            icon: _TabsCountIcon(count: tabsController.count),
            selectedIcon: _TabsCountIcon(count: tabsController.count),
            label: 'Abas',
          ),
          const NavigationDestination(
            icon: Icon(Symbols.person_rounded),
            selectedIcon: Icon(Symbols.person_rounded, fill: 1),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Ícone "abas": quadrado com cantos arredondados e o número de abas
/// desenhado dentro — igual à referência (não é um ícone + badge).
class _TabsCountIcon extends StatelessWidget {
  const _TabsCountIcon({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? looplyTextDark : looplyTextLight;

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, height: 1),
      ),
    );
  }
}

/// Envolve uma página do shell num OpenContainer que, quando acionado
/// externamente (pelo botão "Abas"), faz essa página encolher e virar
/// um novo card na grade de abas.
class ShellPageToTab extends StatefulWidget {
  const ShellPageToTab({
    super.key,
    required this.child,
    required this.registerOpenCallback,
  });

  final Widget child;
  final ValueChanged<VoidCallback> registerOpenCallback;

  @override
  State<ShellPageToTab> createState() => _ShellPageToTabState();
}

class _ShellPageToTabState extends State<ShellPageToTab> {
  VoidCallback? _openContainerFn;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 280),
      closedElevation: 0,
      openElevation: 0,
      closedColor: bg,
      openColor: bg,
      middleColor: bg,
      closedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      tappable: false, // só abre via callback externo, nunca por toque direto
      closedBuilder: (context, openContainer) {
        _openContainerFn = openContainer;
        // Registra o callback assim que o container está pronto, uma
        // única vez por frame, sem causar rebuild em loop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.registerOpenCallback(() => _openContainerFn?.call());
        });
        return widget.child;
      },
      openBuilder: (context, closeContainer) {
        return TabsScreen(onClose: closeContainer);
      },
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const LooplySearchBox(),
        titleSpacing: 16,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Text(
            'Sites rápidos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark ? looplyTextDark : looplyTextLight,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quickSites.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final site = quickSites[index];
              return RepaintBoundary(child: QuickSiteTile(site: site));
            },
          ),
        ],
      ),
    );
  }
}

class QuickSiteTile extends StatelessWidget {
  const QuickSiteTile({super.key, required this.site});
  final QuickSite site;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openNewTab(context, site.url),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: panel, shape: BoxShape.circle),
              child: CachedNetworkImage(
                imageUrl: site.faviconUrl,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 100),
                errorWidget: (context, url, error) => Icon(Symbols.public_rounded, color: text, size: 22),
                placeholder: (context, url) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 6),
            Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: text)),
          ],
        ),
      ),
    );
  }
}

void openNewTab(BuildContext context, String url) {
  final tab = tabsController.createTab(url);
  Navigator.of(context).push(
    MaterialPageRoute(builder: (context) => BrowserScreen(tabId: tab.id, initialUrl: url)),
  );
}

// ============================================================
// JOGOS
// ============================================================

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 68, title: const Text('Jogos')),
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
              return RepaintBoundary(child: GameCard(game: game));
            },
          ),
        ],
      ),
    );
  }
}

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
      transitionDuration: const Duration(milliseconds: 240),
      closedElevation: 0,
      openElevation: 0,
      closedColor: panel,
      openColor: bg,
      middleColor: panel,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key, required this.game, required this.onClose});
  final LooplyGame game;
  final VoidCallback onClose;

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  bool _isLoading = true;
  InAppWebViewController? _webController;

  @override
  void dispose() {
    _webController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: widget.onClose),
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
              cacheMode: CacheMode.LOAD_DEFAULT,
              hardwareAcceleration: true,
            ),
            shouldInterceptRequest: (controller, request) async {
              if (isAdBlockedUrl(request.url.toString())) {
                return WebResourceResponse(contentType: '', data: Uint8List(0));
              }
              return null;
            },
            onWebViewCreated: (controller) => _webController = controller,
            onLoadStart: (controller, url) => setState(() => _isLoading = true),
            onLoadStop: (controller, url) async {
              final probe = await controller.evaluateJavascript(
                source: "document.body ? document.body.innerText.substring(0, 15) : ''",
              );
              if (probe != null && probe.toString().trim().startsWith('<!')) {
                final rawHtml = await controller.evaluateJavascript(source: "document.body.innerText");
                if (rawHtml != null) {
                  await controller.loadData(
                    data: rawHtml.toString(),
                    mimeType: 'text/html',
                    encoding: 'utf8',
                    baseUrl: WebUri(widget.game.url!),
                  );
                  return;
                }
              }
              if (mounted) setState(() => _isLoading = false);
            },
          ),
          if (_isLoading)
            Container(color: bg, child: const Center(child: CircularProgressIndicator(color: looplyPrimary))),
        ],
      ),
    );
  }
}

// ============================================================
// SEARCH BOX + TELA DE PESQUISA
// ============================================================

class LooplySearchBox extends StatelessWidget {
  const LooplySearchBox({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return ValueListenableBuilder<SearchEngine>(
      valueListenable: activeSearchEngine,
      builder: (context, engine, _) {
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28)),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showEnginePicker(context),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CachedNetworkImage(
                    imageUrl: engine.faviconUrl,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 100),
                    errorWidget: (context, url, error) => Icon(Symbols.public_rounded, color: muted, size: 26),
                    placeholder: (context, url) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  ),
                  child: Text('Pesquisar ou digitar o endereço', style: TextStyle(color: muted, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEnginePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(children: [Text('Motor de pesquisa', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800))]),
                ),
                ...searchEngines.map((engine) {
                  return ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? looplyPanel2Dark : looplyPanel2Light),
                      padding: const EdgeInsets.all(6),
                      child: CachedNetworkImage(
                        imageUrl: engine.faviconUrl,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => Icon(Symbols.public_rounded, color: muted, size: 18),
                        placeholder: (context, url) => const SizedBox.shrink(),
                      ),
                    ),
                    title: Text(engine.name, style: TextStyle(color: text)),
                    trailing: ValueListenableBuilder<SearchEngine>(
                      valueListenable: activeSearchEngine,
                      builder: (context, active, _) {
                        return active.name == engine.name
                            ? const Icon(Symbols.check_circle_rounded, color: looplyPrimary, fill: 1)
                            : const SizedBox.shrink();
                      },
                    ),
                    onTap: () {
                      activeSearchEngine.value = engine;
                      Navigator.of(sheetContext).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final uri = Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&q=${Uri.encodeQueryComponent(query)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        final list = (decoded.length > 1 ? decoded[1] as List<dynamic> : <dynamic>[]).map((item) => item.toString()).toList();
        if (mounted) setState(() => _suggestions = list);
      }
    } catch (_) {}
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final engine = activeSearchEngine.value;
    final url = _looksLikeUrl(trimmed) ? _normalizeUrl(trimmed) : engine.buildUrl(trimmed);
    NavAccelerator.instance.preconnect(url);
    final tab = tabsController.createTab(url);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => BrowserScreen(tabId: tab.id, initialUrl: url)),
    );
  }

  bool _looksLikeUrl(String text) => !text.contains(' ') && text.contains('.');
  String _normalizeUrl(String text) => (text.startsWith('http://') || text.startsWith('https://')) ? text : 'https://$text';

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
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        titleSpacing: 0,
        title: ValueListenableBuilder<SearchEngine>(
          valueListenable: activeSearchEngine,
          builder: (context, engine, _) {
            return Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28)),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: CachedNetworkImage(
                      imageUrl: engine.faviconUrl,
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => Icon(Symbols.public_rounded, color: muted, size: 26),
                      placeholder: (context, url) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: text, fontSize: 14),
                      onSubmitted: _submitSearch,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar ou digitar o endereço',
                        hintStyle: TextStyle(color: muted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(onTap: () => _controller.clear(), child: Icon(Symbols.close_rounded, color: muted, size: 18)),
                ],
              ),
            );
          },
        ),
      ),
      body: _suggestions.isEmpty
          ? const SizedBox.shrink()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: Icon(Symbols.search_rounded, color: muted, size: 20),
                  title: Text(suggestion, style: TextStyle(color: text, fontSize: 14)),
                  onTap: () {
                    _controller.text = suggestion;
                    _submitSearch(suggestion);
                  },
                );
              },
            ),
    );
  }
}

// ============================================================
// BROWSER SCREEN — UMA ÚNICA barra de endereço no topo
// (favicon + título/URL + reload), e UMA barra inferior fixa com só
// os 5 ícones de navegação (sem favicon/título nela).
// ============================================================

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.tabId, required this.initialUrl});
  final String tabId;
  final String initialUrl;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  bool _isLoading = true;
  double _progress = 0;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  late final AnimationController _addressBarAnim;
  double _lastScrollY = 0;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _addressBarAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1);

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: looplyPrimary),
      onRefresh: () async {
        await _controller?.reload();
      },
    );
  }

  @override
  void dispose() {
    _addressBarAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _updateTabState() {
    tabsController.updateTab(
      widget.tabId,
      url: _currentUrl,
      title: _currentTitle.isNotEmpty ? _currentTitle : _currentUrl,
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
    );
  }

  void _onScrollChanged(int y) {
    final dy = y - _lastScrollY;
    if (dy > 6 && _addressBarAnim.value > 0) {
      _addressBarAnim.animateTo(0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    } else if (dy < -6 && _addressBarAnim.value < 1) {
      _addressBarAnim.animateTo(1, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
    _lastScrollY = y.toDouble();
  }

  Future<bool> _handleBackGesture() async {
    if (_canGoBack) {
      await _controller?.goBack();
      return false;
    }
    _updateTabState();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackGesture();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
              : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
          child: Column(
            children: [
              // ÚNICA barra de endereço: favicon + título/url + reload.
              // Esconde ao deslizar para baixo na página, reaparece ao
              // deslizar para cima — sem deixar nenhum espaço vazio.
              SizeTransition(
                sizeFactor: _addressBarAnim,
                axisAlignment: -1,
                child: FadeTransition(
                  opacity: _addressBarAnim,
                  child: _AddressBar(
                    title: _currentTitle.isNotEmpty ? _currentTitle : _currentUrl,
                    url: _currentUrl,
                    isLoading: _isLoading,
                    onReload: () => _controller?.reload(),
                  ),
                ),
              ),
              if (_isLoading)
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(value: _progress, color: looplyPrimary, backgroundColor: muted.withOpacity(0.15)),
                ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  pullToRefreshController: _pullToRefreshController,
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    transparentBackground: true,
                    cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
                    hardwareAcceleration: true,
                  ),
                  shouldOverrideUrlLoading: (controller, action) async {
                    final uri = action.request.url;
                    if (uri == null) return NavigationActionPolicy.ALLOW;
                    final scheme = uri.scheme.toLowerCase();
                    if (scheme == 'http' || scheme == 'https' || scheme == 'about' || scheme == 'data') {
                      return NavigationActionPolicy.ALLOW;
                    }
                    return NavigationActionPolicy.CANCEL;
                  },
                  shouldInterceptRequest: (controller, request) async {
                    if (isAdBlockedUrl(request.url.toString())) {
                      return WebResourceResponse(contentType: '', data: Uint8List(0));
                    }
                    return null;
                  },
                  onWebViewCreated: (controller) => _controller = controller,
                  onProgressChanged: (controller, progress) => setState(() => _progress = progress / 100),
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      if (url != null) _currentUrl = url.toString();
                    });
                  },
                  onTitleChanged: (controller, title) {
                    _currentTitle = title ?? '';
                    _updateTabState();
                    if (mounted) setState(() {});
                  },
                  onLoadStop: (controller, url) async {
                    _pullToRefreshController?.endRefreshing();
                    final back = await controller.canGoBack();
                    final forward = await controller.canGoForward();
                    setState(() {
                      _isLoading = false;
                      _canGoBack = back;
                      _canGoForward = forward;
                      if (url != null) _currentUrl = url.toString();
                    });
                    _updateTabState();
                    final html = await controller.getHtml();
                    if (html != null) NavAccelerator.instance.cachePage(_currentUrl, html);
                  },
                  onReceivedError: (controller, request, error) {
                    _pullToRefreshController?.endRefreshing();
                    if (mounted) setState(() => _isLoading = false);
                  },
                  onScrollChanged: (controller, x, y) => _onScrollChanged(y),
                ),
              ),
              // ÚNICA barra inferior: FIXA, só os 5 ícones de navegação,
              // sem favicon/título — igual à referência.
              _BrowserBottomBar(
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onBack: () => _controller?.goBack(),
                onForward: () => _controller?.goForward(),
                onMenu: () => _showPageMenu(context),
                onTabs: () {
                  _updateTabState();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                onHome: () {
                  _updateTabState();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPageMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Symbols.refresh_rounded, color: text),
                  title: Text('Atualizar página', style: TextStyle(color: text)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _controller?.reload();
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.tab_rounded, color: text),
                  title: Text('Nova aba', style: TextStyle(color: text)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openNewTab(context, 'https://www.google.com');
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.close_rounded, color: text),
                  title: Text('Fechar aba', style: TextStyle(color: text)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    tabsController.closeTab(widget.tabId);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barra de endereço única: favicon + título + botão reload (lado
/// direito do título, estilo "pill" igual à Imagem 1).
class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.title,
    required this.url,
    required this.isLoading,
    required this.onReload,
  });

  final String title;
  final String url;
  final bool isLoading;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final host = Uri.tryParse(url)?.host ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 8),
      color: bg,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            CachedNetworkImage(
              imageUrl: 'https://www.google.com/s2/favicons?domain=$host&sz=64',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorWidget: (context, u, e) => Icon(Symbols.public_rounded, color: muted, size: 20),
              placeholder: (context, u) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.isEmpty ? host : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: onReload,
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: looplyPrimary))
                  : Icon(Symbols.refresh_rounded, color: muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior única e fixa: voltar / avançar / menu / abas / home.
class _BrowserBottomBar extends StatelessWidget {
  const _BrowserBottomBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onMenu,
    required this.onTabs,
    required this.onHome,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onMenu;
  final VoidCallback onTabs;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE4E8EE);

    return AnimatedBuilder(
      animation: tabsController,
      builder: (context, _) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: borderColor, width: 1))),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Symbols.arrow_back_rounded, color: canGoBack ? text : muted.withOpacity(0.4)),
                  onPressed: canGoBack ? onBack : null,
                ),
                IconButton(
                  icon: Icon(Symbols.arrow_forward_rounded, color: canGoForward ? text : muted.withOpacity(0.4)),
                  onPressed: canGoForward ? onForward : null,
                ),
                IconButton(icon: Icon(Symbols.menu_rounded, color: text), onPressed: onMenu),
                IconButton(
                  icon: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: text, width: 1.5), borderRadius: BorderRadius.circular(5)),
                    child: Text('${tabsController.count}', style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  onPressed: onTabs,
                ),
                IconButton(icon: Icon(Symbols.home_rounded, color: text), onPressed: onHome),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// TELA DE ABAS — grade com os sites abertos no browser; cada card
// usa Container Transform de volta ao BrowserScreen daquela aba.
// ============================================================

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  @override
  void initState() {
    super.initState();
    tabsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    tabsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tabs = tabsController.tabs;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: widget.onClose),
        title: Text('Abas (${tabs.length})'),
        actions: [
          IconButton(icon: const Icon(Symbols.add_rounded), onPressed: () => openNewTab(context, 'https://www.google.com')),
        ],
      ),
      body: tabs.isEmpty
          ? _EmptyTabsState(onNewTab: () => openNewTab(context, 'https://www.google.com'))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: tabs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                return RepaintBoundary(child: TabCard(key: ValueKey(tab.id), tab: tab));
              },
            ),
    );
  }
}

class _EmptyTabsState extends StatelessWidget {
  const _EmptyTabsState({required this.onNewTab});
  final VoidCallback onNewTab;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.tab_rounded, size: 48, color: muted),
          const SizedBox(height: 12),
          Text('Nenhuma aba aberta', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onNewTab, icon: const Icon(Symbols.add_rounded), label: const Text('Nova aba')),
        ],
      ),
    );
  }
}

class TabCard extends StatelessWidget {
  const TabCard({super.key, required this.tab});
  final BrowserTab tab;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 260),
      closedElevation: 0,
      openElevation: 0,
      closedColor: panel,
      openColor: bg,
      middleColor: panel,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      closedBuilder: (context, openContainer) {
        return Material(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: openContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
                  child: Row(
                    children: [
                      CachedNetworkImage(
                        imageUrl: 'https://www.google.com/s2/favicons?domain=${Uri.tryParse(tab.url)?.host ?? ''}&sz=64',
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => Icon(Symbols.public_rounded, color: muted, size: 16),
                        placeholder: (context, url) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(tab.title ?? tab.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: text, fontWeight: FontWeight.w600)),
                      ),
                      GestureDetector(onTap: () => tabsController.closeTab(tab.id), child: Icon(Symbols.close_rounded, size: 15, color: muted)),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Icon(Symbols.public_rounded, size: 32, color: muted.withOpacity(0.4))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      openBuilder: (context, closeContainer) {
        return BrowserScreen(tabId: tab.id, initialUrl: tab.url);
      },
    );
  }
}

// ============================================================
// PERFIL
// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final panel2 = isDark ? looplyPanel2Dark : looplyPanel2Light;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final coverColor = isDark ? looplyBgDark : looplyBgLight;

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(height: 130, width: double.infinity, color: coverColor),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 6,
                    right: 12,
                    child: Builder(
                      builder: (menuContext) {
                        return Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Symbols.more_vert_rounded, color: text, size: 20),
                            onPressed: () {
                              final box = menuContext.findRenderObject() as RenderBox;
                              final position = box.localToGlobal(Offset(box.size.width, box.size.height));
                              _openMenu(context, position);
                            },
                          ),
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
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: bg, width: 4), color: panel2),
                      child: Icon(Symbols.person_rounded, color: muted, size: 42),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.list(
                children: [
                  Text('Geral', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted)),
                  const SizedBox(height: 10),
                  _ProfileActionTile(icon: Symbols.settings_rounded, label: 'Settings', onTap: () {}),
                  const SizedBox(height: 10),
                  _ProfileActionTile(icon: Symbols.dark_mode_rounded, label: 'Theme', onTap: () => _showThemeSheet(context)),
                  const SizedBox(height: 10),
                  _ProfileActionTile(icon: Symbols.language_rounded, label: 'Idioma', onTap: () {}),
                  const SizedBox(height: 10),
                  _ProfileActionTile(icon: Symbols.shield_rounded, label: 'Bloqueador de anúncios', trailing: 'Ativo', onTap: () {}),
                  const SizedBox(height: 10),
                  _ProfileActionTile(icon: Symbols.speed_rounded, label: 'Acelerador de navegação', trailing: 'Ativo', onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        PopupMenuItem(value: 'settings', child: Row(children: [Icon(Symbols.settings_rounded, color: text, size: 19), const SizedBox(width: 10), Text('Settings', style: TextStyle(color: text))])),
        PopupMenuItem(value: 'theme', child: Row(children: [Icon(Symbols.dark_mode_rounded, color: text, size: 19), const SizedBox(width: 10), Text('Theme', style: TextStyle(color: text))])),
        PopupMenuItem(value: 'idiom', child: Row(children: [Icon(Symbols.language_rounded, color: text, size: 19), const SizedBox(width: 10), Text('Idioma', style: TextStyle(color: text))])),
      ],
    ).then((value) {
      if (value == 'theme') _showThemeSheet(context);
    });
  }

  void _showThemeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      child: Row(children: [Text('Tema', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800))]),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: mode,
                      activeColor: looplyPrimary,
                      title: Text('Claro', style: TextStyle(color: text)),
                      onChanged: (value) {
                        if (value != null) themeController.setMode(value);
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: mode,
                      activeColor: looplyPrimary,
                      title: Text('Escuro', style: TextStyle(color: text)),
                      onChanged: (value) {
                        if (value != null) themeController.setMode(value);
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: mode,
                      activeColor: looplyPrimary,
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
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({required this.icon, required this.label, required this.onTap, this.trailing});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final panel2 = isDark ? looplyPanel2Dark : looplyPanel2Light;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: panel2),
                child: Icon(icon, color: looplyPrimary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600))),
              if (trailing != null) Text(trailing!, style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(width: 6),
              Icon(Symbols.chevron_right_rounded, color: muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}