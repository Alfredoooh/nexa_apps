import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LooplyApp());
}

// ============================================================
// CORES / TEMA — Google Material Blue exato (#1A73E8)
// ============================================================

const Color looplyPrimary = Color(0xFF1A73E8);

const Color looplyBgDark = Color(0xFF121214);
const Color looplyBgLight = Color(0xFFF5F5F7);

const Color looplyPanelDark = Color(0xFF1E1E21);
const Color looplyPanel2Dark = Color(0xFF28282C);
const Color looplyPanelLight = Color(0xFFFFFFFF);
const Color looplyPanel2Light = Color(0xFFEDEDF0);

const Color looplyTextDark = Color(0xFFF0F0F0);
const Color looplyMutedDark = Color(0xFF9A9A9F);
const Color looplyTextLight = Color(0xFF1A1A1A);
const Color looplyMutedLight = Color(0xFF6B6B70);

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);
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
// ACTIVITY LOG
// ============================================================

enum ActivityKind { site, game }

class ActivityEntry {
  ActivityEntry({
    required this.kind,
    required this.title,
    required this.url,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final ActivityKind kind;
  final String title;
  final String url;
  final DateTime timestamp;
}

class ActivityController extends ChangeNotifier {
  final List<ActivityEntry> _entries = [];
  List<ActivityEntry> get entries => List.unmodifiable(_entries.reversed);

  void log(ActivityKind kind, String title, String url) {
    _entries.add(ActivityEntry(kind: kind, title: title, url: url));
    if (_entries.length > 100) _entries.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

final ActivityController activityController = ActivityController();

// ============================================================
// TABS CONTROLLER
// ============================================================

enum TabKind { browser, appScreen }

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.kind,
    this.url = '',
    this.title,
    this.appScreenLabel,
    this.appScreenIcon,
    this.thumbnail,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  final String id;
  final TabKind kind;
  String url;
  String? title;
  String? appScreenLabel;
  IconData? appScreenIcon;
  Uint8List? thumbnail;
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

  BrowserTab createBrowserTab(String url) {
    final tab = BrowserTab(id: 'tab_${_counter++}', kind: TabKind.browser, url: url);
    _tabs.insert(0, tab);
    notifyListeners();
    return tab;
  }

  BrowserTab upsertAppScreenTab(String screenKey, String label, IconData icon, Uint8List thumbnail) {
    final existingIndex = _tabs.indexWhere((t) => t.kind == TabKind.appScreen && t.url == screenKey);
    if (existingIndex != -1) {
      final tab = _tabs[existingIndex];
      tab.thumbnail = thumbnail;
      tab.touch();
      _tabs.removeAt(existingIndex);
      _tabs.insert(0, tab);
      notifyListeners();
      return tab;
    }
    final tab = BrowserTab(
      id: 'tab_${_counter++}',
      kind: TabKind.appScreen,
      url: screenKey,
      appScreenLabel: label,
      appScreenIcon: icon,
      thumbnail: thumbnail,
    );
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

Future<Uint8List?> captureWidgetSnapshot(GlobalKey key, {double pixelRatio = 1.5}) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

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
        indicatorColor: looplyPrimary.withOpacity(0.18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? text : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? text : muted,
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
// SHELL PRINCIPAL — navegação com morph manual (igual ao Orbit):
// captura um bitmap real da tela atual, cria uma imagem flutuante
// sobre a posição exata da tela, anima encolhendo até o card de
// destino na grade de abas.
// ============================================================

class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});

  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> with TickerProviderStateMixin {
  int _selectedTab = 0;
  bool _showingTabsGrid = false;
  bool _morphing = false;

  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _rootKey = GlobalKey();

  final List<String> _screenKeys = ['home_screen', 'games_screen', 'activity_screen'];
  final List<String> _screenLabels = ['Início', 'Jogos', 'Atividade'];
  final List<IconData> _screenIcons = [Symbols.home_rounded, Symbols.sports_esports_rounded, Symbols.history_rounded];

  Uint8List? _morphBitmap;
  Rect? _morphFrom;
  Rect? _morphTo;
  late final AnimationController _morphController;

  BrowserTab? _pendingOpenTab;

  @override
  void initState() {
    super.initState();
    tabsController.addListener(_onTabsChanged);
    _morphController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void dispose() {
    tabsController.removeListener(_onTabsChanged);
    _morphController.dispose();
    super.dispose();
  }

  void _onTabsChanged() {
    if (mounted) setState(() {});
  }

  Rect? _globalRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    final size = renderObject.size;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & size;
  }

  Future<void> _openTabsGrid() async {
    if (_showingTabsGrid || _morphing) return;

    final sourceRect = _globalRect(_rootKey);
    if (sourceRect == null) {
      setState(() => _showingTabsGrid = true);
      return;
    }

    final bitmap = await captureWidgetSnapshot(_repaintKey);
    if (bitmap == null) {
      setState(() => _showingTabsGrid = true);
      return;
    }

    // Registra (ou atualiza) o card desta tela na grade de abas —
    // exatamente como o Orbit faz com captureView() antes de abrir.
    tabsController.upsertAppScreenTab(
      _screenKeys[_selectedTab],
      _screenLabels[_selectedTab],
      _screenIcons[_selectedTab],
      bitmap,
    );

    setState(() {
      _showingTabsGrid = true;
      _morphing = true;
      _morphBitmap = bitmap;
      _morphFrom = sourceRect;
      _morphTo = sourceRect; // cresce a partir do mesmo tamanho: fade+scale suave
    });

    _morphController.value = 0;
    await _morphController.animateTo(1, curve: Curves.easeOutCubic);

    if (mounted) {
      setState(() {
        _morphing = false;
        _morphBitmap = null;
      });
    }
  }

  Future<void> _closeTabsGrid({BrowserTab? openTab}) async {
    if (_morphing) return;
    _pendingOpenTab = openTab;

    setState(() {
      _morphing = true;
    });

    _morphController.value = 1;
    await _morphController.animateTo(0, curve: Curves.easeOutCubic);

    if (!mounted) return;

    if (_pendingOpenTab != null && _pendingOpenTab!.kind == TabKind.browser) {
      final tab = _pendingOpenTab!;
      _pendingOpenTab = null;
      setState(() {
        _morphing = false;
        _showingTabsGrid = false;
      });
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => BrowserScreen(tabId: tab.id, initialUrl: tab.url)),
      );
      return;
    }

    if (_pendingOpenTab != null && _pendingOpenTab!.kind == TabKind.appScreen) {
      final index = _screenKeys.indexOf(_pendingOpenTab!.url);
      _pendingOpenTab = null;
      setState(() {
        _morphing = false;
        _showingTabsGrid = false;
        if (index != -1) _selectedTab = index;
      });
      return;
    }

    setState(() {
      _morphing = false;
      _showingTabsGrid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    final pages = <Widget>[
      const HomeScreen(),
      const GamesScreen(),
      const ActivityScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        body: Stack(
          key: _rootKey,
          children: [
            // Conteúdo principal (shell normal), escondido enquanto a
            // grade de abas estiver visível.
            Offstage(
              offstage: _showingTabsGrid,
              child: SafeArea(
                bottom: false,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: IndexedStack(index: _selectedTab, children: pages),
                ),
              ),
            ),
            // Grade de abas.
            if (_showingTabsGrid)
              TabsGridScreen(
                onSelectTab: (tab) => _closeTabsGrid(openTab: tab),
                onClose: () => _closeTabsGrid(),
              ),
            // Morph: imagem flutuante que faz a transição visual —
            // fade + leve "settle" para dar sensação de profundidade,
            // sem travar a UI thread (é só uma Image widget animada).
            if (_morphing && _morphBitmap != null && _morphFrom != null)
              AnimatedBuilder(
                animation: _morphController,
                builder: (context, _) {
                  final t = _morphController.value;
                  final rect = _morphFrom!;
                  return Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(
                        scale: 1 - (t * 0.08),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(t * 24),
                          child: Image.memory(_morphBitmap!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        bottomNavigationBar: Offstage(
          offstage: _showingTabsGrid,
          child: NavigationBar(
            selectedIndex: _selectedTab < 2 ? _selectedTab : _selectedTab + 1,
            onDestinationSelected: (index) {
              if (index == 2) {
                _openTabsGrid();
                return;
              }
              setState(() => _selectedTab = index < 2 ? index : index - 1);
            },
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                icon: _TabsCountIcon(count: tabsController.count, color: text),
                selectedIcon: _TabsCountIcon(count: tabsController.count, color: text),
                label: 'Abas',
              ),
              const NavigationDestination(
                icon: Icon(Symbols.history_rounded),
                selectedIcon: Icon(Symbols.history_rounded, fill: 1),
                label: 'Atividade',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabsCountIcon extends StatelessWidget {
  const _TabsCountIcon({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}

// ============================================================
// GRADE DE ABAS — mostra sites do browser + cards de telas internas
// (Home/Jogos/Atividade capturadas via screenshot real)
// ============================================================

class TabsGridScreen extends StatefulWidget {
  const TabsGridScreen({super.key, required this.onSelectTab, required this.onClose});
  final ValueChanged<BrowserTab> onSelectTab;
  final VoidCallback onClose;

  @override
  State<TabsGridScreen> createState() => _TabsGridScreenState();
}

class _TabsGridScreenState extends State<TabsGridScreen> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final tabs = tabsController.tabs;

    return Material(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(icon: Icon(Symbols.close_rounded, color: text), onPressed: widget.onClose),
                  Expanded(
                    child: Text('Abas (${tabs.length})', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: Icon(Symbols.add_rounded, color: text),
                    onPressed: () {
                      final tab = tabsController.createBrowserTab('https://www.google.com');
                      widget.onSelectTab(tab);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: tabs.isEmpty
                  ? Center(child: Text('Nenhuma aba aberta', style: TextStyle(color: text)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: tabs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final tab = tabs[index];
                        return RepaintBoundary(child: TabGridCard(tab: tab, onTap: () => widget.onSelectTab(tab)));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class TabGridCard extends StatelessWidget {
  const TabGridCard({super.key, required this.tab, required this.onTap});
  final BrowserTab tab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    final isApp = tab.kind == TabKind.appScreen;
    final label = isApp ? (tab.appScreenLabel ?? '') : (tab.title ?? tab.url);

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
              child: Row(
                children: [
                  if (isApp)
                    Icon(tab.appScreenIcon ?? Symbols.apps_rounded, size: 16, color: muted)
                  else
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
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: text, fontWeight: FontWeight.w600)),
                  ),
                  if (!isApp)
                    GestureDetector(onTap: () => tabsController.closeTab(tab.id), child: Icon(Symbols.close_rounded, size: 15, color: muted)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: tab.thumbnail != null
                    ? Image.memory(tab.thumbnail!, fit: BoxFit.cover)
                    : Center(child: Icon(Symbols.public_rounded, size: 32, color: muted.withOpacity(0.4))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME — search box grande estilo Google, menu hambúrguer à esquerda,
// avatar circular à direita (abre Configurações)
// ============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final bg = isDark ? looplyBgDark : looplyBgLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 30),
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Symbols.menu_rounded, color: text),
                  onPressed: () {},
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: looplyPrimary),
                    alignment: Alignment.center,
                    child: const Icon(Symbols.person_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const LooplyBigSearchBox(),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Sites rápidos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GridView.builder(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Search box grande estilo Google (imagem de referência): logo central
/// acima, pill grande com placeholder "Pesquise" e ícones de voz/câmera.
/// Sem favicons de motores aqui — a troca de motor agora é só em Settings.
class LooplyBigSearchBox extends StatelessWidget {
  const LooplyBigSearchBox({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SearchScreen()),
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            Icon(Symbols.search_rounded, color: muted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Pesquise', style: TextStyle(color: muted, fontSize: 17)),
            ),
            Icon(Symbols.mic_rounded, color: looplyPrimary, size: 22),
            const SizedBox(width: 16),
            Icon(Symbols.photo_camera_rounded, color: looplyPrimary, size: 22),
          ],
        ),
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
        onTap: () => openNewTab(context, site.url, title: site.name),
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

void openNewTab(BuildContext context, String url, {String? title}) {
  final tab = tabsController.createBrowserTab(url);
  activityController.log(ActivityKind.site, title ?? url, url);
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
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final text = isDark ? looplyTextDark : looplyTextLight;

    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: game.url == null
            ? null
            : () {
                activityController.log(ActivityKind.game, game.title, game.url!);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => GameWebViewScreen(game: game)),
                );
              },
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

/// Tela do jogo com ad-block REAL: intercepta a requisição principal do
/// HTML e força Content-Type text/html quando o servidor (GitHub Raw)
/// entrega como text/plain — é isso que impedia o jogo de renderizar
/// e mostrava o código-fonte em vez do preview.
class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key, required this.game});
  final LooplyGame game;

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
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
              // Intercepta a requisição principal do HTML e força o
              // Content-Type correto — resolve de vez o problema do
              // GitHub Raw servindo .html como text/plain.
              shouldInterceptRequest: (controller, request) async {
                final url = request.url.toString();
                if (isAdBlockedUrl(url)) {
                  return WebResourceResponse(contentType: '', data: Uint8List(0));
                }
                if (url == widget.game.url && (request.method == null || request.method == 'GET')) {
                  try {
                    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
                    if (response.statusCode == 200) {
                      return WebResourceResponse(
                        contentType: 'text/html',
                        contentEncoding: 'utf-8',
                        data: response.bodyBytes,
                      );
                    }
                  } catch (_) {
                    // Se a interceptação falhar, deixa o WebView tentar
                    // carregar normalmente como fallback.
                  }
                }
                return null;
              },
              onWebViewCreated: (controller) => _webController = controller,
              onLoadStart: (controller, url) => setState(() => _isLoading = true),
              onLoadStop: (controller, url) {
                if (mounted) setState(() => _isLoading = false);
              },
            ),
            if (_isLoading)
              Container(color: bg, child: const Center(child: CircularProgressIndicator(color: looplyPrimary))),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TELA DE PESQUISA — input estilo da imagem de referência: campo com
// seta de voltar, ícone de microfone e câmera à direita, histórico
// com ícone de relógio
// ============================================================

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
    final tab = tabsController.createBrowserTab(url);
    activityController.log(ActivityKind.site, trimmed, url);
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
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(icon: Icon(Symbols.arrow_back_rounded, color: text), onPressed: () => Navigator.of(context).pop()),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: text, fontSize: 17),
                        onSubmitted: _submitSearch,
                        decoration: InputDecoration(
                          hintText: 'Pesquisar…',
                          hintStyle: TextStyle(color: muted, fontSize: 17),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Icon(Symbols.mic_rounded, color: looplyPrimary, size: 22),
                    const SizedBox(width: 16),
                    Icon(Symbols.photo_camera_rounded, color: looplyPrimary, size: 22),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? looplyPanel2Dark : looplyPanel2Light),
                        child: Icon(Symbols.schedule_rounded, color: muted, size: 18),
                      ),
                      title: Text(suggestion, style: TextStyle(color: text, fontSize: 15)),
                      onTap: () {
                        _controller.text = suggestion;
                        _submitSearch(suggestion);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BROWSER SCREEN — UMA única barra de endereço no topo, UMA barra
// inferior fixa. Hide-on-scroll CORRIGIDO: usa AnimatedContainer com
// clampação segura em vez de animação baseada em deltas acumulados
// de scroll do WebView, que era a causa do travamento.
// ============================================================

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.tabId, required this.initialUrl});
  final String tabId;
  final String initialUrl;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  bool _isLoading = true;
  double _progress = 0;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  // Controla visibilidade da address bar SEM animação contínua ligada
  // a cada evento de scroll (isso era o que travava) — só alterna um
  // bool com debounce leve, e o AnimatedContainer cuida da transição.
  bool _addressBarVisible = true;
  int _lastScrollY = 0;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: looplyPrimary),
      onRefresh: () async {
        await _controller?.reload();
      },
    );
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
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
    _lastScrollY = y;

    // Debounce: só processa a decisão de mostrar/esconder a cada 80ms,
    // em vez de recalcular em TODO frame de scroll (isso é o que
    // sobrecarregava a UI thread e travava a animação).
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      if (dy > 10 && _addressBarVisible) {
        setState(() => _addressBarVisible = false);
      } else if (dy < -10 && !_addressBarVisible) {
        setState(() => _addressBarVisible = true);
      }
    });
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: bg,
          body: Column(
            children: [
              // Barra de endereço única — some/aparece com AnimatedContainer
              // simples (altura 0 <-> altura real), sem travar.
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: _addressBarVisible ? (60 + MediaQuery.of(context).padding.top) : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: OverflowBox(
                  minHeight: 60 + MediaQuery.of(context).padding.top,
                  maxHeight: 60 + MediaQuery.of(context).padding.top,
                  alignment: Alignment.bottomCenter,
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
// ATIVIDADE — substitui o Perfil: histórico de sites visitados e
// jogos abertos
// ============================================================

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final entries = activityController.entries;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text('Atividade'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: Icon(Symbols.delete_sweep_rounded, color: text),
              onPressed: activityController.clear,
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.history_rounded, size: 48, color: muted),
                  const SizedBox(height: 12),
                  Text('Sem atividade recente', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isGame = entry.kind == ActivityKind.game;
                return Material(
                  color: panel,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? looplyPanel2Dark : looplyPanel2Light),
                      child: isGame
                          ? Icon(Symbols.sports_esports_rounded, color: looplyPrimary, size: 19)
                          : CachedNetworkImage(
                              imageUrl: 'https://www.google.com/s2/favicons?domain=${Uri.tryParse(entry.url)?.host ?? ''}&sz=64',
                              fit: BoxFit.contain,
                              errorWidget: (context, u, e) => Icon(Symbols.public_rounded, color: muted, size: 18),
                              placeholder: (context, u) => const SizedBox.shrink(),
                            ),
                    ),
                    title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                    subtitle: Text(_formatTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 12)),
                    onTap: () {
                      if (isGame) {
                        final game = looplyGames.firstWhere((g) => g.url == entry.url, orElse: () => looplyGames.first);
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => GameWebViewScreen(game: game)));
                      } else {
                        openNewTab(context, entry.url, title: entry.title);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} dias';
  }
}

// ============================================================
// CONFIGURAÇÕES — Theme, idioma, motor de pesquisa (movido daqui
// do Perfil antigo). Acessada só pelo avatar da Home.
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final panel2 = isDark ? looplyPanel2Dark : looplyPanel2Light;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(toolbarHeight: 68, title: const Text('Configurações')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Geral', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted)),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Symbols.dark_mode_rounded,
              label: 'Theme',
              onTap: () => _showThemeSheet(context),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<SearchEngine>(
              valueListenable: activeSearchEngine,
              builder: (context, engine, _) {
                return _SettingsTile(
                  icon: Symbols.travel_explore_rounded,
                  label: 'Motor de pesquisa',
                  trailing: engine.name,
                  onTap: () => _showEnginePicker(context),
                );
              },
            ),
            const SizedBox(height: 10),
            _SettingsTile(icon: Symbols.language_rounded, label: 'Idioma', trailing: 'Português', onTap: () {}),
            const SizedBox(height: 10),
            _SettingsTile(icon: Symbols.shield_rounded, label: 'Bloqueador de anúncios', trailing: 'Ativo', onTap: () {}),
            const SizedBox(height: 10),
            _SettingsTile(icon: Symbols.speed_rounded, label: 'Acelerador de navegação', trailing: 'Ativo', onTap: () {}),
          ],
        ),
      ),
    );
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.trailing});

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