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
import 'screens/wikipedia_browser_screen.dart';
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
  bool _wikipediaTabsGridOnTop = false;
  bool _morphing = false;
  final GlobalKey _repaintKey = GlobalKey();
  final GlobalKey _browserViewportKey = GlobalKey();
  // Viewport da WikipediaBrowserScreen quando reaberta pela grelha — mesmo
  // papel do _browserViewportKey, mas para a rota de wikipedia, que usa um
  // Scaffold/WebView diferente do BrowserScreen normal.
  final GlobalKey _wikipediaViewportKey = GlobalKey();
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
  bool _morphCoverBackground = true;
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
    tabsController.activate(tab.id);
    Navigator.of(context).push(openBrowserRoute(tabId: tab.id, initialUrl: restored.url));
  }

  void _onTabsChanged() {
    if (mounted) setState(() {});
  }

  void _handleShellTabRequest() {
    if (!mounted) return;
    final request = ShellTabRequest.instance;

    // Pedido vindo da própria WikipediaBrowserScreen. O shell empilha a
    // grelha por cima da rota atual em vez de remover a Wikipédia; assim a
    // WebView continua viva e pode ser revelada novamente sem recarregar.
    if (request.wikipediaCloseRequested) {
      request.wikipediaCloseRequested = false;
      final screenshot = request.wikipediaCloseScreenshot;
      request.wikipediaCloseScreenshot = null;
      _closeWikipediaToTabsGrid(screenshot);
      return;
    }

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
    bool coverBackground = true,
  }) {
    _removeSnapshotOverlay();
    _morphController.stop();
    _morphController.value = 0;
    _morphImage = image;
    _morphFrom = from;
    _morphTo = from;
    _morphOpening = opening;
    _morphCoverBackground = coverBackground;

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
                  if (!_morphOpening && _morphCoverBackground)
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

  // Abre a grelha a partir da WikipediaBrowserScreen. A rota e a WebView
  // ficam montadas por baixo da grelha; o cartão usa a captura da página e
  // o retorno revela a mesma instância, sem reconstruir nem recarregar o browser.
  Future<void> _closeWikipediaToTabsGrid(Uint8List? screenshot) async {
    if (_showingTabsGrid || _wikipediaTabsGridOnTop || _morphing) return;
    _morphing = true;

    final wikipediaTab = tabsController.getWikipediaTab();
    if (wikipediaTab == null) {
      _morphing = false;
      return;
    }

    // A WikipediaBrowserScreen permanece montada por baixo da grelha. Isto
    // preserva a mesma WebView, o histórico interno, a posição de scroll e
    // qualquer atividade que a página esteja a executar.
    final sourceRect = _rectInOverlay(_wikipediaViewportKey);
    final bitmap = screenshot ?? wikipediaTab.thumbnail;
    if (bitmap != null) {
      tabsController.updateTab(
        wikipediaTab.id,
        title: wikipediaTab.title ?? 'Wikipédia',
        thumbnail: bitmap,
      );
    }

    _previewKeys.putIfAbsent(wikipediaTab.id, GlobalKey.new);
    _cardKeys.putIfAbsent(wikipediaTab.id, GlobalKey.new);

    final imageProvider = bitmap == null ? null : await _prepareSnapshotImage(bitmap);
    if (!mounted) {
      _morphing = false;
      return;
    }

    // Coloca a captura por cima da Wikipédia ANTES de empilhar a grelha.
    // Ao contrário do comportamento anterior, a rota da Wikipédia nunca é
    // removida; por isso voltar ao seu cartão revela a mesma instância.
    if (imageProvider != null && sourceRect != null) {
      _insertSnapshotOverlay(
        image: imageProvider,
        from: sourceRect,
        opening: true,
      );
    }

    _wikipediaTabsGridOnTop = true;
    Navigator.of(context).push<void>(_wikipediaTabsGridRoute());
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
      _removeSnapshotOverlay();
      return;
    }

    if (imageProvider != null && sourceRect != null) {
      final target = _rectInOverlay(_previewKeys[wikipediaTab.id]!) ??
          _rectInOverlay(_cardKeys[wikipediaTab.id]!) ??
          sourceRect;
      await _animateSnapshot(to: target);
    } else {
      _removeSnapshotOverlay();
    }

    if (mounted) setState(() => _morphing = false);
  }

  PageRoute<void> _wikipediaTabsGridRoute() {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (routeContext, animation, secondaryAnimation) => PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeWikipediaTabsGridRoute();
        },
        child: TabsGridScreen(
          previewKeys: _previewKeys,
          cardKeys: _cardKeys,
          onSelectTab: (tab) => _closeWikipediaTabsGridRoute(openTab: tab),
          onClose: () => _closeWikipediaTabsGridRoute(),
          onNewTab: () {
            final tab = tabsController.createBrowserTab('https://www.google.com');
            _previewKeys.putIfAbsent(tab.id, GlobalKey.new);
            _cardKeys.putIfAbsent(tab.id, GlobalKey.new);
            _closeWikipediaTabsGridRoute(openTab: tab);
          },
        ),
      ),
    );
  }

  Future<void> _closeWikipediaTabsGridRoute({BrowserTab? openTab}) async {
    if (!_wikipediaTabsGridOnTop || _morphing) return;
    _morphing = true;

    // Fechar a grelha (X/gesto voltar) significa regressar exatamente à
    // WikipediaBrowserScreen que já está viva por baixo desta rota.
    final targetTab = openTab ?? tabsController.getWikipediaTab();
    if (targetTab == null) {
      _wikipediaTabsGridOnTop = false;
      Navigator.of(context).pop();
      if (mounted) setState(() => _morphing = false);
      return;
    }

    final sourceKey = _previewKeys[targetTab.id] ?? _cardKeys[targetTab.id];
    final sourceRect = sourceKey == null ? null : _rectInOverlay(sourceKey);
    Uint8List? bitmap = targetTab.thumbnail;
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

    if (targetTab.kind == TabKind.wikipedia) {
      tabsController.activate(targetTab.id);
      if (imageProvider != null && sourceRect != null) {
        _insertSnapshotOverlay(
          image: imageProvider,
          from: sourceRect,
          opening: false,
          coverBackground: false,
        );
      }

      _wikipediaTabsGridOnTop = false;
      Navigator.of(context).pop();
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      if (imageProvider != null && sourceRect != null && mounted) {
        final destination = _rectInOverlay(_wikipediaViewportKey);
        if (destination != null) {
          await _animateSnapshot(to: destination);
        } else {
          _removeSnapshotOverlay();
        }
      } else {
        _removeSnapshotOverlay();
      }
      if (mounted) setState(() => _morphing = false);
      return;
    }

    if (targetTab.kind == TabKind.browser) {
      tabsController.activate(targetTab.id);
      final firstLoad = Completer<void>();
      if (imageProvider != null && sourceRect != null) {
        _insertSnapshotOverlay(
          image: imageProvider,
          from: sourceRect,
          opening: false,
        );
      }

      _wikipediaTabsGridOnTop = false;
      Navigator.of(context).pop();
      await WidgetsBinding.instance.endOfFrame;
      Navigator.of(context).push(
        _instantBrowserRoute(targetTab, firstLoadCompleter: firstLoad),
      );
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      if (imageProvider != null && sourceRect != null && mounted) {
        final destination = _rectInOverlay(_browserViewportKey);
        if (destination != null) {
          await _animateSnapshot(to: destination, keepOverlayAtEnd: true);
          try {
            await firstLoad.future.timeout(const Duration(seconds: 5));
          } on TimeoutException {
            // A navegação continua mesmo se o site demorar a responder.
          }
        }
      }
      _removeSnapshotOverlay();
      if (mounted) setState(() => _morphing = false);
      return;
    }

    // Para uma aba interna do Looply, fecha-se a grelha e a rota da
    // Wikipédia, revelando o ecrã interno selecionado no shell.
    final index = _screenKeys.indexOf(targetTab.url);
    if (imageProvider != null && sourceRect != null) {
      _insertSnapshotOverlay(
        image: imageProvider,
        from: sourceRect,
        opening: false,
      );
    }
    _wikipediaTabsGridOnTop = false;
    Navigator.of(context).pop();
    if (index >= 0 && mounted) setState(() => _selectedTab = index);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
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

    if (targetTab != null && targetTab.kind == TabKind.browser) {
      tabsController.activate(targetTab.id);
      final firstLoad = Completer<void>();

      // O push e a inserção do overlay acontecem no mesmo ciclo síncrono:
      // a captura fica no topo antes do primeiro frame da nova rota.
      setState(() => _showingTabsGrid = false);
      Navigator.of(context).push(
        _instantBrowserRoute(targetTab, firstLoadCompleter: firstLoad),
      );

      if (imageProvider != null && sourceRect != null) {
        _insertSnapshotOverlay(
          image: imageProvider,
          from: sourceRect,
          opening: false,
        );
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) {
          final destination = _rectInOverlay(_browserViewportKey);
          if (destination != null) {
            // A imagem termina no viewport e continua visível por cima da
            // WebView enquanto o primeiro documento termina de carregar.
            await _animateSnapshot(to: destination, keepOverlayAtEnd: true);
            try {
              await firstLoad.future.timeout(const Duration(seconds: 5));
            } on TimeoutException {
              // Não bloquear a navegação indefinidamente se o site demorar.
            }
          }
        }
      }

      _removeSnapshotOverlay();
      if (mounted) setState(() => _morphing = false);
      return;
    }

    // Aba da Wikipédia: mesmo tratamento do browser normal (overlay até o
    // conteúdo carregar), mas abrindo WikipediaBrowserScreen em vez de
    // BrowserScreen, e medindo o destino através de _wikipediaViewportKey.
    if (targetTab != null && targetTab.kind == TabKind.wikipedia) {
      tabsController.activate(targetTab.id);
      final firstLoad = Completer<void>();

      setState(() => _showingTabsGrid = false);
      Navigator.of(context).push(
        _instantWikipediaRoute(firstLoadCompleter: firstLoad),
      );

      if (imageProvider != null && sourceRect != null) {
        _insertSnapshotOverlay(
          image: imageProvider,
          from: sourceRect,
          opening: false,
        );
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) {
          final destination = _rectInOverlay(_wikipediaViewportKey);
          if (destination != null) {
            await _animateSnapshot(to: destination, keepOverlayAtEnd: true);
            try {
              await firstLoad.future.timeout(const Duration(seconds: 5));
            } on TimeoutException {
              // Não bloquear a navegação indefinidamente se o site demorar.
            }
          }
        }
      }

      _removeSnapshotOverlay();
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

    setState(() => _showingTabsGrid = false);
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

  PageRoute<void> _instantBrowserRoute(
    BrowserTab tab, {
    Completer<void>? firstLoadCompleter,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => BrowserScreen(
        tabId: tab.id,
        initialUrl: tab.url,
        viewportKey: _browserViewportKey,
        firstLoadCompleter: firstLoadCompleter,
      ),
    );
  }

  // Irmã de _instantBrowserRoute, para a aba especial da Wikipédia.
  // WikipediaBrowserScreen não recebe tabId/initialUrl — ela já sabe a
  // própria URL e gere a própria aba via tabsController.getWikipediaTab()/
  // upsertWikipediaTab() no initState.
  PageRoute<void> _instantWikipediaRoute({Completer<void>? firstLoadCompleter}) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => WikipediaBrowserScreen(
        viewportKey: _wikipediaViewportKey,
        firstLoadCompleter: firstLoadCompleter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = mainText(context);
    final pages = <Widget>[
      HomeScreen(wikipediaViewportKey: _wikipediaViewportKey),
      const GamesScreen(),
      const ActivityScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        body: Stack(
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