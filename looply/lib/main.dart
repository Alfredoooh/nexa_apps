import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LooplyApp());
}

// Palette synchronized with Orbit's BrowserPalette.
const Color looplyPrimary = Color(0xFF1A73E8);
const Color looplyBgDark = Color(0xFF111318);
const Color looplyBgLight = Color(0xFFFFFFFF);
const Color looplyPanelDark = Color(0xFF17191F);
const Color looplyPanel2Dark = Color(0xFF292C33);
const Color looplySoftDark = Color(0xFF1D2026);
const Color looplyPanelLight = Color(0xFFFFFFFF);
const Color looplyPanel2Light = Color(0xFFF0F1F3);
const Color looplySoftLight = Color(0xFFF8F9FA);
const Color looplyTextDark = Color(0xFFE3E5EA);
const Color looplyMutedDark = Color(0xFFB6BBC4);
const Color looplyTextLight = Color(0xFF202124);
const Color looplyMutedLight = Color(0xFF5F6368);
const Color looplyLineDark = Color(0xFF353942);
const Color looplyLineLight = Color(0xFFE8EAED);
const Color looplyBlueDark = Color(0xFF8AB4F8);

Color pageBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyBgDark : looplyBgLight;
Color panelColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyPanelDark : looplyPanelLight;
Color pillColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyPanel2Dark : looplyPanel2Light;
Color softColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplySoftDark : looplySoftLight;
Color mainText(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyTextDark : looplyTextLight;
Color mutedText(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyMutedDark : looplyMutedLight;
Color accentColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyBlueDark : looplyPrimary;
Color lineColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyLineDark : looplyLineLight;

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);
  void setMode(ThemeMode mode) => value = mode;
}

final ThemeController themeController = ThemeController();

const Set<String> adBlockDomains = {
  'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
  'google-analytics.com', 'googletagmanager.com', 'googletagservices.com',
  'adservice.google.com', 'adsystem.com', 'amazon-adsystem.com', 'facebook.net',
  'connect.facebook.net', 'fbcdn.net', 'ads.facebook.com', 'taboola.com',
  'outbrain.com', 'criteo.com', 'criteo.net', 'adroll.com', 'adnxs.com',
  'rubiconproject.com', 'pubmatic.com', 'openx.net', 'casalemedia.com',
  'smartadserver.com', 'advertising.com', 'adform.net', 'adtech.com', 'media.net',
  'yieldmo.com', 'bidswitch.net', 'contextweb.com', 'exoclick.com', 'popads.net',
  'propellerads.com', 'revcontent.com', 'mgid.com', 'zedo.com', 'adblade.com',
  'adcolony.com', 'applovin.com', 'chartboost.com', 'unityads.unity3d.com',
  'vungle.com', 'inmobi.com', 'mopub.com', 'scorecardresearch.com',
  'quantserve.com', 'hotjar.com', 'mixpanel.com', 'segment.io', 'segment.com',
  'amplitude.com', 'crazyegg.com', 'optimizely.com', 'newrelic.com', 'nr-data.net',
  'bugsnag.com', 'sentry.io', 'intercom.io', 'drift.com', 'onesignal.com',
  'pushwoosh.com', 'branch.io', 'adjust.com', 'appsflyer.com', 'kochava.com',
  'tapjoy.com', 'ironsrc.com', 'smaato.net', 'sharethrough.com', 'teads.tv',
  'triplelift.com', 'spotxchange.com', 'adsrvr.org', 'turn.com', 'mathtag.com',
  'bluekai.com', 'krxd.net', 'demdex.net', 'everesttech.net', 'serving-sys.com',
  'atdmt.com', 'adbrite.com', 'adtechus.com', 'burstnet.com', 'chitika.com',
  'clicksor.com', 'infolinks.com', 'kontera.com', 'lijit.com', 'media6degrees.com',
  'pointroll.com', 'quantcast.com', 'rlcdn.com', 'simpli.fi', 'tribalfusion.com',
  'tremorhub.com', 'undertone.com', 'yieldlab.net', 'zergnet.com', 'popcash.net',
  'adsterra.com', 'propellerclick.com', 'clickadu.com', 'galaksion.com',
  'adspyglass.com', 'hilltopads.net', 'juicyads.com', 'trafficjunky.com',
  'exosrv.com', 'moatads.com', 'adsafeprotected.com', 'doubleverify.com',
  'ensighten.com', 'tynt.com', 'addthis.com', 'sharethis.com', 'disqus.com',
  'gemius.pl', 'histats.com', 'statcounter.com', 'clicky.com', 'getclicky.com',
  'woopra.com', 'kissmetrics.com', 'heap.io', 'fullstory.com', 'luckyorange.com',
  'mouseflow.com', 'smartlook.com', 'clarity.ms',
};

bool isAdBlockedUrl(String url) {
  try {
    final host = Uri.parse(url).host.toLowerCase();
    if (host.isEmpty) return false;
    return adBlockDomains.any((domain) => host == domain || host.endsWith('.$domain'));
  } catch (_) {
    return false;
  }
}

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
  QuickSite(name: 'X', domain: 'x.com', url: 'https://x.com'),
  QuickSite(name: 'Wikipedia', domain: 'wikipedia.org', url: 'https://www.wikipedia.org'),
];

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
      if (uri.host.isEmpty) return;
      final origin = '${uri.scheme}://${uri.host}';
      if (!_preconnected.add(origin)) return;
      unawaited(http.head(Uri.parse(origin)).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 0)));
    } catch (_) {}
  }

  void cachePage(String url, String html) {
    if (_pageCache.containsKey(url)) {
      _cacheOrder.remove(url);
    } else if (_cacheOrder.length >= _maxCacheEntries) {
      _pageCache.remove(_cacheOrder.removeAt(0));
    }
    _pageCache[url] = html;
    _cacheOrder.add(url);
  }

  String? getCachedPage(String url) => _pageCache[url];
}

enum ActivityKind { site, game }

class ActivityEntry {
  ActivityEntry({required this.kind, required this.title, required this.url, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
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
    final index = _tabs.indexWhere((tab) => tab.kind == TabKind.appScreen && tab.url == screenKey);
    if (index >= 0) {
      final tab = _tabs.removeAt(index);
      tab.thumbnail = thumbnail;
      tab.touch();
      _tabs.insert(0, tab);
      notifyListeners();
      return tab;
    }
    final tab = BrowserTab(
      id: 'tab_${_counter++}', kind: TabKind.appScreen, url: screenKey,
      appScreenLabel: label, appScreenIcon: icon, thumbnail: thumbnail,
    );
    _tabs.insert(0, tab);
    notifyListeners();
    return tab;
  }

  void updateTab(
    String id, {
    String? url,
    String? title,
    bool? canGoBack,
    bool? canGoForward,
    Uint8List? thumbnail,
  }) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tab = _tabs[index];
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (canGoBack != null) tab.canGoBack = canGoBack;
    if (canGoForward != null) tab.canGoForward = canGoForward;
    if (thumbnail != null) tab.thumbnail = thumbnail;
    tab.touch();
    notifyListeners();
  }

  void closeTab(String id) {
    _tabs.removeWhere((tab) => tab.id == id);
    notifyListeners();
  }

  BrowserTab? getTab(String id) {
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  BrowserTab? getAppScreen(String screenKey) {
    for (final tab in _tabs) {
      if (tab.kind == TabKind.appScreen && tab.url == screenKey) return tab;
    }
    return null;
  }
}

final TabsController tabsController = TabsController();

Future<Uint8List?> captureWidgetSnapshot(GlobalKey key, {double pixelRatio = 1.5}) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.attached) {
      await WidgetsBinding.instance.endOfFrame;
    }
    final ready = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (ready == null || !ready.attached) return null;
    final image = await ready.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final pill = isDark ? looplyPanel2Dark : looplyPanel2Light;
    final text = isDark ? looplyTextDark : looplyTextLight;
    final muted = isDark ? looplyMutedDark : looplyMutedLight;
    final accent = isDark ? looplyBlueDark : looplyPrimary;
    final scheme = ColorScheme.fromSeed(seedColor: looplyPrimary, brightness: brightness, surface: panel).copyWith(primary: accent);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: panel,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: isDark ? looplyLineDark : looplyLineLight,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: accent.withOpacity(0.15),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? text : muted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? text : muted)),
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
        fillColor: pill,
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
      builder: (context, mode, _) => MaterialApp(
        title: 'Looply',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const LooplyShell(),
      ),
    );
  }
}

class LooplyGame {
  const LooplyGame({required this.title, required this.category, required this.players, required this.artColor, required this.index, required this.description, this.url});
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
    title: 'Zombie Rush', category: 'Ação', players: '—', artColor: Color(0xFF1D76D2), index: 0,
    description: 'Sobrevive à horda de zombies nesta experiência jogável diretamente na app.',
    url: 'https://raw.githubusercontent.com/CoolDude2349/Offline-HTML-Games-Pack/refs/heads/master/offline/zombie-rush.html',
  ),
];

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
  final Map<String, GlobalKey> _previewKeys = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final List<String> _screenKeys = const ['home_screen', 'games_screen', 'activity_screen'];
  final List<String> _screenLabels = const ['Início', 'Jogos', 'Atividade'];
  final List<IconData> _screenIcons = const [Symbols.home_rounded, Symbols.sports_esports_rounded, Symbols.history_rounded];
  late final AnimationController _morphController;
  OverlayEntry? _morphEntry;
  Uint8List? _lastScreenSnapshot;
  Rect? _lastScreenRect;

  @override
  void initState() {
    super.initState();
    tabsController.addListener(_onTabsChanged);
    ShellTabRequest.instance.addListener(_handleShellTabRequest);
    _morphController = AnimationController(vsync: this, duration: const Duration(milliseconds: 430));
  }

  @override
  void dispose() {
    tabsController.removeListener(_onTabsChanged);
    ShellTabRequest.instance.removeListener(_handleShellTabRequest);
    _morphEntry?.remove();
    _morphController.dispose();
    super.dispose();
  }

  void _onTabsChanged() {
    if (mounted) setState(() {});
  }

  void _handleShellTabRequest() {
    final requested = ShellTabRequest.instance.requestedIndex;
    ShellTabRequest.instance.requestedIndex = null;
    if (requested == null || !mounted) return;
    setState(() => _selectedTab = requested.clamp(0, 2).toInt());
  }

  Rect? _rectInOverlay(GlobalKey key) {
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      final overlayBox = overlay.context.findRenderObject() as RenderBox?;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (overlayBox == null || box == null || !box.attached) return null;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
      return topLeft & box.size;
    } catch (_) {
      return null;
    }
  }

  Rect? _overlayBounds() {
    try {
      final box = Overlay.of(context, rootOverlay: true).context.findRenderObject() as RenderBox?;
      if (box == null) return null;
      return Offset.zero & box.size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _animateSnapshot({required Uint8List bitmap, required Rect from, required Rect to, required bool opening}) async {
    if (!mounted) return;
    _morphEntry?.remove();
    _morphEntry = null;
    _morphController.stop();
    _morphController.value = 0;
    final startRadius = opening ? BorderRadius.zero : BorderRadius.circular(18);
    final endRadius = opening ? BorderRadius.circular(18) : BorderRadius.zero;
    _morphEntry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _morphController,
            builder: (context, _) {
              final t = Curves.easeInOutCubic.transform(_morphController.value);
              final rect = Rect.lerp(from, to, t) ?? to;
              final radius = BorderRadius.lerp(startRadius, endRadius, t) ?? BorderRadius.zero;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Image.memory(bitmap, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_morphEntry!);
    try {
      await _morphController.animateTo(1, curve: Curves.linear);
    } finally {
      _morphEntry?.remove();
      _morphEntry = null;
      if (mounted) setState(() => _morphing = false);
    }
  }

  Future<void> _openTabsGrid() async {
    if (_showingTabsGrid || _morphing) return;
    final sourceRect = _rectInOverlay(_repaintKey);
    final bitmap = await captureWidgetSnapshot(_repaintKey, pixelRatio: 1.35);
    if (!mounted) return;
    if (bitmap == null || sourceRect == null) {
      setState(() => _showingTabsGrid = true);
      return;
    }

    _lastScreenSnapshot = bitmap;
    _lastScreenRect = sourceRect;
    final appTab = tabsController.upsertAppScreenTab(
      _screenKeys[_selectedTab], _screenLabels[_selectedTab], _screenIcons[_selectedTab], bitmap,
    );
    _previewKeys.putIfAbsent(appTab.id, GlobalKey.new);
    _cardKeys.putIfAbsent(appTab.id, GlobalKey.new);
    setState(() {
      _showingTabsGrid = true;
      _morphing = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    final target = _rectInOverlay(_previewKeys[appTab.id]!) ?? _rectInOverlay(_cardKeys[appTab.id]!) ?? sourceRect;
    await _animateSnapshot(bitmap: bitmap, from: sourceRect, to: target, opening: true);
  }

  Future<void> _closeTabsGrid({BrowserTab? openTab}) async {
    if (_morphing || !_showingTabsGrid) return;
    final tab = openTab ?? tabsController.getAppScreen(_screenKeys[_selectedTab]);
    final sourceKey = tab == null ? null : (_previewKeys[tab.id] ?? _cardKeys[tab.id]);
    final sourceRect = sourceKey == null ? null : _rectInOverlay(sourceKey);
    Uint8List? bitmap = tab?.thumbnail ?? _lastScreenSnapshot;
    if (bitmap == null && sourceKey != null) bitmap = await captureWidgetSnapshot(sourceKey, pixelRatio: 1.3);
    if (!mounted) return;

    if (openTab != null && openTab.kind == TabKind.browser) {
      setState(() {
        _showingTabsGrid = false;
        _morphing = bitmap != null && sourceRect != null;
      });
      Navigator.of(context).push(_instantBrowserRoute(openTab));
      await WidgetsBinding.instance.endOfFrame;
      final destination = _overlayBounds();
      if (bitmap != null && sourceRect != null && destination != null) {
        await _animateSnapshot(bitmap: bitmap, from: sourceRect, to: destination, opening: false);
      } else if (mounted) {
        setState(() => _morphing = false);
      }
      return;
    }

    if (openTab != null && openTab.kind == TabKind.appScreen) {
      final index = _screenKeys.indexOf(openTab.url);
      if (index >= 0) _selectedTab = index;
    }
    setState(() {
      _showingTabsGrid = false;
      _morphing = bitmap != null && sourceRect != null;
    });
    await WidgetsBinding.instance.endOfFrame;
    final destination = _rectInOverlay(_repaintKey);
    if (bitmap != null && sourceRect != null && destination != null) {
      await _animateSnapshot(bitmap: bitmap, from: sourceRect, to: destination, opening: false);
    } else if (mounted) {
      setState(() => _morphing = false);
    }
  }

  PageRoute<void> _instantBrowserRoute(BrowserTab tab) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => BrowserScreen(tabId: tab.id, initialUrl: tab.url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = mainText(context);
    final pages = const <Widget>[HomeScreen(), GamesScreen(), ActivityScreen()];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        body: Stack(
          key: _rootKey,
          children: [
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
            if (_showingTabsGrid)
              TabsGridScreen(
                previewKeys: _previewKeys,
                cardKeys: _cardKeys,
                onSelectTab: (tab) => _closeTabsGrid(openTab: tab),
                onClose: () => _closeTabsGrid(),
                onNewTab: () {
                  final tab = tabsController.createBrowserTab('https://www.google.com');
                  _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
                  _cardKeys.putIfAbsent(tab.id, GlobalKey.new);
                  _closeTabsGrid(openTab: tab);
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
            destinations: [
              const NavigationDestination(icon: Icon(Symbols.home_rounded), selectedIcon: Icon(Symbols.home_rounded, fill: 1), label: 'Início'),
              const NavigationDestination(icon: Icon(Symbols.sports_esports_rounded), selectedIcon: Icon(Symbols.sports_esports_rounded, fill: 1), label: 'Jogos'),
              NavigationDestination(icon: _TabsCountIcon(count: tabsController.count, color: text), selectedIcon: _TabsCountIcon(count: tabsController.count, color: text), label: 'Abas'),
              const NavigationDestination(icon: Icon(Symbols.history_rounded), selectedIcon: Icon(Symbols.history_rounded, fill: 1), label: 'Atividade'),
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
  Widget build(BuildContext context) => Container(
    width: 23, height: 23, alignment: Alignment.center,
    decoration: BoxDecoration(border: Border.all(color: color.withOpacity(.85), width: 1.5), borderRadius: BorderRadius.circular(6)),
    child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, height: 1)),
  );
}

class TabsGridScreen extends StatefulWidget {
  const TabsGridScreen({super.key, required this.onSelectTab, required this.onClose, required this.onNewTab, required this.previewKeys, required this.cardKeys});
  final ValueChanged<BrowserTab> onSelectTab;
  final VoidCallback onClose;
  final VoidCallback onNewTab;
  final Map<String, GlobalKey> previewKeys;
  final Map<String, GlobalKey> cardKeys;
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
  void _onChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplySoftDark : looplySoftLight;
    final text = mainText(context);
    final muted = mutedText(context);
    final tabs = tabsController.tabs;
    return Material(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fechar separadores',
                    style: IconButton.styleFrom(backgroundColor: pillColor(context), foregroundColor: text, fixedSize: const Size(42, 42)),
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Separadores', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800)),
                    Text('${tabs.length} ${tabs.length == 1 ? 'aba aberta' : 'abas abertas'}', style: TextStyle(color: muted, fontSize: 12)),
                  ])),
                  IconButton(
                    tooltip: 'Nova aba',
                    style: IconButton.styleFrom(backgroundColor: accentColor(context), foregroundColor: isDark ? const Color(0xFF111318) : Colors.white, fixedSize: const Size(46, 46)),
                    icon: const Icon(Symbols.add_rounded),
                    onPressed: widget.onNewTab,
                  ),
                ],
              ),
            ),
            Expanded(
              child: tabs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Symbols.tab_rounded, size: 44, color: muted), const SizedBox(height: 10), Text('Nenhuma aba aberta', style: TextStyle(color: text, fontWeight: FontWeight.w600))]))
                  : LayoutBuilder(builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
                        itemCount: tabs.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .77,
                        ),
                        itemBuilder: (context, index) {
                          final tab = tabs[index];
                          final previewKey = widget.previewKeys.putIfAbsent(tab.id, GlobalKey.new);
                          final cardKey = widget.cardKeys.putIfAbsent(tab.id, GlobalKey.new);
                          return RepaintBoundary(
                            key: cardKey,
                            child: TabGridCard(
                              tab: tab,
                              previewKey: previewKey,
                              onTap: () => widget.onSelectTab(tab),
                              onClose: tab.kind == TabKind.browser ? () => tabsController.closeTab(tab.id) : null,
                            ),
                          );
                        },
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

class TabGridCard extends StatelessWidget {
  const TabGridCard({super.key, required this.tab, required this.previewKey, required this.onTap, this.onClose});
  final BrowserTab tab;
  final GlobalKey previewKey;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? looplyPanelDark : looplyPanelLight;
    final bg = isDark ? looplyBgDark : looplySoftLight;
    final muted = mutedText(context);
    final text = mainText(context);
    final isApp = tab.kind == TabKind.appScreen;
    final host = Uri.tryParse(tab.url)?.host ?? '';
    final label = isApp ? (tab.appScreenLabel ?? 'Looply') : ((tab.title?.trim().isNotEmpty ?? false) ? tab.title! : (host.isEmpty ? tab.url : host));

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
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 7),
              child: Row(children: [
                if (isApp)
                  Icon(tab.appScreenIcon ?? Symbols.apps_rounded, size: 17, color: muted)
                else
                  CachedNetworkImage(
                    imageUrl: 'https://www.google.com/s2/favicons?domain=$host&sz=64', width: 17, height: 17, fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => Icon(Symbols.public_rounded, color: muted, size: 17),
                    placeholder: (_, __) => const SizedBox.shrink(),
                  ),
                const SizedBox(width: 7),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600))),
                if (onClose != null)
                  SizedBox(
                    width: 28, height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Fechar aba',
                      style: IconButton.styleFrom(backgroundColor: pillColor(context), foregroundColor: muted),
                      icon: const Icon(Symbols.close_rounded, size: 15),
                      onPressed: onClose,
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ClipRRect(
                  key: previewKey,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: double.infinity,
                    color: bg,
                    child: tab.thumbnail != null
                        ? Image.memory(tab.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => Center(child: Icon(Symbols.public_rounded, size: 32, color: muted.withOpacity(.55))))
                        : Center(child: Icon(isApp ? (tab.appScreenIcon ?? Symbols.apps_rounded) : Symbols.public_rounded, size: 34, color: muted.withOpacity(.40))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openSettings() {
    _scaffoldKey.currentState?.closeDrawer();
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    });
  }

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: pageBg(context),
      drawer: Drawer(
        backgroundColor: pageBg(context),
        width: MediaQuery.of(context).size.width * .82,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: accentColor(context).withOpacity(.14), borderRadius: BorderRadius.circular(14)), child: Icon(Symbols.public_rounded, color: accentColor(context), size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Looply', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800))),
                ]),
              ),
              Divider(height: 1, color: lineColor(context)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor(context).withOpacity(.15)), child: Icon(Symbols.person_rounded, color: accentColor(context), size: 23)),
                title: Text('Utilizador', style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                subtitle: Text('Configurações e preferências', style: TextStyle(color: muted, fontSize: 12)),
                trailing: Icon(Symbols.chevron_right_rounded, color: muted),
                onTap: _openSettings,
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: lineColor(context)),
              ListTile(leading: Icon(Symbols.home_rounded, color: muted), title: Text('Início', style: TextStyle(color: text)), onTap: _closeDrawer),
              ListTile(leading: Icon(Symbols.sports_esports_rounded, color: muted), title: Text('Jogos', style: TextStyle(color: text)), onTap: () { _closeDrawer(); _goToShellTab(1); }),
              ListTile(leading: Icon(Symbols.history_rounded, color: muted), title: Text('Atividade', style: TextStyle(color: text)), onTap: () { _closeDrawer(); _goToShellTab(2); }),
              const Spacer(),
              Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 18), child: Text('Looply Browser', style: TextStyle(color: muted, fontSize: 12))),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 28),
          children: [
            // The search control is the first item at the top; its menu icon
            // replaces the magnifying glass and opens the real navigation drawer.
            const LooplyBigSearchBox(),
            const SizedBox(height: 25),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Sites rápidos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quickSites.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 16, childAspectRatio: 1.08),
                itemBuilder: (context, index) => RepaintBoundary(child: QuickSiteTile(site: quickSites[index])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToShellTab(int index) {
    // The drawer is hosted by the Home page in the shell. The surrounding
    // IndexedStack remains intact; this event is handled through a notification.
    ShellTabRequest.instance.request(index);
  }
}

class ShellTabRequest extends ChangeNotifier {
  ShellTabRequest._();
  static final ShellTabRequest instance = ShellTabRequest._();
  int? requestedIndex;
  void request(int index) { requestedIndex = index; notifyListeners(); }
}

class LooplyBigSearchBox extends StatelessWidget {
  const LooplyBigSearchBox({super.key});
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Container(
      height: 54,
      decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        const SizedBox(width: 3),
        IconButton(
          tooltip: 'Abrir menu',
          style: IconButton.styleFrom(foregroundColor: muted, fixedSize: const Size(46, 46)),
          icon: const Icon(Symbols.menu_rounded, size: 23),
          onPressed: () => _openHomeDrawer(context),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Pesquisar ou escrever um endereço',
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
              child: Align(alignment: Alignment.centerLeft, child: Text('Pesquisar ou escrever um URL', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 15))),
            ),
          ),
        ),
        const SizedBox(width: 15),
      ]),
    );
  }

  void _openHomeDrawer(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    state?._scaffoldKey.currentState?.openDrawer();
  }
}

class QuickSiteTile extends StatelessWidget {
  const QuickSiteTile({super.key, required this.site});
  final QuickSite site;
  @override
  Widget build(BuildContext context) {
    final panel = panelColor(context);
    final text = mainText(context);
    return GestureDetector(
      onTapDown: (_) => NavAccelerator.instance.preconnect(site.url),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openNewTab(context, site.url, title: site.name),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 54, height: 54, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: panel, shape: BoxShape.circle),
            child: CachedNetworkImage(
              imageUrl: site.faviconUrl, fit: BoxFit.contain, fadeInDuration: const Duration(milliseconds: 100),
              errorWidget: (_, __, ___) => Icon(Symbols.public_rounded, color: text, size: 22),
              placeholder: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 7),
          Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: text)),
        ]),
      ),
    );
  }
}

void openNewTab(BuildContext context, String url, {String? title}) {
  final tab = tabsController.createBrowserTab(url);
  activityController.log(ActivityKind.site, title ?? url, url);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => BrowserScreen(tabId: tab.id, initialUrl: url)));
}

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(toolbarHeight: 64, title: const Text('Jogos')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: looplyGames.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .82),
          itemBuilder: (context, index) => RepaintBoundary(child: GameCard(game: looplyGames[index])),
        ),
      ]),
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game});
  final LooplyGame game;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: panelColor(context), borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: game.url == null ? null : () {
          activityController.log(ActivityKind.game, game.title, game.url!);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameWebViewScreen(game: game)));
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SizedBox(width: double.infinity, child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: GameArtPainter(game: game)),
            Positioned(top: 9, left: 9, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: const Color(0xCC0B0D11), borderRadius: BorderRadius.circular(9)), child: Text(game.category.toUpperCase(), style: const TextStyle(fontSize: 8, letterSpacing: .5, color: Colors.white, fontWeight: FontWeight.w800)))),
            const Positioned(right: 9, bottom: 9, child: Icon(Symbols.play_circle_rounded, fill: 1, color: Colors.white, size: 29)),
          ]))),
          Padding(padding: const EdgeInsets.fromLTRB(11, 10, 11, 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 5),
            Row(children: [const Icon(Symbols.circle_rounded, fill: 1, size: 5, color: Color(0xFF50D890)), const SizedBox(width: 4), Text('Disponível', style: TextStyle(fontSize: 10, color: muted))]),
          ])),
        ]),
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
  InAppWebViewController? _webController;
  @override
  void dispose() {
    _webController?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(leading: IconButton(icon: const Icon(Symbols.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()), title: Text(widget.game.title)),
        body: Stack(children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.game.url!)),
            initialSettings: InAppWebViewSettings(javaScriptEnabled: true, mediaPlaybackRequiresUserGesture: false, transparentBackground: true, cacheMode: CacheMode.LOAD_DEFAULT, hardwareAcceleration: true),
            shouldInterceptRequest: (controller, request) async {
              final url = request.url.toString();
              if (isAdBlockedUrl(url)) return WebResourceResponse(contentType: 'text/plain', data: Uint8List(0));
              if (url == widget.game.url && (request.method == null || request.method == 'GET')) {
                try {
                  final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
                  if (response.statusCode == 200) return WebResourceResponse(contentType: 'text/html', contentEncoding: 'utf-8', data: response.bodyBytes);
                } catch (_) {}
              }
              return null;
            },
            onWebViewCreated: (controller) => _webController = controller,
            onLoadStart: (_, __) { if (mounted) setState(() => _isLoading = true); },
            onLoadStop: (_, __) { if (mounted) setState(() => _isLoading = false); },
            onReceivedError: (_, __, ___) { if (mounted) setState(() => _isLoading = false); },
          ),
          if (_isLoading) Container(color: bg, child: Center(child: CircularProgressIndicator(color: accentColor(context)))),
        ]),
      ),
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
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _focusNode.requestFocus(); });
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
    _debounce = Timer(const Duration(milliseconds: 220), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final sequence = ++_requestSequence;
    try {
      final uri = Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&q=${Uri.encodeQueryComponent(query)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 || !mounted || sequence != _requestSequence) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final list = (decoded.length > 1 ? decoded[1] as List<dynamic> : <dynamic>[]).map((item) => item.toString()).toList();
      if (mounted && sequence == _requestSequence) setState(() => _suggestions = list);
    } catch (_) {}
  }

  void _submitSearch(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    final url = _looksLikeUrl(value) ? _normalizeUrl(value) : activeSearchEngine.value.buildUrl(value);
    NavAccelerator.instance.preconnect(url);
    final tab = tabsController.createBrowserTab(url);
    activityController.log(ActivityKind.site, value, url);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BrowserScreen(tabId: tab.id, initialUrl: url)));
  }

  bool _looksLikeUrl(String text) => !text.contains(' ') && (text.contains('.') || text.startsWith('localhost'));
  String _normalizeUrl(String text) => (text.startsWith('http://') || text.startsWith('https://')) ? text : 'https://$text';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 3, 14, 8),
              child: Row(children: [
                IconButton(tooltip: 'Voltar', icon: Icon(Symbols.arrow_back_rounded, color: text), onPressed: () => Navigator.of(context).pop()),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: text, fontSize: 17),
                      cursorColor: accentColor(context),
                      onSubmitted: _submitSearch,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: bg,
                        hintText: 'Pesquisar ou escrever um URL',
                        hintStyle: TextStyle(color: muted, fontSize: 15),
                        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(tooltip: 'Limpar', icon: Icon(Symbols.close_rounded, color: muted), onPressed: () { _controller.clear(); _focusNode.requestFocus(); }),
              ]),
            ),
            Divider(height: 1, color: lineColor(context)),
            Expanded(
              child: _suggestions.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          leading: Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: Icon(Symbols.search_rounded, color: muted, size: 18)),
                          title: Text(suggestion, style: TextStyle(color: text, fontSize: 15)),
                          onTap: () { _controller.text = suggestion; _submitSearch(suggestion); },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

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
  bool _addressBarVisible = true;
  int _lastScrollY = 0;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: looplyPrimary),
      onRefresh: () async { await _controller?.reload(); },
    );
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _updateTabState({Uint8List? screenshot}) {
    tabsController.updateTab(widget.tabId, url: _currentUrl, title: _currentTitle.isNotEmpty ? _currentTitle : _currentUrl, canGoBack: _canGoBack, canGoForward: _canGoForward, thumbnail: screenshot);
  }

  void _onScrollChanged(int y) {
    final dy = y - _lastScrollY;
    _lastScrollY = y;
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      if (dy > 14 && _addressBarVisible) setState(() => _addressBarVisible = false);
      else if (dy < -14 && !_addressBarVisible) setState(() => _addressBarVisible = true);
    });
  }

  Future<bool> _handleBack() async {
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
    final bg = pageBg(context);
    final muted = mutedText(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleBack() && mounted) Navigator.of(context).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: bg,
          body: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: _addressBarVisible ? (60 + MediaQuery.of(context).padding.top) : 0,
              clipBehavior: Clip.hardEdge,
              child: OverflowBox(
                minHeight: 60 + MediaQuery.of(context).padding.top,
                maxHeight: 60 + MediaQuery.of(context).padding.top,
                alignment: Alignment.bottomCenter,
                child: _AddressBar(title: _currentTitle.isNotEmpty ? _currentTitle : _currentUrl, url: _currentUrl, isLoading: _isLoading, onReload: () => _controller?.reload()),
              ),
            ),
            if (_isLoading) SizedBox(height: 2, child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, color: accentColor(context), backgroundColor: muted.withOpacity(.15))),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                pullToRefreshController: _pullToRefreshController,
                initialSettings: InAppWebViewSettings(javaScriptEnabled: true, mediaPlaybackRequiresUserGesture: false, transparentBackground: true, cacheMode: CacheMode.LOAD_DEFAULT, hardwareAcceleration: true),
                shouldOverrideUrlLoading: (controller, action) async {
                  final uri = action.request.url;
                  if (uri == null) return NavigationActionPolicy.ALLOW;
                  final scheme = uri.scheme.toLowerCase();
                  return {'http', 'https', 'about', 'data', 'blob'}.contains(scheme) ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
                },
                shouldInterceptRequest: (controller, request) async {
                  if (isAdBlockedUrl(request.url.toString())) return WebResourceResponse(contentType: 'text/plain', data: Uint8List(0));
                  return null;
                },
                onWebViewCreated: (controller) => _controller = controller,
                onProgressChanged: (controller, progress) { if (mounted) setState(() => _progress = progress / 100); },
                onLoadStart: (controller, url) {
                  if (!mounted) return;
                  setState(() { _isLoading = true; if (url != null) _currentUrl = url.toString(); });
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
                  Uint8List? screenshot;
                  try { screenshot = await controller.takeScreenshot(); } catch (_) {}
                  String? html;
                  try { html = await controller.getHtml(); } catch (_) {}
                  if (html != null) NavAccelerator.instance.cachePage(_currentUrl, html);
                  if (!mounted) return;
                  setState(() {
                    _isLoading = false;
                    _canGoBack = back;
                    _canGoForward = forward;
                    if (url != null) _currentUrl = url.toString();
                  });
                  _updateTabState(screenshot: screenshot);
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
              onTabs: () { _updateTabState(); Navigator.of(context).popUntil((route) => route.isFirst); },
              onHome: () { _updateTabState(); Navigator.of(context).popUntil((route) => route.isFirst); },
            ),
          ]),
        ),
      ),
    );
  }

  void _showPageMenu(BuildContext context) {
    final text = mainText(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panelColor(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Symbols.refresh_rounded, color: text), title: Text('Atualizar página', style: TextStyle(color: text)), onTap: () { Navigator.pop(sheetContext); _controller?.reload(); }),
        ListTile(leading: Icon(Symbols.tab_rounded, color: text), title: Text('Nova aba', style: TextStyle(color: text)), onTap: () { Navigator.pop(sheetContext); openNewTab(context, 'https://www.google.com'); }),
        ListTile(leading: Icon(Symbols.close_rounded, color: text), title: Text('Fechar aba', style: TextStyle(color: text)), onTap: () { Navigator.pop(sheetContext); tabsController.closeTab(widget.tabId); Navigator.of(context).pop(); }),
      ]))),
    );
  }
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({required this.title, required this.url, required this.isLoading, required this.onReload});
  final String title;
  final String url;
  final bool isLoading;
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final host = Uri.tryParse(url)?.host ?? '';
    return Container(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 8, 12, 8),
      color: bg,
      child: Container(
        height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          CachedNetworkImage(imageUrl: 'https://www.google.com/s2/favicons?domain=$host&sz=64', width: 20, height: 20, fit: BoxFit.contain, errorWidget: (_, __, ___) => Icon(Symbols.public_rounded, color: muted, size: 20), placeholder: (_, __) => const SizedBox.shrink()),
          const SizedBox(width: 10),
          Expanded(child: Text(title.isEmpty ? host : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600))),
          GestureDetector(onTap: onReload, child: isLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor(context))) : Icon(Symbols.refresh_rounded, color: muted, size: 20)),
        ]),
      ),
    );
  }
}

class _BrowserBottomBar extends StatelessWidget {
  const _BrowserBottomBar({required this.canGoBack, required this.canGoForward, required this.onBack, required this.onForward, required this.onMenu, required this.onTabs, required this.onHome});
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onMenu;
  final VoidCallback onTabs;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return AnimatedBuilder(
      animation: tabsController,
      builder: (context, _) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: lineColor(context)))),
        child: SizedBox(height: 52, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(tooltip: 'Voltar', icon: Icon(Symbols.arrow_back_rounded, color: canGoBack ? text : muted.withOpacity(.4)), onPressed: canGoBack ? onBack : null),
          IconButton(tooltip: 'Avançar', icon: Icon(Symbols.arrow_forward_rounded, color: canGoForward ? text : muted.withOpacity(.4)), onPressed: canGoForward ? onForward : null),
          IconButton(tooltip: 'Menu', icon: Icon(Symbols.menu_rounded, color: text), onPressed: onMenu),
          IconButton(tooltip: 'Abas', icon: _TabsCountIcon(count: tabsController.count, color: text), onPressed: onTabs),
          IconButton(tooltip: 'Início', icon: Icon(Symbols.home_rounded, color: text), onPressed: onHome),
        ])),
      ),
    );
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() { super.initState(); activityController.addListener(_onChanged); }
  @override
  void dispose() { activityController.removeListener(_onChanged); super.dispose(); }
  void _onChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = activityController.entries;
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(toolbarHeight: 64, title: const Text('Atividade'), actions: [if (entries.isNotEmpty) IconButton(tooltip: 'Limpar atividade', icon: Icon(Symbols.delete_sweep_rounded, color: text), onPressed: activityController.clear)]),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Symbols.history_rounded, size: 48, color: muted), const SizedBox(height: 12), Text('Sem atividade recente', style: TextStyle(color: text, fontWeight: FontWeight.w700))]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), itemCount: entries.length, separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isGame = entry.kind == ActivityKind.game;
                return Material(
                  color: panelColor(context), borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: Container(width: 40, height: 40, padding: const EdgeInsets.all(9), decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: isGame ? Icon(Symbols.sports_esports_rounded, color: accentColor(context), size: 20) : CachedNetworkImage(imageUrl: 'https://www.google.com/s2/favicons?domain=${Uri.tryParse(entry.url)?.host ?? ''}&sz=64', fit: BoxFit.contain, errorWidget: (_, __, ___) => Icon(Symbols.public_rounded, color: muted, size: 18), placeholder: (_, __) => const SizedBox.shrink())),
                    title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                    subtitle: Text(_formatTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 12)),
                    onTap: () {
                      if (isGame) {
                        final game = looplyGames.firstWhere((g) => g.url == entry.url, orElse: () => looplyGames.first);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameWebViewScreen(game: game)));
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
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} dias';
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: pageBg(context), statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: pageBg(context), statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: pageBg(context),
        appBar: AppBar(toolbarHeight: 64, title: const Text('Configurações')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 10), child: Text('Geral', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted))),
          _SettingsTile(icon: Symbols.dark_mode_rounded, label: 'Tema', onTap: () => _showThemeSheet(context), trailing: _themeLabel(themeController.value)),
          const SizedBox(height: 9),
          ValueListenableBuilder<SearchEngine>(valueListenable: activeSearchEngine, builder: (context, engine, _) => _SettingsTile(icon: Symbols.travel_explore_rounded, label: 'Motor de pesquisa', trailing: engine.name, onTap: () => _showEnginePicker(context))),
          const SizedBox(height: 9),
          const _SettingsTile(icon: Symbols.language_rounded, label: 'Idioma', trailing: 'Português'),
          const SizedBox(height: 9),
          const _SettingsTile(icon: Symbols.shield_rounded, label: 'Bloqueador de anúncios', trailing: 'Ativo'),
          const SizedBox(height: 9),
          const _SettingsTile(icon: Symbols.speed_rounded, label: 'Acelerador de navegação', trailing: 'Ativo'),
        ]),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) { ThemeMode.light => 'Claro', ThemeMode.dark => 'Escuro', _ => 'Automático' };

  void _showThemeSheet(BuildContext context) {
    final text = mainText(context);
    showModalBottomSheet<void>(
      context: context, backgroundColor: panelColor(context), showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, _) => SafeArea(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Tema', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)))),
          RadioListTile<ThemeMode>(value: ThemeMode.light, groupValue: mode, activeColor: accentColor(context), title: Text('Claro', style: TextStyle(color: text)), onChanged: (v) { if (v != null) themeController.setMode(v); }),
          RadioListTile<ThemeMode>(value: ThemeMode.dark, groupValue: mode, activeColor: accentColor(context), title: Text('Escuro', style: TextStyle(color: text)), onChanged: (v) { if (v != null) themeController.setMode(v); }),
          RadioListTile<ThemeMode>(value: ThemeMode.system, groupValue: mode, activeColor: accentColor(context), title: Text('Automático (sistema)', style: TextStyle(color: text)), onChanged: (v) { if (v != null) themeController.setMode(v); }),
        ]))),
      ),
    );
  }

  void _showEnginePicker(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    showModalBottomSheet<void>(
      context: context, backgroundColor: panelColor(context), showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Motor de pesquisa', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800)))),
        ...searchEngines.map((engine) => ListTile(
          leading: Container(width: 34, height: 34, padding: const EdgeInsets.all(6), decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: CachedNetworkImage(imageUrl: engine.faviconUrl, fit: BoxFit.contain, errorWidget: (_, __, ___) => Icon(Symbols.public_rounded, color: muted, size: 18), placeholder: (_, __) => const SizedBox.shrink())),
          title: Text(engine.name, style: TextStyle(color: text)),
          trailing: ValueListenableBuilder<SearchEngine>(valueListenable: activeSearchEngine, builder: (_, active, __) => active.name == engine.name ? Icon(Symbols.check_circle_rounded, color: accentColor(context), fill: 1) : const SizedBox.shrink()),
          onTap: () { activeSearchEngine.value = engine; Navigator.of(sheetContext).pop(); },
        )),
      ]))),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: panelColor(context), borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: Icon(icon, color: accentColor(context), size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600))),
          if (trailing != null) Text(trailing!, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(width: 6),
          Icon(Symbols.chevron_right_rounded, color: muted, size: 18),
        ])),
      ),
    );
  }
}
