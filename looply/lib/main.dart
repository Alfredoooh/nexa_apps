import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'auth_service.dart';
import 'cloud_sync.dart';
import 'browser_library.dart';
import 'screens/home_screen.dart';
import 'screens/orbit_browser_screen.dart';
import 'widgets/drawer_menu.dart' as drawer_menu hide TabsGridScreen;
import 'session_store.dart';
import 'shell/shell_tab_request.dart';
import 'shell/tabs_grid_screen.dart';
import 'theme.dart';
import 'localization.dart';
import 'widgets/material_symbols.dart';
import 'widgets/global_sites_fab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Apenas os dados necessários para a primeira composição são aguardados.
  // Histórico, favoritos, downloads e caches são restaurados após o primeiro
  // frame para que nenhum armazenamento secundário prolongue o splash.
  await themeController.restore();
  await Future.wait<void>(<Future<void>>[
    appLanguageController.restore(),
    tabsController.restore(),
    authController.restore(),
  ].map(_safeStartupRestore));

  runApp(const LooplyApp());

  // Restaura os restantes dados em paralelo sem bloquear a apresentação.
  unawaited(Future.wait<void>(<Future<void>>[
    activityController.restore(),
    searchHistoryController.restore(),
    customSitesController.restore(),
    activeSearchEngine.restore(),
    restoreRuntimeSettings(),
    AdBlockStats.instance.restore(),
    browserFaviconCache.restore(),
    bookmarksController.restore(),
    downloadsController.restore(),
  ].map(_safeStartupRestore)));
}

Future<void> _safeStartupRestore(Future<void> restore) async {
  try {
    await restore;
  } catch (_) {
    // Uma preferência danificada ou indisponível não deve bloquear o arranque.
  }
}


class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguageController,
      builder: (context, language, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, __) => ValueListenableBuilder<bool>(
          valueListenable: themeController.pureDark,
          builder: (context, pureBlack, ___) => MaterialApp(
            navigatorKey: browseItNavigatorKey,
            title: 'BrowseIt',
            debugShowCheckedModeBanner: false,
            builder: (context, child) => M3ETheme(
              // Converte o ColorScheme ativo do Looply (claro, escuro ou AMOLED)
              // para os tokens próprios dos componentes Material 3 Expressive.
              data: buildM3EThemeDefaults(
                colorScheme: M3EColorScheme.fromColorScheme(
                  Theme.of(context).colorScheme,
                ),
              ),
              child: MaterialUiCompatibilityBridge(
                // Compatibilidade para dependências antigas que ainda
                // importam package:flutter/material.dart.
                child: Directionality(
                  textDirection: language.code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: Builder(
                    builder: (overlayContext) {
                      final activeTheme = Theme.of(overlayContext);
                      final dark = activeTheme.brightness == Brightness.dark;
                      final systemBackground = activeTheme.scaffoldBackgroundColor;
                      final systemOverlay = (dark
                              ? SystemUiOverlayStyle.light
                              : SystemUiOverlayStyle.dark)
                          .copyWith(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                        systemNavigationBarColor: systemBackground,
                        systemNavigationBarDividerColor: systemBackground,
                        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
                        systemNavigationBarContrastEnforced: false,
                                              );

                      return AnnotatedRegion<SystemUiOverlayStyle>(
                        value: systemOverlay,
                        child: ColoredBox(
                          color: systemBackground,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // SafeArea envolve o Navigator inteiro, incluindo rotas
                              // push e modais. Assim, nenhuma página ou sheet pode
                              // desenhar conteúdo por baixo dos botões do Android.
                              SafeArea(
                                top: false,
                                bottom: true,
                                child: child ?? const SizedBox.shrink(),
                              ),
                              const Positioned.fill(child: GlobalSitesFloatingButton()),
                              // Offstage mantém os glifos Rounded necessários à Activity
                              // Kotlin dentro da fonte submetida ao icon tree-shaker.
                              Positioned(
                                left: -10000,
                                top: -10000,
                                child: ExcludeSemantics(
                                  child: Offstage(
                                    child: Row(
                                      children: [
                                        for (final symbol in AppIcons.nativeBrowserGlyphs)
                                          Icon(symbol, size: 24, weight: 400, opticalSize: 24),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            locale: language.locale,
            supportedLocales: supportedAppLanguages.map((item) => item.locale).toList(growable: false),
            themeMode: mode,
            themeAnimationDuration: Duration.zero,
            theme: buildLooplyTheme(Brightness.light),
            darkTheme: buildLooplyTheme(Brightness.dark, pureBlack: pureBlack),
            home: const LooplyShell(),
          ),
        ),
      ),
    );
  }
}

Future<Uint8List?> captureWidgetSnapshot(GlobalKey key, {double pixelRatio = 1.5}) async {
  try {
    // Aguarda o frame atual terminar para não capturar um RenderObject a meio
    // de um layout/paint causado pela troca de rota ou pela atualização da aba.
    await WidgetsBinding.instance.endOfFrame;
    var renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || !renderObject.attached) {
      await WidgetsBinding.instance.endOfFrame;
      renderObject = key.currentContext?.findRenderObject();
    }
    if (renderObject is! RenderRepaintBoundary ||
        !renderObject.attached ||
        renderObject.size.isEmpty) {
      return null;
    }
    if (renderObject.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }

    final ready = key.currentContext?.findRenderObject();
    if (ready is! RenderRepaintBoundary || !ready.attached || ready.size.isEmpty) {
      return null;
    }

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


class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});
  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _showingTabsGrid = false;
  bool _morphing = false;
  Completer<void>? _tabsGridPositionCompleter;
  bool _skipNextNativeEnterAnimation = false;
  String? _activeBrowserTabId;
  final Map<String, GlobalKey> _browserViewportKeys = {};
  final Map<String, Completer<void>> _browserFirstLoads = {};
  // Sinaliza quando a WebView nativa hospedada pelo Android está pronta.
  // A entrada do browser só começa depois deste ponto, evitando iniciar a
  // transição enquanto a Activity Kotlin prepara a primeira composição.
  final Map<String, Completer<void>> _browserPlatformReady = {};
  final GlobalKey _repaintKey = GlobalKey();
  final Map<String, GlobalKey> _previewKeys = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final Map<String, GlobalKey> _homePreviewKeys = {};
  // As páginas principais são Início e Atividade.
  final List<String> _screenKeys = const ['home_screen'];
  List<String> get _screenLabels => <String>[appText('home')];
  final List<IconData> _screenIcons = const [AppIcons.house];
  late final AnimationController _morphController;
  late final AnimationController _browserFadeController;
  late final AnimationController _drawerController;
  late final Animation<double> _browserFadeOpacity;
  OverlayEntry? _morphEntry;
  ImageProvider? _morphImage;
  Rect? _morphFrom;
  Rect? _morphTo;
  bool _morphOpening = true;
  Uint8List? _lastScreenSnapshot;
  String? _preferredReturnTabId;
  bool _restoreChecked = false;
  int _lastObservedTabCount = 0;
  late final List<Listenable> _cloudSyncSources;
  static const MethodChannel _defaultBrowserIntentChannel = MethodChannel('browseit/default_browser');

  void _onCloudSyncSourceChanged() {
    BrowseItCloudSync.scheduleAppBackup();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudSyncSources = <Listenable>[
      themeController,
      themeController.pureDark,
      appLanguageController,
      tabsController,
      activityController,
      searchHistoryController,
      customSitesController,
      activeSearchEngine,
      AdBlockStats.instance,
      browserFaviconCache,
      bookmarksController,
      downloadsController,
    ];
    for (final source in _cloudSyncSources) {
      source.addListener(_onCloudSyncSourceChanged);
    }
    _lastObservedTabCount = tabsController.count;
    tabsController.addListener(_onTabsChanged);
    ShellTabRequest.instance.addListener(_handleShellTabRequest);
    _defaultBrowserIntentChannel.setMethodCallHandler(_handleDefaultBrowserIntent);
    _morphController = AnimationController(vsync: this, duration: const Duration(milliseconds: 430));
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      reverseDuration: const Duration(milliseconds: 520),
    );
    drawer_menu.LooplyDrawerBridge.open = _openShellDrawer;
    drawer_menu.LooplyDrawerBridge.close = _closeShellDrawer;
    _browserFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 390),
    )..value = 1;
    _browserFadeOpacity = CurvedAnimation(
      parent: _browserFadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRestoreSession();
      _consumePendingDefaultBrowserUrls();
    });
  }

  Future<dynamic> _handleDefaultBrowserIntent(MethodCall call) async {
    if (call.method != 'openUrl') return null;
    final url = call.arguments?.toString() ?? '';
    _openExternalBrowserUrl(url);
    return true;
  }

  Future<void> _consumePendingDefaultBrowserUrls() async {
    try {
      while (mounted) {
        final url = await _defaultBrowserIntentChannel.invokeMethod<String>('consumeInitialUrl');
        if (url == null || url.isEmpty) break;
        _openExternalBrowserUrl(url);
      }
    } on PlatformException {
      // A aplicação continua a poder ser usada normalmente se não tiver sido
      // aberta através de um link externo.
    } on MissingPluginException {
      // O canal só existe na implementação Android nativa do BrowseIt.
    }
  }

  void _openExternalBrowserUrl(String rawUrl) {
    if (!mounted) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return;
    final tab = tabsController.createBrowserTab(uri.toString());
    ShellTabRequest.instance.requestBrowser(tab.id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final source in _cloudSyncSources) {
      source.removeListener(_onCloudSyncSourceChanged);
    }
    tabsController.removeListener(_onTabsChanged);
    ShellTabRequest.instance.removeListener(_handleShellTabRequest);
    _defaultBrowserIntentChannel.setMethodCallHandler(null);
    _removeSnapshotOverlay();
    _morphController.dispose();
    _browserFadeController.dispose();
    _drawerController.dispose();
    drawer_menu.LooplyDrawerBridge.open = null;
    drawer_menu.LooplyDrawerBridge.close = null;
    super.dispose();
  }

  // Quando o app vai para segundo plano, pausado ou é encerrado, marca o
  // instante — é o que decide, no próximo arranque, se ainda estamos
  // dentro da janela de 1h para restaurar o browser.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Quando Histórico, Downloads ou outra página está por cima,
      // não substitui a atividade dessa rota pela tela que ficou atrás.
      final shellRoute = ModalRoute.of(context);
      if (shellRoute == null || shellRoute.isCurrent) {
        _persistCurrentActivity();
      }
      unawaited(SessionStore.instance.markBackgrounded());
      unawaited(tabsController.flushPersistence());
      unawaited(activityController.flushPersistence());
      unawaited(AdBlockStats.instance.flushPersistence());
      unawaited(BrowseItCloudSync.syncAppBackup().catchError((_) {}));
    } else if (state == AppLifecycleState.resumed) {
      unawaited(BrowseItCloudSync.syncAppBackup().catchError((_) {}));
    }
  }

  Future<void> _maybeRestoreSession() async {
    if (_restoreChecked || !mounted) return;
    _restoreChecked = true;

    // A escolha de arranque é a última atividade do utilizador, não o último
    // URL guardado. Assim, abrir o browser ontem não força o app a arrancar
    // sempre nesse site se a última utilização foi noutra área.
    final saved = await SessionStore.instance.getLastActivity();
    if (!mounted) return;

    if (saved == null) {
      setState(() {
        _selectedTab = 0;
        _activeBrowserTabId = null;
        _showingTabsGrid = false;
      });
      return;
    }

    final type = saved['type']?.toString() ?? 'shell';
    final returnTo = _activityMap(saved['returnTo']);

    if (type == 'drawer_page') {
      _restoreBaseActivity(returnTo);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pageKey = saved['page']?.toString() ?? '';
        unawaited(drawer_menu.restoreDrawerPageActivity(
          context,
          pageKey: pageKey,
          returnTo: returnTo,
        ));
      });
      return;
    }

    if (type == 'tabs_grid') {
      _restoreBaseActivity(returnTo);
      _preferredReturnTabId = _activeBrowserTabId;
      if (mounted) setState(() => _showingTabsGrid = true);
      return;
    }

    _restoreBaseActivity(saved);
  }

  Map<String, dynamic> _activityMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{'type': 'shell', 'screenIndex': 0};
  }

  void _restoreBaseActivity(Map<String, dynamic> activity) {
    final type = activity['type']?.toString() ?? 'shell';
    String? restoredBrowserId;
    var restoredScreen = 0;

    BrowserTab? restoreBrowserTab;
    if (type == 'browser') {
      final id = activity['tabId']?.toString();
      final tab = id == null ? null : tabsController.getTab(id);
      // As sessões privadas não são reabertas automaticamente.
      if (tab != null && !tab.isIncognito && tab.kind != TabKind.appScreen) {
        restoreBrowserTab = tab;
        restoredBrowserId = tab.id;
      }
    } else if (type == 'shell') {
      final rawIndex = activity['screenIndex'];
      if (rawIndex is num) restoredScreen = rawIndex.toInt();
    }

    if (mounted) {
      setState(() {
        _selectedTab = restoredScreen.clamp(0, _screenKeys.length - 1).toInt();
        _activeBrowserTabId = restoredBrowserId;
        _showingTabsGrid = false;
      });
      if (restoreBrowserTab != null) {
        _ensureBrowserTabMounted(restoreBrowserTab);
        tabsController.activate(restoreBrowserTab.id);
      }
    }
  }

  Map<String, dynamic> _currentBaseActivity() {
    final id = _activeBrowserTabId;
    final active = id == null ? null : tabsController.getTab(id);
    if (active != null && !active.isIncognito && active.kind != TabKind.appScreen) {
      return <String, dynamic>{'type': 'browser', 'tabId': active.id};
    }
    return <String, dynamic>{'type': 'shell', 'screenIndex': _selectedTab};
  }

  void _persistCurrentActivity() {
    final activity = _showingTabsGrid
        ? <String, dynamic>{
            'type': 'tabs_grid',
            'returnTo': _currentBaseActivity(),
          }
        : _currentBaseActivity();
    unawaited(SessionStore.instance.saveLastActivity(activity));
  }

  void _onTabsChanged() {
    if (!mounted) return;

    final tabs = tabsController.tabs;
    final liveBrowserIds = tabs
        .where((tab) => tab.kind != TabKind.appScreen)
        .map((tab) => tab.id)
        .toSet();
    final liveTabIds = tabs.map((tab) => tab.id).toSet();

    final activeId = _activeBrowserTabId;
    if (activeId != null && liveBrowserIds.contains(activeId)) {
      final active = tabsController.getTab(activeId);
      if (active != null && active.kind != TabKind.appScreen) {
        _ensureBrowserTabMounted(active);
      }
    }

    // Remove recursos de abas fechadas sem reconstruir a página inteira em
    // cada atualização de título/URL enviada pelo WebView.
    _browserViewportKeys.removeWhere((id, _) =>
        !liveBrowserIds.contains(id) || id != _activeBrowserTabId);
    _browserFirstLoads.removeWhere((id, _) =>
        !liveBrowserIds.contains(id) || id != _activeBrowserTabId);
    _browserPlatformReady.removeWhere((id, _) =>
        !liveBrowserIds.contains(id) || id != _activeBrowserTabId);
    _previewKeys.removeWhere((id, _) => !liveTabIds.contains(id));
    _cardKeys.removeWhere((id, _) => !liveTabIds.contains(id));
    _homePreviewKeys.removeWhere((id, _) => !liveTabIds.contains(id));

    var activeWasRemoved = false;
    if (_activeBrowserTabId != null &&
        !liveBrowserIds.contains(_activeBrowserTabId)) {
      _activeBrowserTabId = null;
      activeWasRemoved = true;
    }

    final nextCount = tabs.length;
    final countChanged = nextCount != _lastObservedTabCount;
    _lastObservedTabCount = nextCount;

    // Atualizações de navegação são refletidas localmente pela WebView e pela
    // grelha. O Shell só precisa de rebuild quando muda o número de abas ou
    // quando a aba que estava aberta é realmente removida.
    if (countChanged || activeWasRemoved) setState(() {});
  }

  void _ensureBrowserTabMounted(BrowserTab tab) {
    if (tab.kind == TabKind.appScreen) return;
    _browserViewportKeys.putIfAbsent(tab.id, GlobalKey.new);
    _browserFirstLoads.putIfAbsent(tab.id, Completer<void>.new);
    _browserPlatformReady.putIfAbsent(tab.id, Completer<void>.new);
    _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
    _cardKeys.putIfAbsent(tab.id, GlobalKey.new);
  }

  void _animateDrawerTo(double target, {double velocity = 0, double drawerWidth = 304}) {
    if (!mounted) return;
    final distance = (target - _drawerController.value).abs();
    if (distance <= .001) return;
    _drawerController.stop();
    final speed = velocity.abs();
    final milliseconds = speed > 80
        ? (distance * drawerWidth / speed * 1000).round().clamp(230, 430).toInt()
        : (distance * 455).round().clamp(260, 455).toInt();
    unawaited(_drawerController.animateTo(
      target,
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeInOutCubicEmphasized,
    ));
  }

  void _openShellDrawer() => _animateDrawerTo(1);

  void _closeShellDrawer() => _animateDrawerTo(0);

  void _onDrawerDragStart(DragStartDetails details) {
    _drawerController.stop();
  }

  void _onDrawerDragUpdate(DragUpdateDetails details, double drawerWidth) {
    if (drawerWidth <= 0) return;
    _drawerController.value =
        (_drawerController.value + details.delta.dx / drawerWidth)
            .clamp(0.0, 1.0)
            .toDouble();
  }

  void _onDrawerDragEnd(DragEndDetails details, double drawerWidth) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final progress = _drawerController.value;
    final target = velocity > 420
        ? 1.0
        : velocity < -420
            ? 0.0
            : progress >= .42
                ? 1.0
                : 0.0;
    _animateDrawerTo(target, velocity: velocity, drawerWidth: drawerWidth);
  }

  double _drawerWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(320.0, math.min(screenWidth * .82, screenWidth - 24)).toDouble();
  }

  void _activateBrowserTab(BrowserTab tab) {
    _ensureBrowserTabMounted(tab);
    // A abertura pela grelha usa o Container Transform existente. O percurso
    // normal Home -> Browser usa apenas fade, sem deslocar a WebView.
    _browserFadeController.stop();
    _browserFadeController.value = 1;
    setState(() {
      _activeBrowserTabId = tab.id;
      _showingTabsGrid = false;
    });
    tabsController.activate(tab.id);
    _persistCurrentActivity();
  }

  // Transição fade usada na navegação normal entre Home e Browser.
  // O Container Transform da grelha continua independente deste controlador.
  void _activateBrowserTabWithFade(BrowserTab tab) {
    _ensureBrowserTabMounted(tab);
    final browserAlreadyVisible =
        _activeBrowserTabId != null && !_showingTabsGrid;
    _browserFadeController.stop();
    _browserFadeController.value = browserAlreadyVisible ? 1 : 0;
    setState(() {
      _activeBrowserTabId = tab.id;
      _showingTabsGrid = false;
    });
    tabsController.activate(tab.id);
    _persistCurrentActivity();
    if (!browserAlreadyVisible) {
      unawaited(_playBrowserEntranceWhenReady(tab.id));
    }
  }

  Future<void> _playBrowserEntranceWhenReady(String tabId) async {
    final ready = _browserPlatformReady[tabId];
    if (ready != null && !ready.isCompleted) {
      try {
        await ready.future.timeout(const Duration(milliseconds: 650));
      } on TimeoutException {
        // Não bloqueia a navegação caso a plataforma demore a sinalizar.
      }
    }

    // Deixa o Android anexar a superfície nativa e o Flutter concluir um
    // frame antes de iniciar o fade, evitando um frame inicial em branco.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        _activeBrowserTabId != tabId ||
        _showingTabsGrid ||
        _browserFadeController.isAnimating) {
      return;
    }
    await _browserFadeController.forward();
  }

  Future<void> _navigateToShellScreen(int index) async {
    if (_activeBrowserTabId != null && !_showingTabsGrid) {
      _browserFadeController.stop();
      try {
        await _browserFadeController.reverse();
      } catch (_) {}
      if (!mounted) return;
    }
    setState(() {
      _activeBrowserTabId = null;
      _selectedTab = index.clamp(0, _screenKeys.length - 1).toInt();
    });
    _persistCurrentActivity();
  }

  void _handleShellTabRequest() {
    if (!mounted) return;
    final request = ShellTabRequest.instance;

    if (request.browserPreviewRequested) {
      final tabId = request.browserPreviewTabId;
      final screenshot = request.browserPreviewScreenshot;
      final sourceRect = request.browserPreviewSourceRect;
      request.clearBrowserPreviewRequest();
      if (tabId != null && screenshot != null) {
        unawaited(_openBrowserFromHomePreview(
          tabId: tabId,
          screenshot: screenshot,
          sourceRect: sourceRect,
        ));
      }
      return;
    }

    if (request.browserHomeRequested) {
      final tabId = request.browserHomeTabId;
      final screenshot = request.browserHomeScreenshot;
      final sourceRect = request.browserHomeSourceRect;
      request.clearBrowserHomeRequest();
      if (tabId != null) {
        unawaited(_closeBrowserToHomePreview(
          tabId: tabId,
          screenshot: screenshot,
          sourceRect: sourceRect,
        ));
      }
      return;
    }

    if (request.browserCloseRequested) {
      request.browserCloseRequested = false;
      final tabId = request.browserCloseTabId;
      final screenshot = request.browserCloseScreenshot;
      final sourceRect = request.browserCloseSourceRect;
      request.browserCloseTabId = null;
      request.browserCloseScreenshot = null;
      request.browserCloseSourceRect = null;
      if (tabId != null) {
        unawaited(_closeBrowserToTabsGrid(
          tabId: tabId,
          screenshot: screenshot,
          sourceRect: sourceRect,
        ));
      }
      return;
    }

    if (request.orbitBrowserRequested) {
      request.orbitBrowserRequested = false;
      final tab = tabsController.getOrbitBrowserTab() ??
          tabsController.upsertOrbitBrowserTab(null);
      _activateBrowserTabWithFade(tab);
      return;
    }

    final requestedBrowserId = request.browserTabRequested;
    request.browserTabRequested = null;
    if (requestedBrowserId != null) {
      final tab = tabsController.getTab(requestedBrowserId);
      if (tab != null) _activateBrowserTabWithFade(tab);
      return;
    }

    if (request.tabsRequested) {
      request.tabsRequested = false;
      request.requestedIndex = null;
      _preferredReturnTabId = _activeBrowserTabId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTabsGrid();
      });
      return;
    }

    final requested = request.requestedIndex;
    request.requestedIndex = null;
    if (requested == null) return;
    unawaited(_navigateToShellScreen(requested));
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

  Future<ImageProvider?> _prepareSnapshotImage(Uint8List bitmap) async {
    final provider = MemoryImage(bitmap);
    try {
      // Decodifica antes de inserir o overlay. Assim o primeiro frame da
      // animação já contém a imagem real e nunca um placeholder cinzento.
      await precacheImage(provider, context);
      return provider;
    } catch (_) {
      return null;
    }
  }

  void _insertSnapshotOverlay({
    required ImageProvider image,
    required Rect from,
    required bool opening,
  }) {
    _removeSnapshotOverlay();
    _morphController.stop();
    _morphController.value = 0;
    _morphImage = image;
    _morphFrom = from;
    _morphTo = from;
    _morphOpening = opening;

    // A mesma OverlayEntry permanece montada do primeiro ao último frame.
    // Não removemos uma imagem para inserir outra no início da animação —
    // essa troca de entries era a origem do frame vazio/flash.
    _morphEntry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _morphController,
            builder: (context, _) {
              final imageProvider = _morphImage;
              final from = _morphFrom;
              final to = _morphTo;
              if (imageProvider == null || from == null || to == null) {
                return const SizedBox.expand();
              }

              final t = Curves.easeInOutCubic.transform(_morphController.value);
              final rect = Rect.lerp(from, to, t) ?? to;
              final startRadius = _morphOpening
                  ? BorderRadius.zero
                  : BorderRadius.circular(18);
              final endRadius = _morphOpening
                  ? BorderRadius.circular(18)
                  : BorderRadius.zero;
              final radius = BorderRadius.lerp(startRadius, endRadius, t) ??
                  BorderRadius.zero;

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!_morphOpening)
                    Positioned.fill(
                      child: ColoredBox(color: pageBg(overlayContext)),
                    ),
                  Positioned.fromRect(
                    rect: rect,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Image(
                          image: imageProvider,
                          // Preserve the complete web viewport while the card
                          // morphs to its destination. Cover used to crop the
                          // captured page during the expansion and made it look
                          // artificially zoomed.
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
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
  }

  void _removeSnapshotOverlay() {
    _morphEntry?.remove();
    _morphEntry = null;
    _morphImage = null;
    _morphFrom = null;
    _morphTo = null;
  }

  Future<void> _animateSnapshot({
    required Rect to,
    bool keepOverlayAtEnd = false,
  }) async {
    if (!mounted || _morphEntry == null) return;
    _morphTo = to;
    _morphEntry!.markNeedsBuild();

    try {
      // A curva é aplicada apenas no builder. O driver fica linear para não
      // aplicar easeInOut duas vezes e alterar a velocidade a meio do morph.
      await _morphController.animateTo(
        1,
        duration: const Duration(milliseconds: 440),
        curve: Curves.linear,
      );
    } finally {
      if (!keepOverlayAtEnd) _removeSnapshotOverlay();
    }
  }

  void _beginTabsGridPositionWait() {
    _tabsGridPositionCompleter = Completer<void>();
  }

  void _completeTabsGridPositionReady() {
    final completer = _tabsGridPositionCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<void> _waitForTabsGridPositionReady() async {
    final completer = _tabsGridPositionCompleter;
    if (completer != null && !completer.isCompleted) {
      try {
        await completer.future.timeout(const Duration(milliseconds: 1600));
      } on TimeoutException {
        // A grelha permanece utilizável mesmo que um cartão não seja medido.
      }
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _openTabsGrid() async {
    if (_showingTabsGrid || _morphing) return;
    _morphing = true;
    final returnTo = _currentBaseActivity();
    _preferredReturnTabId = _activeBrowserTabId;
    unawaited(SessionStore.instance.saveLastActivity({
      'type': 'tabs_grid',
      'returnTo': returnTo,
    }));

    final sourceRect = _rectInOverlay(_repaintKey);
    final bitmap = await captureWidgetSnapshot(_repaintKey, pixelRatio: 1.1);
    if (!mounted) {
      _morphing = false;
      return;
    }

    if (bitmap == null || sourceRect == null) {
      final appTab = tabsController.upsertAppScreenTab(
        _screenKeys[_selectedTab],
        _screenLabels[_selectedTab],
        _screenIcons[_selectedTab],
        bitmap,
      );
      _previewKeys.putIfAbsent(appTab.id, GlobalKey.new);
      _cardKeys.putIfAbsent(appTab.id, GlobalKey.new);
      _preferredReturnTabId = appTab.id;
      _beginTabsGridPositionWait();
      setState(() {
        _showingTabsGrid = true;
        _morphing = false;
      });
      return;
    }

    final imageProvider = await _prepareSnapshotImage(bitmap);
    if (!mounted) {
      _morphing = false;
      return;
    }

    _lastScreenSnapshot = bitmap;
    final appTab = tabsController.upsertAppScreenTab(
      _screenKeys[_selectedTab],
      _screenLabels[_selectedTab],
      _screenIcons[_selectedTab],
      bitmap,
    );
    _previewKeys.putIfAbsent(appTab.id, GlobalKey.new);
    _cardKeys.putIfAbsent(appTab.id, GlobalKey.new);
    _preferredReturnTabId = appTab.id;

    if (imageProvider == null) {
      _beginTabsGridPositionWait();
      setState(() {
        _showingTabsGrid = true;
        _morphing = false;
      });
      return;
    }

    // Primeiro cobrimos o ecrã atual com a captura já descodificada.
    // Só depois montamos a grelha por baixo dela.
    _insertSnapshotOverlay(
      image: imageProvider,
      from: sourceRect,
      opening: true,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _removeSnapshotOverlay();
      return;
    }

    _beginTabsGridPositionWait();
    setState(() => _showingTabsGrid = true);
    await _waitForTabsGridPositionReady();
    if (!mounted) {
      _removeSnapshotOverlay();
      return;
    }

    final target = _rectInOverlay(_previewKeys[appTab.id]!) ??
        _rectInOverlay(_cardKeys[appTab.id]!) ??
        sourceRect;
    await _animateSnapshot(to: target);
    if (mounted) setState(() => _morphing = false);
  }

  // Todas as páginas Orbit usam o mesmo percurso de ida para a grelha.
  // A captura cobre a viewport antes de a WebView ativa ser desmontada;
  // na grelha ficam apenas as miniaturas persistidas de cada separador.
  Future<void> _closeBrowserToTabsGrid({
    required String tabId,
    required Uint8List? screenshot,
    required Rect? sourceRect,
  }) async {
    if (_showingTabsGrid || _morphing) return;
    _morphing = true;

    final browserTab = tabsController.getTab(tabId);
    if (browserTab == null) {
      _morphing = false;
      return;
    }

    _ensureBrowserTabMounted(browserTab);
    _preferredReturnTabId = browserTab.id;
    if (!browserTab.isIncognito) {
      unawaited(SessionStore.instance.saveLastActivity({
        'type': 'tabs_grid',
        'returnTo': <String, dynamic>{'type': 'browser', 'tabId': browserTab.id},
      }));
    }
    final bitmap = screenshot ?? browserTab.thumbnail;
    final imageProvider = bitmap == null
        ? null
        : await _prepareSnapshotImage(bitmap);

    if (!mounted) {
      _morphing = false;
      return;
    }

    if (imageProvider != null && sourceRect != null) {
      _insertSnapshotOverlay(
        image: imageProvider,
        from: sourceRect,
        opening: true,
      );
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) {
      _removeSnapshotOverlay();
      _morphing = false;
      return;
    }

    // A grelha passa a apresentar as miniaturas locais. A WebView ativa sai
    // da árvore enquanto nenhum separador está em utilização direta.
    _beginTabsGridPositionWait();
    setState(() => _showingTabsGrid = true);
    await _waitForTabsGridPositionReady();

    if (!mounted) {
      _removeSnapshotOverlay();
      _morphing = false;
      return;
    }

    if (imageProvider != null && sourceRect != null) {
      final preview = _previewKeys[browserTab.id];
      final card = _cardKeys[browserTab.id];
      final destination = (preview == null ? null : _rectInOverlay(preview)) ??
          (card == null ? null : _rectInOverlay(card));
      if (destination != null) {
        await _animateSnapshot(to: destination);
      } else {
        _removeSnapshotOverlay();
      }
    } else {
      _removeSnapshotOverlay();
    }

    if (mounted) setState(() => _morphing = false);
  }

  Future<void> _closeTabsGrid({BrowserTab? openTab}) async {
    if (_morphing || !_showingTabsGrid) return;
    _morphing = true;

    final preferredReturnTab = tabsController.getTab(_preferredReturnTabId ?? '');
    final targetTab = openTab ??
        preferredReturnTab ??
        tabsController.getAppScreen(_screenKeys[_selectedTab]);
    _preferredReturnTabId = null;

    final sourceKey = targetTab == null
        ? null
        : (_previewKeys[targetTab.id] ?? _cardKeys[targetTab.id]);
    final sourceRect = sourceKey == null ? null : _rectInOverlay(sourceKey);

    Uint8List? bitmap = targetTab?.thumbnail;
    if (bitmap == null && targetTab?.kind == TabKind.appScreen) {
      bitmap = _lastScreenSnapshot;
    }
    if (bitmap == null && sourceKey != null) {
      bitmap = await captureWidgetSnapshot(sourceKey, pixelRatio: 1.1);
    }
    if (!mounted) {
      _morphing = false;
      return;
    }

    final imageProvider = bitmap == null ? null : await _prepareSnapshotImage(bitmap);
    if (!mounted) {
      _morphing = false;
      return;
    }

    if (targetTab != null && targetTab.kind != TabKind.appScreen) {
      _ensureBrowserTabMounted(targetTab);
      // Ao regressar da grelha, o movimento é feito pelo Container Transform.
      // O fade de navegação normal deve começar já na posição final.
      _browserFadeController.stop();
      _browserFadeController.value = 1;
      // A abertura já está a ser executada pelo Container Transform. Não
      // impedir que a Activity Kotlin acrescente uma segunda transição.
      _skipNextNativeEnterAnimation = true;
      setState(() {
        _activeBrowserTabId = targetTab.id;
        _showingTabsGrid = false;
      });
      tabsController.activate(targetTab.id);
      if (!targetTab.isIncognito) {
        unawaited(SessionStore.instance.saveLastActivity({
          'type': 'browser',
          'tabId': targetTab.id,
        }));
      } else {
        unawaited(SessionStore.instance.saveLastActivity({
          'type': 'shell',
          'screenIndex': _selectedTab,
        }));
      }

      // A captura é colocada por cima da grelha antes de montar a WebView.
      // Assim não há um frame intermédio em que a WebView recém-ativada apareça
      // sem a imagem do cartão, mantendo exatamente o Container Transform.
      if (imageProvider != null && sourceRect != null) {
        _insertSnapshotOverlay(
          image: imageProvider,
          from: sourceRect,
          opening: false,
        );
      }

      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        _removeSnapshotOverlay();
        _morphing = false;
        return;
      }

      if (imageProvider != null && sourceRect != null) {
        final viewportKey = _browserViewportKeys[targetTab.id];
        final destination = viewportKey == null
            ? null
            : _rectInOverlay(viewportKey);
        if (destination != null) {
          final firstLoad = _browserFirstLoads[targetTab.id];
          final needsInitialCover = targetTab.thumbnail == null &&
              firstLoad != null &&
              !firstLoad.isCompleted;
          await _animateSnapshot(
            to: destination,
            keepOverlayAtEnd: needsInitialCover,
          );
          if (needsInitialCover) {
            try {
              await firstLoad.future.timeout(const Duration(seconds: 5));
            } on TimeoutException {
              // A captura continua por um limite curto; a navegação não fica
              // bloqueada indefinidamente quando o site não responde.
            }
            _removeSnapshotOverlay();
          }
        } else {
          _removeSnapshotOverlay();
        }
      } else {
        _removeSnapshotOverlay();
      }

      if (mounted) {
        setState(() => _morphing = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) setState(() => _skipNextNativeEnterAnimation = false);
      }
      return;
    }

    if (targetTab != null && targetTab.kind == TabKind.appScreen) {
      var index = _screenKeys.indexOf(targetTab.url);
      // Compatibilidade com separadores de ecrã 'Jogos' e 'Descobrir' gravados
      // por versões anteriores: encaminha-os para o Início, já que nenhum dos
      // dois continua exposto na navegação principal.
      if (index < 0 &&
          (targetTab.url == 'games_screen' || targetTab.url == 'discover_screen')) {
        index = 0;
      }
      if (index >= 0) _selectedTab = index;
    }
    unawaited(SessionStore.instance.saveLastActivity({
      'type': 'shell',
      'screenIndex': _selectedTab,
    }));

    if (imageProvider != null && sourceRect != null) {
      _insertSnapshotOverlay(
        image: imageProvider,
        from: sourceRect,
        opening: false,
      );
      await WidgetsBinding.instance.endOfFrame;
    }

    setState(() {
      _activeBrowserTabId = null;
      _showingTabsGrid = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    if (imageProvider != null && sourceRect != null && mounted) {
      final destination = _rectInOverlay(_repaintKey);
      if (destination != null) {
        await _animateSnapshot(to: destination);
      } else {
        _removeSnapshotOverlay();
      }
    } else {
      _removeSnapshotOverlay();
    }

    if (mounted) setState(() => _morphing = false);
  }


  Future<void> _closeBrowserToHomePreview({
    required String tabId,
    required Uint8List? screenshot,
    required Rect? sourceRect,
  }) async {
    if (!mounted || _morphing || _showingTabsGrid) return;
    _morphing = true;

    final tab = tabsController.getTab(tabId);
    if (tab != null) tabsController.activate(tab.id);

    final imageProvider = screenshot == null
        ? null
        : await _prepareSnapshotImage(screenshot);
    if (!mounted) {
      _morphing = false;
      return;
    }

    // The browser tab has already received its new thumbnail from
    // OrbitBrowserScreen. Reveal Home underneath the same snapshot, then morph
    // into that exact recent-tab card rather than merely fading to Home.
    _browserFadeController.stop();
    _browserFadeController.value = 1;
    setState(() {
      _activeBrowserTabId = null;
      _showingTabsGrid = false;
      _selectedTab = 0;
    });
    _persistCurrentActivity();

    if (imageProvider != null && sourceRect != null) {
      _insertSnapshotOverlay(
        image: imageProvider,
        from: sourceRect,
        opening: false,
      );
    }

    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _removeSnapshotOverlay();
      _morphing = false;
      return;
    }

    if (imageProvider != null && sourceRect != null) {
      final destination = _homePreviewKeys[tabId] == null
          ? null
          : _rectInOverlay(_homePreviewKeys[tabId]!);
      if (destination != null && destination.width > 0 && destination.height > 0) {
        await _animateSnapshot(to: destination);
      } else {
        _removeSnapshotOverlay();
      }
    } else {
      _removeSnapshotOverlay();
    }

    if (mounted) setState(() => _morphing = false);
  }

  Future<void> _openBrowserFromHomePreview({
    required String tabId,
    required Uint8List screenshot,
    required Rect? sourceRect,
  }) async {
    if (!mounted || _morphing || _showingTabsGrid) return;
    final tab = tabsController.getTab(tabId);
    if (tab == null || tab.kind == TabKind.appScreen) return;

    _morphing = true;
    _skipNextNativeEnterAnimation = true;
    _ensureBrowserTabMounted(tab);
    _browserFadeController.stop();
    _browserFadeController.value = 1;
    tabsController.activate(tab.id);
    unawaited(SessionStore.instance.saveLastActivity({
      'type': 'browser',
      'tabId': tab.id,
    }));

    final provider = sourceRect == null
        ? null
        : await _prepareSnapshotImage(screenshot);
    if (!mounted) {
      _morphing = false;
      _skipNextNativeEnterAnimation = false;
      return;
    }

    setState(() {
      _activeBrowserTabId = tab.id;
      _showingTabsGrid = false;
    });

    if (provider != null && sourceRect != null) {
      _insertSnapshotOverlay(
        image: provider,
        from: sourceRect,
        opening: false,
      );
    }

    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _removeSnapshotOverlay();
      _morphing = false;
      _skipNextNativeEnterAnimation = false;
      return;
    }

    if (provider != null && sourceRect != null) {
      final viewport = _browserViewportKeys[tab.id];
      final destination = viewport == null ? null : _rectInOverlay(viewport);
      if (destination != null) {
        await _animateSnapshot(to: destination);
      } else {
        _removeSnapshotOverlay();
      }
    } else {
      _removeSnapshotOverlay();
    }

    if (!mounted) return;
    setState(() => _morphing = false);
    // O browser só é ativado depois de a captura terminar a expansão. O extra
    // skipNativeEnterAnimation elimina a segunda transição da Activity Android.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _skipNextNativeEnterAnimation = false);
  }

  void _returnHomeFromTabs() {
    final homeTab = tabsController.upsertAppScreenTab(
      _screenKeys.first,
      _screenLabels.first,
      _screenIcons.first,
      null,
    );
    unawaited(_closeTabsGrid(openTab: homeTab));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final browserTabs = tabsController.tabs
        .where((tab) => tab.kind != TabKind.appScreen)
        .toList(growable: false);
    final activeBrowserIndex = browserTabs.indexWhere(
      (tab) => tab.id == _activeBrowserTabId,
    );
    final BrowserTab? activeBrowserTab = activeBrowserIndex < 0
        ? null
        : browserTabs[activeBrowserIndex];
    if (activeBrowserTab != null && !_showingTabsGrid) {
      _ensureBrowserTabMounted(activeBrowserTab);
    }

    // A shell principal e os separadores do Orbit são duas camadas reais.
    // Isto permite que o browser suba por cima da página anterior enquanto
    // a página de trás é empurrada ligeiramente para baixo, sem substituir
    // nem reconstruir a WebView persistente. O Container Transform da grelha
    // continua independente e inalterado.
    final shellPages = <Widget>[
      HomeScreen(
        onOpenDrawer: _openShellDrawer,
        recentTabPreviewKeys: _homePreviewKeys,
        onOpenTabs: () => unawaited(_openTabsGrid()),
      ),
    ];
    final Widget? activeBrowserPage = activeBrowserTab == null || _showingTabsGrid
        ? null
        : Theme(
            data: activeBrowserTab.isIncognito
                ? buildLooplyTheme(Brightness.dark)
                : Theme.of(context),
            child: OrbitBrowserScreen(
              key: ValueKey<String>('orbit-${activeBrowserTab.id}'),
              tabId: activeBrowserTab.id,
              initialUrl: activeBrowserTab.url,
              isActive: !_morphing,
              skipNativeEnterAnimation: _skipNextNativeEnterAnimation,
              viewportKey: _browserViewportKeys[activeBrowserTab.id]!,
              firstLoadCompleter: _browserFirstLoads[activeBrowserTab.id]!,
              browserReadyCompleter: _browserPlatformReady[activeBrowserTab.id]!,
              isIncognito: activeBrowserTab.isIncognito,
            ),
          );

    final shellPage = AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light, systemNavigationBarDividerColor: bg, systemNavigationBarContrastEnforced: false)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark, systemNavigationBarDividerColor: bg, systemNavigationBarContrastEnforced: false),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        extendBody: false,
        body: SafeArea(
          top: false,
          bottom: true,
          child: Stack(
          children: [
            Positioned.fill(
              child: Offstage(
                offstage: _showingTabsGrid,
                child: IgnorePointer(
                  ignoring: _activeBrowserTabId != null,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox.expand(
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: IndexedStack(
                          index: _selectedTab,
                          children: shellPages,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Só a WebView da aba ativa existe na árvore. Ao abrir a grelha,
            // ela é desmontada e a próxima só é criada quando for selecionada.
            Positioned.fill(
              child: Offstage(
                offstage: _activeBrowserTabId == null || _showingTabsGrid,
                child: FadeTransition(
                  opacity: _browserFadeOpacity,
                  child: RepaintBoundary(
                    key: activeBrowserTab == null
                        ? null
                        : _browserViewportKeys[activeBrowserTab.id],
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: SizedBox.expand(
                        child: activeBrowserPage ?? const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showingTabsGrid)
              Positioned.fill(
                child: PopScope<void>(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (!didPop) _closeTabsGrid();
                  },
                  child: TabsGridScreen(
                    previewKeys: _previewKeys,
                    cardKeys: _cardKeys,
                    initialIncognitoMode: tabsController
                        .getTab(_preferredReturnTabId ?? _activeBrowserTabId ?? '')
                        ?.isIncognito ?? false,
                    initialActiveTabId: _preferredReturnTabId ?? _activeBrowserTabId,
                    onInitialPositionReady: _completeTabsGridPositionReady,
                    onSelectTab: (tab) => _closeTabsGrid(openTab: tab),
                    onClose: () => _closeTabsGrid(),
                    onHome: _returnHomeFromTabs,
                    onNewTab: () {
                      final tab = tabsController.createBrowserTab('https://www.google.com');
                      _ensureBrowserTabMounted(tab);
                      _closeTabsGrid(openTab: tab);
                    },
                    onNewIncognitoTab: () {
                      final tab = tabsController.createBrowserTab(
                        'https://www.google.com',
                        isIncognito: true,
                      );
                      _ensureBrowserTabMounted(tab);
                      _closeTabsGrid(openTab: tab);
                    },
                    onCloseAllTabs: (incognitoOnly) {
                      final idsToClose = tabsController.tabs
                          .where((tab) => tab.isIncognito == incognitoOnly)
                          .map((tab) => tab.id)
                          .toList(growable: false);
                      final activeWasClosed = _activeBrowserTabId != null &&
                          idsToClose.contains(_activeBrowserTabId);
                      _preferredReturnTabId = null;
                      tabsController.closeTabs(idsToClose);
                      if (activeWasClosed) {
                        setState(() => _activeBrowserTabId = null);
                      }
                      unawaited(SessionStore.instance.saveLastActivity({
                        'type': 'tabs_grid',
                        'returnTo': <String, dynamic>{
                          'type': 'shell',
                          'screenIndex': _selectedTab,
                        },
                      }));
                    },
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );

    final drawerWidth = _drawerWidth(context);
    final drawerGestureEnabled = _selectedTab == 0 &&
        _activeBrowserTabId == null && !_showingTabsGrid;
    final drawerPanel = drawer_menu.LooplyDrawer(
      width: drawerWidth,
      onClose: _closeShellDrawer,
    );
    return AnimatedBuilder(
      animation: _drawerController,
      child: shellPage,
      builder: (context, child) {
        final progress = _drawerController.value.clamp(0.0, 1.0).toDouble();
        final isDrawerOpen = progress > .001;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: drawerWidth,
              child: drawerPanel,
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: drawerGestureEnabled ? _onDrawerDragStart : null,
                onHorizontalDragUpdate: drawerGestureEnabled
                    ? (details) => _onDrawerDragUpdate(details, drawerWidth)
                    : null,
                onHorizontalDragEnd: drawerGestureEnabled ? (details) => _onDrawerDragEnd(details, drawerWidth) : null,
                child: Transform.translate(
                  offset: Offset(drawerWidth * progress, 0),
                  child: child!,
                ),
              ),
            ),
            if (isDrawerOpen)
              Positioned(
                left: drawerWidth * progress,
                top: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeShellDrawer,
                  onHorizontalDragStart: _onDrawerDragStart,
                  onHorizontalDragUpdate: (details) =>
                      _onDrawerDragUpdate(details, drawerWidth),
                  onHorizontalDragEnd: (details) => _onDrawerDragEnd(details, drawerWidth),
                  child: ColoredBox(
                    color: Colors.black.withOpacity(.07 * progress),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
