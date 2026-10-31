import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'models.dart';
import 'screens/activity_screen.dart';
import 'screens/games_screen.dart';
import 'screens/home_screen.dart';
import 'screens/orbit_browser_screen.dart';
import 'widgets/drawer_menu.dart';
import 'session_store.dart';
import 'shell/shell_tab_request.dart';
import 'shell/tabs_grid_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LooplyApp());
}

class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => MaterialApp(
        title: 'Looply',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        themeAnimationDuration: Duration.zero,
        theme: buildLooplyTheme(Brightness.light),
        darkTheme: buildLooplyTheme(Brightness.dark),
        home: const LooplyShell(),
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
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, GlobalKey> _previewKeys = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final List<String> _screenKeys = const ['home_screen', 'games_screen', 'activity_screen'];
  final List<String> _screenLabels = const ['Início', 'Jogos', 'Atividade'];
  final List<IconData> _screenIcons = const [Symbols.home_rounded, Symbols.sports_esports_rounded, Symbols.history_rounded];
  late final AnimationController _morphController;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRestoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabsController.removeListener(_onTabsChanged);
    ShellTabRequest.instance.removeListener(_handleShellTabRequest);
    _removeSnapshotOverlay();
    _morphController.dispose();
    super.dispose();
  }

  // Quando o app vai para segundo plano, pausado ou é encerrado, marca o
  // instante — é o que decide, no próximo arranque, se ainda estamos
  // dentro da janela de 1h para restaurar o browser.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(SessionStore.instance.markBackgrounded());
    }
  }

  Future<void> _maybeRestoreSession() async {
    if (_restoreChecked || !mounted) return;
    _restoreChecked = true;
    final restored = await SessionStore.instance.getRestorablePage();
    if (restored == null || !mounted) return;

    final tab = tabsController.createBrowserTab(restored.url);
    _ensureBrowserTabMounted(tab);
    tabsController.activate(tab.id);
    setState(() => _activeBrowserTabId = tab.id);
  }

  void _onTabsChanged() {
    if (!mounted) return;

    final liveBrowserIds = tabsController.tabs
        .where((tab) => tab.kind != TabKind.appScreen)
        .map((tab) => tab.id)
        .toSet();

    // Cada browser tab mantém o seu próprio OrbitBrowserScreen e a sua
    // própria InAppWebView na árvore do IndexedStack. Apenas a aba ativa é
    // pintada; as restantes ficam Offstage sem destruir o documento nativo.
    for (final tab in tabsController.tabs) {
      if (tab.kind != TabKind.appScreen) {
        _ensureBrowserTabMounted(tab);
      }
    }

    _browserViewportKeys.removeWhere((id, _) => !liveBrowserIds.contains(id));
    _browserFirstLoads.removeWhere((id, _) => !liveBrowserIds.contains(id));
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
    _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
    _cardKeys.putIfAbsent(tab.id, GlobalKey.new);
  }

  void _openShellDrawer() {
    _shellScaffoldKey.currentState?.openDrawer();
  }

  void _activateBrowserTab(BrowserTab tab) {
    _ensureBrowserTabMounted(tab);
    tabsController.activate(tab.id);
    setState(() {
      _activeBrowserTabId = tab.id;
      _showingTabsGrid = false;
    });
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
      _activateBrowserTab(tab);
      return;
    }

    final requestedBrowserId = request.browserTabRequested;
    request.browserTabRequested = null;
    if (requestedBrowserId != null) {
      final tab = tabsController.getTab(requestedBrowserId);
      if (tab != null) _activateBrowserTab(tab);
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
    setState(() {
      _activeBrowserTabId = null;
      _selectedTab = requested.clamp(0, 2).toInt();
    });
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
  // A WebView permanece montada no IndexedStack: apenas a camada visual é
  // coberta pela captura durante o Container Transform.
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

    // Não fazemos pop de rota nem recriamos o Orbit Browser. Todas as abas
    // ficam vivas, tal como a Wikipédia ficava na implementação aprovada.
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
      tabsController.activate(targetTab.id);

      // A captura é colocada por cima da grelha antes de trocar o IndexedStack.
      // Assim não há um frame intermédio em que a WebView recém-ativada apareça
      // sem a imagem do cartão, mantendo exatamente o Container Transform.
      if (imageProvider != null && sourceRect != null) {
        _insertSnapshotOverlay(
          image: imageProvider,
          from: sourceRect,
          opening: false,
        );
      }

      setState(() {
        _activeBrowserTabId = targetTab.id;
        _showingTabsGrid = false;
      });

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
      final index = _screenKeys.indexOf(targetTab.url);
      if (index >= 0) _selectedTab = index;
    }

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


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = mainText(context);
    final browserTabs = tabsController.tabs
        .where((tab) => tab.kind != TabKind.appScreen)
        .toList(growable: false);

    // Garante que todas as abas tenham chaves estáveis antes de construir o
    // IndexedStack. As páginas inativas continuam montadas, mas não recebem
    // pintura nem gestos; ao regressar, a mesma WebView volta a ficar visível.
    for (final tab in browserTabs) {
      _ensureBrowserTabMounted(tab);
    }

    final activeBrowserIndex = browserTabs.indexWhere(
      (tab) => tab.id == _activeBrowserTabId,
    );
    final stackIndex = activeBrowserIndex >= 0
        ? 3 + activeBrowserIndex
        : _selectedTab;

    final pages = <Widget>[
      HomeScreen(onOpenDrawer: _openShellDrawer),
      const GamesScreen(),
      const ActivityScreen(),
      for (final tab in browserTabs)
        OrbitBrowserScreen(
          key: ValueKey<String>('orbit-${tab.id}'),
          tabId: tab.id,
          initialUrl: tab.url,
          isActive: !_showingTabsGrid && tab.id == _activeBrowserTabId,
          viewportKey: _browserViewportKeys[tab.id]!,
          firstLoadCompleter: _browserFirstLoads[tab.id]!,
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
      child: Scaffold(
        key: _shellScaffoldKey,
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        drawer: const LooplyDrawer(),
        drawerEnableOpenDragGesture: true,
        drawerEdgeDragWidth: 28,
        body: Stack(
          children: [
            Positioned.fill(
              child: Offstage(
                offstage: _showingTabsGrid,
                child: SafeArea(
                  bottom: false,
                  child: SizedBox.expand(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: IndexedStack(
                        index: stackIndex,
                        children: pages,
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
                    onNewTab: () {
                      final tab = tabsController.createBrowserTab('https://www.google.com');
                      _ensureBrowserTabMounted(tab);
                      _closeTabsGrid(openTab: tab);
                    },
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Offstage(
          offstage: _showingTabsGrid || _activeBrowserTabId != null,
          child: NavigationBar(
            selectedIndex: _selectedTab < 2 ? _selectedTab : _selectedTab + 1,
            onDestinationSelected: (index) {
              if (index == 2) {
                _openTabsGrid();
                return;
              }
              setState(() {
                _activeBrowserTabId = null;
                _selectedTab = index < 2 ? index : index - 1;
              });
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