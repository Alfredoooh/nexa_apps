import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'models.dart';
import 'auth_service.dart';
import 'browser_library.dart';
import 'screens/activity_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'screens/orbit_browser_screen.dart';
import 'widgets/drawer_menu.dart';
import 'session_store.dart';
import 'shell/shell_tab_request.dart';
import 'shell/tabs_grid_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Restaurar preferências e dados locais antes de construir a primeira tela:
  // evita mostrar temporariamente o tema padrão ou uma grelha sem separadores.
  await themeController.restore();
  await tabsController.restore();
  await activityController.restore();
  await searchHistoryController.restore();
  await authController.restore();
  await customSitesController.restore();
  await activeSearchEngine.restore();
  await restoreRuntimeSettings();
  await AdBlockStats.instance.restore();
  await browserFaviconCache.restore();
  await bookmarksController.restore();
  await downloadsController.restore();

  runApp(const LooplyApp());
}


class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => ValueListenableBuilder<bool>(
        valueListenable: themeController.pureDark,
        builder: (context, pureBlack, __) => MaterialApp(
          title: 'Looply',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          themeAnimationDuration: Duration.zero,
          theme: buildLooplyTheme(Brightness.light),
          darkTheme: buildLooplyTheme(Brightness.dark, pureBlack: pureBlack),
          home: const LooplyShell(),
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
  String? _activeBrowserTabId;
  final Map<String, GlobalKey> _browserViewportKeys = {};
  final Map<String, Completer<void>> _browserFirstLoads = {};
  // Sinaliza quando a plataforma nativa da WebView já foi criada. A entrada
  // do browser só começa depois deste ponto, evitando animar enquanto o
  // Android ainda está a anexar a PlatformView (causa comum de pequenos saltos).
  final Map<String, Completer<void>> _browserPlatformReady = {};
  final GlobalKey _repaintKey = GlobalKey();
  final Map<String, GlobalKey> _previewKeys = {};
  final Map<String, GlobalKey> _cardKeys = {};
  // As páginas principais são Início, Descobrir e Atividade.
  final List<String> _screenKeys = const ['home_screen', 'discover_screen', 'activity_screen'];
  final List<String> _screenLabels = const ['Início', 'Descobrir', 'Atividade'];
  final List<IconData> _screenIcons = const [Symbols.home_rounded, Symbols.explore_rounded, Symbols.history_rounded];
  late final AnimationController _morphController;
  late final AnimationController _browserSlideController;
  late final AnimationController _drawerController;
  late final Animation<Offset> _browserSlidePosition;
  OverlayEntry? _morphEntry;
  ImageProvider? _morphImage;
  Rect? _morphFrom;
  Rect? _morphTo;
  bool _morphOpening = true;
  Uint8List? _lastScreenSnapshot;
  String? _preferredReturnTabId;
  bool _restoreChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabsController.addListener(_onTabsChanged);
    ShellTabRequest.instance.addListener(_handleShellTabRequest);
    _morphController = AnimationController(vsync: this, duration: const Duration(milliseconds: 430));
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 460),
    );
    LooplyDrawerBridge.open = _openShellDrawer;
    LooplyDrawerBridge.close = _closeShellDrawer;
    _browserSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 390),
    )..value = 1;
    _browserSlidePosition = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _browserSlideController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRestoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabsController.removeListener(_onTabsChanged);
    ShellTabRequest.instance.removeListener(_handleShellTabRequest);
    _removeSnapshotOverlay();
    _morphController.dispose();
    _browserSlideController.dispose();
    _drawerController.dispose();
    LooplyDrawerBridge.open = null;
    LooplyDrawerBridge.close = null;
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
        unawaited(restoreDrawerPageActivity(
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

    final liveBrowserIds = tabsController.tabs
        .where((tab) => tab.kind != TabKind.appScreen)
        .map((tab) => tab.id)
        .toSet();

    if (_activeBrowserTabId != null) {
      final active = tabsController.getTab(_activeBrowserTabId!);
      if (active != null && active.kind != TabKind.appScreen) {
        _ensureBrowserTabMounted(active);
      }
    }

    // Mantém apenas os recursos de WebView da aba efetivamente ativa.
    // Miniaturas e chaves dos cartões continuam independentes para a grelha.
    _browserViewportKeys.removeWhere((id, _) =>
        !liveBrowserIds.contains(id) || id != _activeBrowserTabId);
    _browserFirstLoads.removeWhere((id, _) =>
        !liveBrowserIds.contains(id) || id != _activeBrowserTabId);
    _browserPlatformReady.removeWhere((id, _) =>
        !liveBrowserIds.contains(id) || id != _activeBrowserTabId);
    _previewKeys.removeWhere((id, _) => tabsController.getTab(id) == null);
    _cardKeys.removeWhere((id, _) => tabsController.getTab(id) == null);

    if (_activeBrowserTabId != null &&
        !liveBrowserIds.contains(_activeBrowserTabId)) {
      _activeBrowserTabId = null;
    }

    setState(() {});
  }

  void _ensureBrowserTabMounted(BrowserTab tab) {
    if (tab.kind == TabKind.appScreen) return;
    _browserViewportKeys.putIfAbsent(tab.id, GlobalKey.new);
    _browserFirstLoads.putIfAbsent(tab.id, Completer<void>.new);
    _browserPlatformReady.putIfAbsent(tab.id, Completer<void>.new);
    _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
    _cardKeys.putIfAbsent(tab.id, GlobalKey.new);
  }

  void _openShellDrawer() {
    if (!mounted || _drawerController.value >= 1) return;
    unawaited(_drawerController.animateTo(
      1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    ));
  }

  void _closeShellDrawer() {
    if (!mounted || _drawerController.value <= 0) return;
    unawaited(_drawerController.animateBack(
      0,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInCubic,
    ));
  }

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

  void _onDrawerDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity > 360) {
      _openShellDrawer();
    } else if (velocity < -360) {
      _closeShellDrawer();
    } else if (_drawerController.value >= .38) {
      _openShellDrawer();
    } else {
      _closeShellDrawer();
    }
  }

  double _drawerWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(320.0, math.min(screenWidth * .82, screenWidth - 24)).toDouble();
  }

  void _activateBrowserTab(BrowserTab tab) {
    _ensureBrowserTabMounted(tab);
    // A abertura pela grelha usa exclusivamente o Container Transform.
    // Repor a posição final do slide normal impede que a WebView fique
    // deslocada para fora do ecrã depois de uma navegação Home -> Browser.
    _browserSlideController.stop();
    _browserSlideController.value = 1;
    setState(() {
      _activeBrowserTabId = tab.id;
      _showingTabsGrid = false;
    });
    tabsController.activate(tab.id);
    _persistCurrentActivity();
  }

  // Transição vertical usada apenas na navegação normal entre Home e Browser.
  // O Container Transform dos separadores continua a usar o seu overlay/captura
  // original, sem passar por este controlador.
  void _activateBrowserTabWithSlide(BrowserTab tab) {
    _ensureBrowserTabMounted(tab);
    final browserAlreadyVisible =
        _activeBrowserTabId != null && !_showingTabsGrid;
    _browserSlideController.stop();
    _browserSlideController.value = browserAlreadyVisible ? 1 : 0;
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
    // frame antes de iniciar o movimento. A transição continua a ser um slide
    // real, sem fade ou screenshot e sem tocar no Container Transform.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        _activeBrowserTabId != tabId ||
        _showingTabsGrid ||
        _browserSlideController.isAnimating) {
      return;
    }
    await _browserSlideController.forward();
  }

  Future<void> _navigateToShellScreen(int index) async {
    if (_activeBrowserTabId != null && !_showingTabsGrid) {
      _browserSlideController.stop();
      try {
        await _browserSlideController.reverse();
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
      _activateBrowserTabWithSlide(tab);
      return;
    }

    final requestedBrowserId = request.browserTabRequested;
    request.browserTabRequested = null;
    if (requestedBrowserId != null) {
      final tab = tabsController.getTab(requestedBrowserId);
      if (tab != null) _activateBrowserTabWithSlide(tab);
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
                          fit: BoxFit.cover,
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
        duration: const Duration(milliseconds: 470),
        curve: Curves.linear,
      );
    } finally {
      if (!keepOverlayAtEnd) _removeSnapshotOverlay();
    }
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
    final bitmap = await captureWidgetSnapshot(_repaintKey, pixelRatio: 1.35);
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

    if (imageProvider == null) {
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

    setState(() => _showingTabsGrid = true);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
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
    setState(() => _showingTabsGrid = true);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

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
      bitmap = await captureWidgetSnapshot(sourceKey, pixelRatio: 1.3);
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
      // O slide de navegação normal deve começar já na posição final.
      _browserSlideController.stop();
      _browserSlideController.value = 1;
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

      if (mounted) setState(() => _morphing = false);
      return;
    }

    if (targetTab != null && targetTab.kind == TabKind.appScreen) {
      var index = _screenKeys.indexOf(targetTab.url);
      // Compatibilidade com separadores de ecrã 'Jogos' gravados por versões
      // anteriores: encaminha-os para Descobrir, sem voltar a expor Jogos na
      // navegação principal.
      if (index < 0 && targetTab.url == 'games_screen') index = 1;
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


  void _returnHomeFromTabs() {
    final homeTab = tabsController.getAppScreen(_screenKeys.first) ??
        tabsController.upsertAppScreenTab(
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
      HomeScreen(onOpenDrawer: _openShellDrawer),
      const DiscoverScreen(),
      const ActivityScreen(),
    ];
    final Widget? activeBrowserPage = activeBrowserTab == null || _showingTabsGrid
        ? null
        : OrbitBrowserScreen(
            key: ValueKey<String>('orbit-${activeBrowserTab.id}'),
            tabId: activeBrowserTab.id,
            initialUrl: activeBrowserTab.url,
            isActive: true,
            viewportKey: _browserViewportKeys[activeBrowserTab.id]!,
            firstLoadCompleter: _browserFirstLoads[activeBrowserTab.id]!,
            browserReadyCompleter: _browserPlatformReady[activeBrowserTab.id]!,
            isIncognito: activeBrowserTab.isIncognito,
          );

    final shellPage = AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        body: Stack(
          children: [
            // Página de trás: ao entrar no Orbit é empurrada para baixo e
            // ligeiramente reduzida. Ao fechar, regressa à posição original.
            // Este é o conteúdo vivo da tela anterior, não uma screenshot.
            Positioned.fill(
              child: Offstage(
                offstage: _showingTabsGrid,
                child: AnimatedBuilder(
                  animation: _browserSlideController,
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
                  builder: (context, child) {
                    // Usa exatamente o mesmo progresso curvo da página que
                    // sobe, para que a tela anterior seja empurrada ao mesmo
                    // ritmo e regresse sincronizada no fecho.
                    final progress = _activeBrowserTabId == null
                        ? 0.0
                        : (1 - _browserSlidePosition.value.dy).clamp(0.0, 1.0).toDouble();
                    return IgnorePointer(
                      ignoring: _activeBrowserTabId != null,
                      // Movimento simples por composição: evita recalcular
                      // clip arredondado e escala em todos os frames, mantendo
                      // a sensação de a tela anterior ser empurrada para baixo.
                      child: Transform.translate(
                        offset: Offset(0, 16 * progress),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Só a WebView da aba ativa existe na árvore. Ao abrir a grelha,
            // ela é desmontada e a próxima só é criada quando for selecionada.
            Positioned.fill(
              child: Offstage(
                offstage: _activeBrowserTabId == null || _showingTabsGrid,
                child: SlideTransition(
                  position: _browserSlidePosition,
                  child: RepaintBoundary(
                    child: SafeArea(
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
                    onCloseAllTabs: () {
                      _preferredReturnTabId = null;
                      tabsController.closeAllTabs();
                      setState(() {
                        _activeBrowserTabId = null;
                      });
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
        bottomNavigationBar: Offstage(
          offstage: _showingTabsGrid || _activeBrowserTabId != null,
          child: _LooplyBottomBar(
            selectedIndex: switch (_selectedTab) { 1 => 1, 2 => 3, _ => 0 },
            tabCount: tabsController.count,
            onSelect: (index) {
              if (index == 2) {
                _openTabsGrid();
              } else {
                final pageIndex = switch (index) { 0 => 0, 1 => 1, _ => 2 };
                unawaited(_navigateToShellScreen(pageIndex));
              }
            },
          ),
        ),
      ),
    );

    final drawerWidth = _drawerWidth(context);
    final drawerGestureEnabled = _selectedTab == 0 &&
        _activeBrowserTabId == null && !_showingTabsGrid;
    final drawerPanel = LooplyDrawer(
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
                onHorizontalDragEnd: drawerGestureEnabled ? _onDrawerDragEnd : null,
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
                  onHorizontalDragEnd: _onDrawerDragEnd,
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

class _TabsCountIcon extends StatelessWidget {
  const _TabsCountIcon({required this.count, required this.color});
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(.88), width: 1.6),
      borderRadius: BorderRadius.circular(6),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, height: 1),
        ),
      ),
    ),
  );
}

class _LooplyBottomBar extends StatelessWidget {
  const _LooplyBottomBar({
    required this.selectedIndex,
    required this.tabCount,
    required this.onSelect,
  });

  final int selectedIndex;
  final int tabCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final background = browserBottomBarColor(context);
    final foreground = mutedText(context);
    final selected = mainText(context);
    final indicator = Theme.of(context).brightness == Brightness.dark
        ? inputBarTone(context)
        : accentColor(context).withOpacity(.15);

    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        color: background,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / 4;
            final left = selectedIndex * slotWidth + 3;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  left: left,
                  top: 3,
                  width: slotWidth - 6,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: indicator,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _BottomBarItem(
                      icon: Symbols.home_rounded,
                      selectedIcon: Symbols.home_rounded,
                      tooltip: 'Início',
                      selected: selectedIndex == 0,
                      color: selectedIndex == 0 ? selected : foreground,
                      onTap: () => onSelect(0),
                    ),
                    _BottomBarItem(
                      icon: Symbols.explore_rounded,
                      selectedIcon: Symbols.explore_rounded,
                      tooltip: 'Descobrir',
                      selected: selectedIndex == 1,
                      color: selectedIndex == 1 ? selected : foreground,
                      onTap: () => onSelect(1),
                    ),
                    Expanded(
                      child: Center(
                        child: IconButton(
                          tooltip: 'Abas',
                          onPressed: () => onSelect(2),
                          icon: _TabsCountIcon(count: tabCount, color: foreground),
                        ),
                      ),
                    ),
                    _BottomBarItem(
                      icon: Symbols.history_rounded,
                      selectedIcon: Symbols.history_rounded,
                      tooltip: 'Atividade',
                      selected: selectedIndex == 3,
                      color: selectedIndex == 3 ? selected : foreground,
                      onTap: () => onSelect(3),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.tooltip,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Center(
          child: IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            icon: Icon(selected ? selectedIcon : icon, color: color, size: 24, fill: selected ? 1 : 0),
          ),
        ),
      );
}
