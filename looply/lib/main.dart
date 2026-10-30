import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'models.dart';
import 'screens/activity_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/games_screen.dart';
import 'screens/home_screen.dart';
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

class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});
  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _showingTabsGrid = false;
  bool _morphing = false;
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _rootKey = GlobalKey();
  final GlobalKey _browserViewportKey = GlobalKey();
  final Map<String, GlobalKey> _previewKeys = {};
  final Map<String, GlobalKey> _cardKeys = {};
  final List<String> _screenKeys = const ['home_screen', 'games_screen', 'activity_screen'];
  final List<String> _screenLabels = const ['Início', 'Jogos', 'Atividade'];
  final List<IconData> _screenIcons = const [Symbols.home_rounded, Symbols.sports_esports_rounded, Symbols.history_rounded];
  late final AnimationController _morphController;
  OverlayEntry? _morphEntry;
  Uint8List? _lastScreenSnapshot;
  Rect? _lastScreenRect;
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
    _morphEntry?.remove();
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
    tabsController.activate(tab.id);
    Navigator.of(context).push(
      openBrowserRoute(tabId: tab.id, initialUrl: restored.url),
    );
  }

  void _onTabsChanged() {
    if (mounted) setState(() {});
  }

  void _handleShellTabRequest() {
    if (!mounted) return;
    final request = ShellTabRequest.instance;
    if (request.tabsRequested) {
      request.tabsRequested = false;
      request.requestedIndex = null;
      _preferredReturnTabId = tabsController.activeTabId;
      Navigator.of(context).popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTabsGrid();
      });
      return;
    }
    final requested = request.requestedIndex;
    request.requestedIndex = null;
    if (requested == null) return;
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

  void _prepareSnapshotOverlay({required Uint8List bitmap, required Rect from, required bool opening}) {
    _morphEntry?.remove();
    _morphEntry = null;
    _morphController.stop();
    _morphController.value = 0;
    _morphEntry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Não pinta um fundo por cima da grelha: a captura deve
              // ampliar-se sobre o ecrã que já está visível.
              Positioned.fromRect(
                rect: from,
                child: ClipRRect(
                  borderRadius: opening ? BorderRadius.zero : BorderRadius.circular(18),
                  child: Image.memory(bitmap, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_morphEntry!);
  }

  // Curva suavizada (easeInOutCubic em vez de linear no driver da animação)
  // para que a transição de container-morph pareça mais fluida e menos
  // abrupta, tanto a abrir quanto a fechar.
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
                  // Mantém o ecrã de origem visível por trás da captura.
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
      await _morphController.animateTo(1, curve: Curves.easeInOutCubic);
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

    _prepareSnapshotOverlay(bitmap: bitmap, from: sourceRect, opening: true);
    setState(() {
      _showingTabsGrid = true;
      _morphing = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final target = _rectInOverlay(_previewKeys[appTab.id]!) ?? _rectInOverlay(_cardKeys[appTab.id]!) ?? sourceRect;
    await _animateSnapshot(bitmap: bitmap, from: sourceRect, to: target, opening: true);
  }

  Future<void> _closeTabsGrid({BrowserTab? openTab}) async {
    if (_morphing || !_showingTabsGrid) return;

    final preferredReturnTab = tabsController.getTab(_preferredReturnTabId ?? '');
    final targetTab = openTab ?? preferredReturnTab ?? tabsController.getAppScreen(_screenKeys[_selectedTab]);
    _preferredReturnTabId = null;
    final sourceKey = targetTab == null
        ? null
        : targetTab.kind == TabKind.browser
            ? (_previewKeys[targetTab.id] ?? _cardKeys[targetTab.id])
            : (_cardKeys[targetTab.id] ?? _previewKeys[targetTab.id]);
    final sourceRect = sourceKey == null ? null : _rectInOverlay(sourceKey);
    Uint8List? bitmap = targetTab?.thumbnail;
    if (bitmap == null && targetTab?.kind == TabKind.appScreen) bitmap = _lastScreenSnapshot;
    if (bitmap == null && sourceKey != null) {
      bitmap = await captureWidgetSnapshot(sourceKey, pixelRatio: 1.3);
    }
    if (!mounted) return;

    if (targetTab != null && targetTab.kind == TabKind.browser) {
      final revealWebView = ValueNotifier<bool>(false);
      tabsController.activate(targetTab.id);

      if (bitmap != null && sourceRect != null) {
        _prepareSnapshotOverlay(
          bitmap: bitmap,
          from: sourceRect,
          opening: false,
        );
      }

      // A rota fica transparente durante o morph. Assim, a grelha continua
      // visível por trás e não há troca prematura do fundo para a página.
      setState(() => _morphing = bitmap != null && sourceRect != null);
      final routeFuture = Navigator.of(context).push<void>(
        _instantBrowserRoute(targetTab, revealWebView: revealWebView),
      );

      await WidgetsBinding.instance.endOfFrame;
      final destination = _rectInOverlay(_browserViewportKey);
      if (bitmap != null && sourceRect != null && destination != null) {
        await _animateSnapshot(
          bitmap: bitmap,
          from: sourceRect,
          to: destination,
          opening: false,
        );
      } else if (mounted) {
        setState(() => _morphing = false);
      }

      if (!mounted) {
        revealWebView.dispose();
        return;
      }

      // A troca do fundo e a revelação do InAppWebView acontecem juntas,
      // somente depois de a captura terminar a expansão.
      setState(() => _showingTabsGrid = false);
      revealWebView.value = true;
      unawaited(routeFuture.then<void>((_) {
        revealWebView.dispose();
      }));
      return;
    }

    if (targetTab != null && targetTab.kind == TabKind.appScreen) {
      final index = _screenKeys.indexOf(targetTab.url);
      if (index >= 0) _selectedTab = index;
    }
    if (bitmap != null && sourceRect != null) {
      _prepareSnapshotOverlay(bitmap: bitmap, from: sourceRect, opening: false);
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

  PageRoute<void> _instantBrowserRoute(BrowserTab tab, {ValueNotifier<bool>? revealWebView}) {
    return PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => BrowserScreen(
        tabId: tab.id,
        initialUrl: tab.url,
        viewportKey: _browserViewportKey,
        revealWebView: revealWebView,
      ),
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
              PopScope<void>(
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
                    _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
                    _cardKeys.putIfAbsent(tab.id, GlobalKey.new);
                    _closeTabsGrid(openTab: tab);
                  },
                ),
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