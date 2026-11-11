import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models.dart';
import '../browser_security.dart';
import '../browser_library.dart';
import '../shell/shell_tab_request.dart';
import '../shell/browser_navigation.dart';
import '../shell/fade_page_route.dart';
import '../theme.dart';
import '../localization.dart';
import '../translate_service.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/looply_popup.dart';
import '../widgets/media_context_sheet.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../widgets/svg_icon.dart';

/// Adaptador mínimo sobre flutter_inappwebview. Todas as plataformas usam
/// o mesmo motor InAppWebView; não existe PlatformView/Kotlin WebView paralelo.
class _OrbitWebViewController {
  _OrbitWebViewController(this.plugin);

  final InAppWebViewController plugin;

  Future<bool> canGoBack() => plugin.canGoBack();
  Future<bool> canGoForward() => plugin.canGoForward();
  Future<String?> getUrl() async => (await plugin.getUrl())?.toString();
  Future<String?> getTitle() => plugin.getTitle();
  Future<Uint8List?> takeScreenshot() => plugin.takeScreenshot();
  Future<void> goBack() => plugin.goBack();
  Future<void> goForward() => plugin.goForward();
  Future<void> reload() => plugin.reload();
  Future<void> clearMatches() => plugin.clearMatches();
  Future<void> findAll(String query) => plugin.findAllAsync(find: query);
  Future<void> findNext(bool forward) => plugin.findNext(forward: forward);
  Future<void> evaluateJavascript(String source) async {
    await plugin.evaluateJavascript(source: source);
  }

  Future<dynamic> evaluateJavascriptRaw(String source) {
    return plugin.evaluateJavascript(source: source);
  }

  Future<String?> getPageToolbarColor() async {
    try {
      final result = await plugin.evaluateJavascript(source: r'''(() => {
        const meta = document.querySelector('meta[name="theme-color"]');
        if (meta && meta.content) return meta.content.trim();
        const body = document.body ? getComputedStyle(document.body).backgroundColor : '';
        const solid = value => value && value !== 'transparent' && !/^rgba\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*0(?:\.0+)?\s*\)$/i.test(value);
        if (solid(body)) return body;
        const root = getComputedStyle(document.documentElement).backgroundColor || '';
        if (solid(root)) return root;
        const top = document.elementFromPoint(Math.max(1, innerWidth / 2), Math.max(1, Math.min(48, innerHeight / 4)));
        if (top) { const topColor = getComputedStyle(top).backgroundColor; if (solid(topColor)) return topColor; }
        return ''; 
      })()''');
      if (result == null) return null;
      final value = result.toString().replaceAll('"', '').trim();
      return value.isEmpty || value == 'null' ? null : value;
    } catch (_) {
      return null;
    }
  }

  /// Lê o idioma declarado pela própria página (atributo lang do <html>).
  /// Usado para decidir se vale a pena oferecer tradução.
  Future<String?> getPageLanguage() async {
    try {
      final result = await plugin.evaluateJavascript(source: r'''(() => {
        const candidates = [
          document.documentElement?.getAttribute('lang'),
          document.querySelector('meta[http-equiv="content-language"]')?.content,
          document.querySelector('meta[name="language"]')?.content,
          document.querySelector('html')?.getAttribute('xml:lang'),
          document.querySelector('meta[property="og:locale"]')?.content
        ];
        const value = candidates.find(item => typeof item === 'string' && item.trim());
        return value ? value.trim().replace('_', '-').split('-')[0].toLowerCase() : '';
      })()''');
      if (result == null) return null;
      final value = result.toString().replaceAll('"', '').trim().toLowerCase();
      return value.isEmpty || value == 'null' ? null : value.split(RegExp(r'[-_]')).first;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSettings({
    required bool cacheEnabled,
    required bool adBlockEnabled,
    required bool forceDark,
    required bool followAppTheme,
    required bool appIsDark,
  }) async {
    await plugin.setSettings(
      settings: InAppWebViewSettings(
        cacheEnabled: cacheEnabled,
        cacheMode: cacheEnabled ? CacheMode.LOAD_DEFAULT : CacheMode.LOAD_NO_CACHE,
        contentBlockers: buildPlatformAdBlockers(enabled: adBlockEnabled),
        algorithmicDarkeningAllowed: forceDark || (followAppTheme && appIsDark),
      ),
    );
  }
}

/// Browser do Looply. A instância é criada apenas para o separador ativo;
/// os restantes guardam URL, estado e captura local sem WebViews em memória.
class OrbitBrowserScreen extends StatefulWidget {
  const OrbitBrowserScreen({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.isActive,
    required this.viewportKey,
    this.firstLoadCompleter,
    this.browserReadyCompleter,
    this.isIncognito = false,
  });

  final String tabId;
  final String initialUrl;
  final bool isActive;
  final GlobalKey viewportKey;
  final Completer<void>? firstLoadCompleter;
  final Completer<void>? browserReadyCompleter;
  final bool isIncognito;

  @override
  State<OrbitBrowserScreen> createState() => _OrbitBrowserScreenState();
}

class _OrbitBrowserScreenState extends State<OrbitBrowserScreen>
    with SingleTickerProviderStateMixin {
  _OrbitWebViewController? _controller;
  bool _isAiSearchPage = false;
  String? _aiPageHtml;
  Color? _siteToolbarColor;
  Uint8List? _currentFavicon;
  Brightness? _lastAppBrightness;
  PullToRefreshController? _pullToRefreshController;
  Timer? _progressHideTimer;
  Timer? _findDebounce;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  bool _isFindInPage = false;
  bool _isExpandingToSearch = false;

  // Evita re-perguntar tradução na mesma sessão de página se o utilizador
  // já respondeu (sim ou não) para a URL atual.
  String? _translationPromptedForUrl;
  bool _pageIsTranslated = false;

  bool _isLoading = true;
  bool _showProgress = true;
  double _progress = 0;
  late String _currentUrl;
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _desktopSiteRequested = false;
  double _pageZoomFactor = 1.0;
  bool _renderProcessCrashed = false;
  String? _loadError;
  Key _webViewKey = UniqueKey();
  bool _tabsRequestInProgress = false;
  bool _firstLoadSignaled = false;

  // ---------------------------------------------------------------------
  // Esconder/mostrar a toolbar ao deslizar: 1 = totalmente visível,
  // 0 = totalmente escondida. É controlado DIRETAMENTE pelo delta do
  // gesto de scroll (sem animação temporizada) para a toolbar seguir o
  // dedo 1:1, exatamente como Chrome/Firefox/Safari fazem. A altura real
  // que ela ocupa no layout (Column) é ligada a este mesmo valor, por
  // isso quando ela encolhe o espaço dela desaparece de verdade e o
  // WebView por baixo cresce para preencher — nada fica escondido atrás
  // da appbar, porque não há sobreposição nenhuma: é redimensionamento.
  // ---------------------------------------------------------------------
  late final AnimationController _toolbarVisibility;
  double _lastScrollY = 0;
  bool _hasScrollBaseline = false;

  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');
  bool _nativeDrawerRequestInProgress = false;

  Future<void> _openNativeDrawer() async {
    if (_nativeDrawerRequestInProgress) return;
    _nativeDrawerRequestInProgress = true;
    try {
      final selected = await _nativeUi.invokeMethod<String>('showNativeDrawer', <String, Object>{
        'items': <Map<String, Object>>[
          {'label': appText('home'), 'value': 'home'},
          if (!widget.isIncognito) {'label': appText('history'), 'value': 'history'},
          if (!widget.isIncognito) {'label': appText('downloads'), 'value': 'downloads'},
          {'label': appText('bookmarks'), 'value': 'bookmarks'},
          {'label': appText('settings'), 'value': 'settings'},
        ],
      });
      if (!mounted || selected == null) return;
      switch (selected) {
        case 'home': ShellTabRequest.instance.request(0); break;
        case 'history': Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())); break;
        case 'downloads': Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsScreen())); break;
        case 'bookmarks': Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookmarksScreen())); break;
        case 'settings': Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())); break;
      }
    } on MissingPluginException {
      // Sem drawer nativo fora do Android.
    } on PlatformException {
      // O browser continua utilizável se o canal falhar.
    } finally {
      _nativeDrawerRequestInProgress = false;
    }
  }

  void _restartAiChat() {
    if (!_isAiSearchPage) return;
    setState(() {
      _aiPageHtml = null;
      _isLoading = true;
      _showProgress = true;
      _progress = 0;
      _webViewKey = UniqueKey();
    });
    unawaited(_loadAiSearchAsset());
  }

  @override
  void initState() {
    super.initState();
    _toolbarVisibility = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    final existingTab = tabsController.getTab(widget.tabId);
    _currentUrl = existingTab != null && existingTab.url.isNotEmpty
        ? existingTab.url
        : widget.initialUrl;
    _currentTitle = existingTab?.title ?? '';
    _isAiSearchPage = _currentUrl.startsWith('looply://ai-search');
    if (_isAiSearchPage) {
      final query = Uri.tryParse(_currentUrl)?.queryParameters['q'];
      if (query != null && query.trim().isNotEmpty) _currentTitle = query;
      unawaited(_loadAiSearchAsset());
    }
    _canGoBack = existingTab?.canGoBack ?? false;
    _canGoForward = existingTab?.canGoForward ?? false;
    // Quando já existe miniatura, a página tem histórico de carregamento;
    // evita-se apresentar um indicador de carregamento falso ao selecioná-la.
    _isLoading = existingTab?.thumbnail == null;
    _showProgress = _isLoading;

    browserFaviconCache.addListener(_onFaviconCacheChanged);
    adBlockEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    navigationAcceleratorEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    forceDarkWebsitesEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    siteThemeFollowsAppEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    adaptiveToolbarColorEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    appLanguageController.addListener(_onRuntimeWebViewSettingsChanged);
    appLanguageController.addListener(_onAppLanguageChanged);
    themeController.addListener(_onRuntimeWebViewSettingsChanged);
    themeController.pureDark.addListener(_onRuntimeWebViewSettingsChanged);
    BrowserPreconnectHints.setActive(widget.tabId, widget.isActive && !widget.isIncognito);

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: looplyPrimary),
      onRefresh: () async {
        try {
          final controller = _controller;
          if (controller != null) {
            await controller.reload();
          } else {
            _pullToRefreshController?.endRefreshing();
          }
        } catch (_) {
          _pullToRefreshController?.endRefreshing();
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    final changed = _lastAppBrightness != null && _lastAppBrightness != brightness;
    _lastAppBrightness = brightness;
    if (changed && _controller != null) {
      unawaited(_applyWebsiteAppearance(_controller!));
    }
  }

  @override
  void dispose() {
    _toolbarVisibility.dispose();
    _progressHideTimer?.cancel();
    _findDebounce?.cancel();
    _findController.dispose();
    _findFocusNode.dispose();
    browserFaviconCache.removeListener(_onFaviconCacheChanged);
    adBlockEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    navigationAcceleratorEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    forceDarkWebsitesEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    siteThemeFollowsAppEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    adaptiveToolbarColorEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    appLanguageController.removeListener(_onRuntimeWebViewSettingsChanged);
    appLanguageController.removeListener(_onAppLanguageChanged);
    themeController.removeListener(_onRuntimeWebViewSettingsChanged);
    themeController.pureDark.removeListener(_onRuntimeWebViewSettingsChanged);
    BrowserPreconnectHints.detach(widget.tabId);
    // Este State só é descartado quando o separador é realmente fechado.
    // Este State é descartado quando a aba deixa de ser a ativa.
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrbitBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      BrowserPreconnectHints.setActive(widget.tabId, widget.isActive && !widget.isIncognito);
    }
  }

  String get _acceptLanguageHeader {
    const regions = <String, String>{
      'pt': 'PT', 'en': 'US', 'es': 'ES', 'fr': 'FR', 'de': 'DE', 'it': 'IT',
      'ar': 'SA', 'zh': 'CN', 'ja': 'JP', 'ru': 'RU', 'hi': 'IN', 'tr': 'TR',
    };
    final code = appLanguageController.value.code;
    final region = regions[code] ?? 'US';
    return '$code,${code}-$region;q=0.9,en;q=0.7';
  }

  Future<void> _loadAiSearchAsset() async {
    try {
      final html = await rootBundle.loadString('assets/apps/ai_search/index.html');
      if (!mounted) return;
      setState(() => _aiPageHtml = html);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Não foi possível abrir a página local de pesquisa IA: $error';
        _isLoading = false;
        _showProgress = false;
      });
      _signalFirstLoad();
      final ready = widget.browserReadyCompleter;
      if (ready != null && !ready.isCompleted) ready.complete();
    }
  }

  Color? _parseCssColor(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    final hex = RegExp(r'^#([0-9a-f]{6}|[0-9a-f]{8})$').firstMatch(value);
    if (hex != null) {
      final digits = hex.group(1)!;
      final parsed = int.tryParse(digits, radix: 16);
      if (parsed == null) return null;
      return digits.length == 8 ? Color(parsed) : Color(0xFF000000 | parsed);
    }
    final rgb = RegExp(r'rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})').firstMatch(value);
    if (rgb != null) {
      final r = int.parse(rgb.group(1)!).clamp(0, 255).toInt();
      final g = int.parse(rgb.group(2)!).clamp(0, 255).toInt();
      final b = int.parse(rgb.group(3)!).clamp(0, 255).toInt();
      return Color.fromARGB(255, r, g, b);
    }
    return null;
  }

  /// Luminância perceptual (fórmula YIQ) em vez da luminância linear de
  /// computeLuminance(). A linear sobrestima o "brilho" de cores saturadas
  /// como roxo/laranja puro, fazendo a status bar escolher o contraste
  /// errado (ex.: roxo #FF4500-like a ficar classificado como "claro").
  double _perceivedBrightness(Color color) {
    return (color.red * 299 + color.green * 587 + color.blue * 114) / 1000 / 255;
  }

  bool _isLightSurface(Color color) => _perceivedBrightness(color) > .55;

  Color _contrastForeground(Color color) {
    return _isLightSurface(color) ? const Color(0xFF111111) : Colors.white;
  }

  /// Cor do pill de busca quando a toolbar adaptativa está ativa: mistura a
  /// cor do site com o tom de contraste (preto/branco) e aplica opacidade,
  /// para o pill ficar claramente distinguível do fundo sólido do appbar
  /// em vez de se misturar nele.
  Color _adaptivePillColor(Color toolbarColor) {
    final mixTarget = _isLightSurface(toolbarColor) ? Colors.black : Colors.white;
    return Color.lerp(toolbarColor, mixTarget, .22)!.withOpacity(.86);
  }

  Future<void> _applyWebsiteAppearance(_OrbitWebViewController controller) async {
    if (!mounted) return;
    final appIsDark = Theme.of(context).brightness == Brightness.dark;
    final forceDark = forceDarkWebsitesEnabled.value && !_isAiSearchPage;
    // Os sites seguem o modo efetivo do BrowseIt; não consultam o tema do SO.
    final followsApp = siteThemeFollowsAppEnabled.value;
    try {
      await controller.setSettings(
        cacheEnabled: !widget.isIncognito && navigationAcceleratorEnabled.value,
        adBlockEnabled: adBlockEnabled.value,
        forceDark: forceDark,
        followAppTheme: followsApp,
        appIsDark: appIsDark,
      );
      final scheme = followsApp ? (appIsDark ? 'dark' : 'light') : 'normal';
      final needsCssDarkFallback = defaultTargetPlatform != TargetPlatform.android;
      final script = '''(() => {
        try {
          const root = document.documentElement;
          root.style.setProperty('color-scheme', '$scheme');
          root.dataset.appTheme = '$scheme';
          let meta = document.querySelector('meta[name="color-scheme"]');
          if (!meta) { meta = document.createElement('meta'); meta.name = 'color-scheme'; document.head?.appendChild(meta); }
          meta.content = '$scheme';
          const id = 'browseit-forced-dark-style';
          let style = document.getElementById(id);
          if ($forceDark && $needsCssDarkFallback) {
            if (!style) { style = document.createElement('style'); style.id = id; document.head?.appendChild(style); }
            style.textContent = 'html{background:#111!important;filter:invert(1) hue-rotate(180deg)!important} img,video,canvas,picture,svg{filter:invert(1) hue-rotate(180deg)!important}';
          } else if (style) { style.remove(); }
        } catch (_) {}
      })();''';
      await controller.evaluateJavascript(script);
    } catch (_) {}
  }

  Future<void> _refreshAdaptiveToolbarColor(_OrbitWebViewController controller) async {
    if (widget.isIncognito || !adaptiveToolbarColorEnabled.value || _isAiSearchPage) {
      if (mounted && _siteToolbarColor != null) setState(() => _siteToolbarColor = null);
      return;
    }
    final raw = await controller.getPageToolbarColor();
    final color = _parseCssColor(raw);
    if (!mounted || color == null) return;
    if (_siteToolbarColor != color) setState(() => _siteToolbarColor = color);
  }

  void _onFaviconCacheChanged() {
    if (!mounted || _isAiSearchPage) return;
    final encoded = browserFaviconCache.forUrl(_currentUrl);
    if (encoded == null) {
      if (_currentFavicon != null) setState(() => _currentFavicon = null);
      return;
    }
    try {
      final bytes = base64Decode(encoded);
      setState(() => _currentFavicon = bytes);
    } catch (_) {}
  }
  void _onRuntimeWebViewSettingsChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    unawaited(_applyWebsiteAppearance(controller));
    if (adaptiveToolbarColorEnabled.value) unawaited(_refreshAdaptiveToolbarColor(controller));
    if (mounted) setState(() {});
  }

  void _onAppLanguageChanged() {
    _translationPromptedForUrl = null;
    if (!widget.isIncognito && !_isAiSearchPage && _controller != null) {
      unawaited(_maybeOfferTranslation());
    }
  }

  Future<void> _applyRuntimeWebViewSettings(
    _OrbitWebViewController controller,
  ) async {
    try {
      await _applyWebsiteAppearance(controller);
      if (adaptiveToolbarColorEnabled.value) {
        await _refreshAdaptiveToolbarColor(controller);
      }
    } catch (_) {
      // A alteração do interruptor não pode interromper a navegação atual.
    }
  }

  void _signalFirstLoad() {
    if (_firstLoadSignaled) return;
    _firstLoadSignaled = true;
    final completer = widget.firstLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _updateTabState({Uint8List? screenshot}) {
    tabsController.updateTab(
      widget.tabId,
      url: _currentUrl,
      title: _currentTitle.trim().isNotEmpty ? _currentTitle : _currentUrl,
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
      thumbnail: screenshot,
    );
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      final canBack = await controller.canGoBack();
      final canForward = await controller.canGoForward();
      final liveUrl = await controller.getUrl();
      final liveTitle = await controller.getTitle();
      if (!mounted) return;
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canForward;
        if (!_isAiSearchPage && liveUrl != null) _currentUrl = liveUrl.toString();
        if (!_isAiSearchPage && liveTitle?.trim().isNotEmpty == true) _currentTitle = liveTitle!;
      });
      _updateTabState();
    } catch (_) {
      // O WebView pode ainda estar a inicializar ou a recuperar o renderer.
    }
  }

  Future<bool> _tryWebViewBack() async {
    final controller = _controller;
    if (_canGoBack && controller != null && !_renderProcessCrashed) {
      try {
        await controller.goBack();
        return true;
      } catch (_) {
        // Se o renderer não responder, regressa à página principal.
      }
    }
    return false;
  }

  Future<void> _handleSystemBack() async {
    if (await _tryWebViewBack()) return;
    if (!mounted) return;
    ShellTabRequest.instance.request(0);
  }

  Future<Uint8List?> _captureScreenshot() async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      final raw = await controller
          .takeScreenshot()
          .timeout(const Duration(milliseconds: 900));
      if (raw == null || raw.isEmpty) return null;

      // Miniaturas pequenas evitam manter screenshots de ecrã inteiro para
      // dezenas de separadores. O Container Transform continua a usar a
      // captura de viewport independente; esta versão reduzida é só para a grelha.
      final codec = await ui.instantiateImageCodec(
        raw,
        targetWidth: 520,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          return data?.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  Rect? _rectInRootOverlay(GlobalKey key) {
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      final overlayBox = overlay.context.findRenderObject() as RenderBox?;
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (overlayBox == null ||
          box == null ||
          !box.attached ||
          box.size.isEmpty) {
        return null;
      }
      final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
      return topLeft & box.size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openTabsGrid() async {
    if (_tabsRequestInProgress) return;
    _tabsRequestInProgress = true;
    try {
      // Esta é agora a ÚNICA captura de screenshot do browser — acontece
      // exatamente quando o utilizador está a sair para a grelha de abas,
      // nunca automaticamente a seguir a um carregamento de página. Sem
      // nenhuma outra captura a correr em paralelo nesse instante, não há
      // disputa pelo takeScreenshot() do WebView e por isso não há flash
      // visível ao tocar em "Abas".
      final screenshot = await _captureScreenshot();
      if (screenshot != null) _updateTabState(screenshot: screenshot);

      if (!mounted) return;
      final viewportRect = _rectInRootOverlay(widget.viewportKey);
      ShellTabRequest.instance.requestCloseBrowser(
        tabId: widget.tabId,
        screenshot: screenshot ?? tabsController.getTab(widget.tabId)?.thumbnail,
        sourceRect: viewportRect,
      );
    } finally {
      _tabsRequestInProgress = false;
    }
  }

  void _enterFindInPage() {
    if (!mounted) return;
    _findController.clear();
    setState(() => _isFindInPage = true);
    _toolbarVisibility.animateTo(1.0, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocusNode.requestFocus();
    });
  }

  void _onFindTextChanged(String value) {
    _findDebounce?.cancel();
    _findDebounce = Timer(const Duration(milliseconds: 180), () async {
      final controller = _controller;
      if (controller == null || !mounted) return;
      try {
        if (value.trim().isEmpty) {
          await controller.clearMatches();
        } else {
          await controller.findAll(value.trim());
        }
      } catch (_) {}
    });
  }

  Future<void> _moveFindResult(bool forward) async {
    final controller = _controller;
    if (controller == null || _findController.text.trim().isEmpty) return;
    try {
      await controller.findNext(forward);
    } catch (_) {}
  }

  Future<void> _exitFindInPage() async {
    _findDebounce?.cancel();
    _findFocusNode.unfocus();
    try {
      await _controller?.clearMatches();
    } catch (_) {}
    if (!mounted) return;
    _findController.clear();
    setState(() => _isFindInPage = false);
  }

  Future<void> _openSearchWithExpandAnimation() async {
    if (_isExpandingToSearch) return;
    setState(() => _isExpandingToSearch = true);

    // Dá tempo da animação de expansão do pill (e do fade do leading/actions)
    // terminar antes de empurrar a tela de pesquisa, para que a transição
    // pareça contínua: o pill cresce, os botões somem, e então a busca
    // aparece com fade.
    await Future<void>.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      FadePageRoute<void>(builder: (_) => SearchScreen(isIncognito: widget.isIncognito)),
    );

    if (!mounted) return;
    setState(() => _isExpandingToSearch = false);
  }

  // ---------------------------------------------------------------------
  // Tradução via API pública sem chave (translate_service.dart), com
  // SnackBar de confirmação em vez do widget flutuante do Google Translate.
  // ---------------------------------------------------------------------

  String _normalizeLanguageCode(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-').split('-').first;

  Future<void> _maybeOfferTranslation() async {
    if (_isAiSearchPage || widget.isIncognito || !mounted) return;
    final pageUrl = _currentUrl;
    if (_translationPromptedForUrl == pageUrl) return;
    final controller = _controller;
    if (controller == null) return;

    final targetCode = _normalizeLanguageCode(appLanguageController.value.code);
    final detected = await controller.getPageLanguage();
    if (!mounted || pageUrl != _currentUrl || detected == null || detected.isEmpty) return;
    final siteCode = _normalizeLanguageCode(detected);
    if (siteCode == targetCode) return;

    _translationPromptedForUrl = pageUrl;
    _showTranslateSnackBar(targetCode);
  }

  SnackBar _translationSnackBar(String message, {SnackBarAction? action, Duration? duration}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF202124);
    return SnackBar(
      duration: duration ?? const Duration(seconds: 5),
      backgroundColor: isDark ? const Color(0xFF34363A) : const Color(0xFFF1F3F4),
      content: Text(message, style: TextStyle(color: foreground, fontWeight: FontWeight.w500)),
      action: action == null
          ? null
          : SnackBarAction(
              label: action.label,
              textColor: foreground,
              onPressed: action.onPressed,
            ),
    );
  }

  void _showTranslateSnackBar(String targetCode) {
    if (!mounted || widget.isIncognito) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      _translationSnackBar(
        appText('translate_page_prompt'),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: appText('translate'),
          onPressed: () => unawaited(_translateCurrentPage(targetCode)),
        ),
      ),
    );
  }

  Future<void> _translateCurrentPage(String targetCode) async {
    final controller = _controller;
    if (controller == null || !mounted || widget.isIncognito) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      _translationSnackBar(appText('translating_page'), duration: const Duration(seconds: 3)),
    );
    try {
      final translated = await PageTranslateService.translateWebView(
        controller: controller.plugin,
        targetLanguageCode: _normalizeLanguageCode(targetCode),
      );
      if (!translated) throw StateError('Google Translate returned no translated text.');
      _pageIsTranslated = true;
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(_translationSnackBar(appText('translation_failed')));
      }
    }
  }

  Future<void> _runShortcut(_OrbitMenuAction action) async {
    if (!mounted) return;
    switch (action) {
      case _OrbitMenuAction.back:
        await _controller?.goBack();
        await _refreshNavigationState();
        break;
      case _OrbitMenuAction.forward:
        await _controller?.goForward();
        await _refreshNavigationState();
        break;
      case _OrbitMenuAction.copyAddress:
        await Clipboard.setData(ClipboardData(text: _currentUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appText('copied')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case _OrbitMenuAction.siteInfo:
        _showSiteInfo();
        break;
      case _OrbitMenuAction.reload:
        await _controller?.reload();
        break;
      case _OrbitMenuAction.openSearch:
        unawaited(_openSearchWithExpandAnimation());
        break;
      case _OrbitMenuAction.findInPage:
        _enterFindInPage();
        break;
      case _OrbitMenuAction.newTab:
        final newTab = tabsController.createBrowserTab('https://www.google.com', isIncognito: widget.isIncognito);
        ShellTabRequest.instance.requestBrowser(newTab.id);
        break;
      case _OrbitMenuAction.bookmarks:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookmarksScreen()));
        break;
      case _OrbitMenuAction.settings:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
      case _OrbitMenuAction.goHome:
        ShellTabRequest.instance.request(0);
        break;
      case _OrbitMenuAction.history:
        if (widget.isIncognito) break;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
        break;
      case _OrbitMenuAction.downloads:
        if (widget.isIncognito) break;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DownloadsScreen()),
        );
        break;
      case _OrbitMenuAction.translate:
        if (!widget.isIncognito) {
          unawaited(_translateCurrentPage(appLanguageController.value.code));
        }
        break;
      case _OrbitMenuAction.bookmark:
        if (bookmarksController.contains(_currentUrl)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(appText('already_bookmarked'))),
            );
          }
        } else {
          bookmarksController.add(
            _currentTitle.trim().isEmpty ? _currentUrl : _currentTitle,
            _currentUrl,
          );
          unawaited(browserFaviconCache.fetchForUrl(_currentUrl));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(appText('bookmark_saved'))),
            );
          }
        }
        break;
      case _OrbitMenuAction.desktopSite:
        await _toggleDesktopSite();
        break;
      case _OrbitMenuAction.zoomIn:
        await _applyZoom(0.1);
        break;
      case _OrbitMenuAction.zoomOut:
        await _applyZoom(-0.1);
        break;
      case _OrbitMenuAction.print:
        await _printCurrentPage();
        break;
      case _OrbitMenuAction.addToHomeScreen:
        await _addCurrentPageToHomeScreen();
        break;
    }
  }

  Future<void> _toggleDesktopSite() async {
    final controller = _controller;
    if (controller == null) return;
    _desktopSiteRequested = !_desktopSiteRequested;
    if (mounted) setState(() {});
    const desktopUserAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    try {
      await controller.plugin.setSettings(
        settings: InAppWebViewSettings(
          userAgent: _desktopSiteRequested ? desktopUserAgent : null,
          preferredContentMode: _desktopSiteRequested
              ? UserPreferredContentMode.DESKTOP
              : UserPreferredContentMode.MOBILE,
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      );
      await controller.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_desktopSiteRequested ? 'Site de desktop ativado' : 'Site de desktop desativado'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _applyZoom(double delta) async {
    final controller = _controller;
    if (controller == null) return;
    _pageZoomFactor = (_pageZoomFactor + delta).clamp(0.5, 2.0).toDouble();
    try {
      await controller.evaluateJavascript(
        "document.body.style.zoom = '${(_pageZoomFactor * 100).round()}%';",
      );
    } catch (_) {}
  }

  Future<void> _printCurrentPage() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.plugin.printCurrentPage();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível imprimir esta página.')),
        );
      }
    }
  }

  Future<void> _addCurrentPageToHomeScreen() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atalho para o ecrã inicial ainda não está disponível nesta versão.')),
    );
  }

  void _showBrowserOptionsSheet() {
    final surface = panelColor(context);
    final muted = mutedText(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .76,
        minChildSize: .48,
        maxChildSize: .92,
        expand: false,
        builder: (context, scrollController) => Material(
          color: surface,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(color: muted.withOpacity(.5), borderRadius: BorderRadius.circular(99)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                    children: [
                      _BrowserQuickAction(icon: AppIcons.arrowLeft, label: appText('go_back'), enabled: _canGoBack, onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.back)),
                      _BrowserQuickAction(icon: AppIcons.arrowRight, label: appText('go_forward'), enabled: _canGoForward, onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.forward)),
                      _BrowserQuickAction(icon: AppIcons.plus, label: appText(widget.isIncognito ? 'new_private_tab' : 'new_tab'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.newTab)),
                      _BrowserQuickAction(icon: AppIcons.bookmarksSimple, label: appText('bookmarks'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.bookmarks)),
                      _BrowserQuickAction(icon: AppIcons.gear, label: appText('settings'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.settings)),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: muted.withOpacity(.18), indent: 22, endIndent: 22),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                    children: [
                      if (!widget.isIncognito) _BrowserSheetListItem(icon: AppIcons.clockCounterClockwise, label: appText('history'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.history)),
                      if (!widget.isIncognito) _BrowserSheetListItem(icon: AppIcons.downloadSimple, label: appText('downloads'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.downloads)),
                      _BrowserSheetListItem(icon: AppIcons.magnifyingGlass, label: appText('find_in_page'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.findInPage)),
                      _BrowserSheetListItem(icon: AppIcons.bookmarkSimple, label: appText('add_bookmark'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.bookmark)),
                      if (!widget.isIncognito) _BrowserSheetListItem(icon: AppIcons.sparkles, label: appText('translate'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.translate)),
                      Divider(height: 18, color: muted.withOpacity(.18), indent: 12, endIndent: 12),
                      _BrowserSheetListItem(icon: AppIcons.clockCounterClockwise, label: appText('reload_page'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.reload)),
                      _BrowserSheetListItem(
                        icon: AppIcons.browser,
                        label: _desktopSiteRequested ? 'Desativar site de desktop' : 'Site de desktop',
                        onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.desktopSite),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(child: _BrowserSheetListItem(icon: AppIcons.magnifyingGlass, label: 'Reduzir zoom (-)', onTap: () => unawaited(_runShortcut(_OrbitMenuAction.zoomOut)))),
                            Expanded(child: _BrowserSheetListItem(icon: AppIcons.magnifyingGlass, label: 'Aumentar zoom (+)', onTap: () => unawaited(_runShortcut(_OrbitMenuAction.zoomIn)))),
                          ],
                        ),
                      ),
                      _BrowserSheetListItem(icon: AppIcons.fileArrowUp, label: 'Imprimir', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.print)),
                      _BrowserSheetListItem(icon: AppIcons.plus, label: 'Adicionar ao ecrã inicial', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.addToHomeScreen)),
                      _BrowserSheetListItem(icon: AppIcons.copy, label: appText('copy_address'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.copyAddress)),
                      _BrowserSheetListItem(icon: AppIcons.info, label: appText('site_info'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.siteInfo)),
                      _BrowserSheetListItem(icon: AppIcons.house, label: appText('home_page'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.goHome)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectSheetAction(BuildContext sheetContext, _OrbitMenuAction action) {
    Navigator.of(sheetContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runShortcut(action));
    });
  }

  void _retryPage() {
    final controller = _controller;
    if (!_renderProcessCrashed && controller != null) {
      setState(() {
        _loadError = null;
        _isLoading = true;
        _showProgress = true;
        _progress = 0;
      });
      unawaited(controller.reload());
      return;
    }

    setState(() {
      _controller = null;
      _renderProcessCrashed = false;
      _loadError = null;
      _isLoading = true;
      _showProgress = true;
      _progress = 0;
      _webViewKey = UniqueKey();
    });
  }

  void _showSiteInfo() {
    final uri = Uri.tryParse(_currentUrl);
    final host = uri?.host.isNotEmpty == true ? uri!.host : _currentUrl;
    unawaited(showLooplyDialog<bool>(
      context: context,
      title: appText('site_info'),
      icon: AppIcons.info,
      message: _currentTitle.isEmpty ? host : _currentTitle,
      secondaryMessage: _currentUrl,
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('close'), value: true),
      ],
    ));
  }

  // ---------------------------------------------------------------------
  // Long-press contextual: deteta o tipo de elemento tocado (imagem, vídeo,
  // link simples) via hitTestResult e mostra apenas as opções relevantes
  // a esse tipo, usando o LooplyPopupMenuButton já existente no projeto
  // (mesmo componente sem bordas usado no resto da app).
  // ---------------------------------------------------------------------

  final GlobalKey _longPressAnchorKey = GlobalKey();
  Offset? _lastLongPressGlobalPosition;

  Future<void> _handleLongPressHitTest(InAppWebViewHitTestResult hitTestResult) async {
    if (!mounted) return;
    final type = hitTestResult.type;
    final extra = hitTestResult.extra;
    if (extra == null || extra.trim().isEmpty) return;
    final isImage = type == InAppWebViewHitTestResultType.IMAGE_TYPE ||
        type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE;
    final isVideoOrAudio = _looksLikeMediaUrl(extra);
    final isLink = type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE;
    if (!isImage && !isVideoOrAudio && !isLink) return;
    HapticFeedback.mediumImpact();

    final kind = isImage ? MediaSheetKind.image : (isVideoOrAudio ? MediaSheetKind.video : MediaSheetKind.link);
    final options = <MediaSheetOption>[];
    if (isImage) {
      options.add(const MediaSheetOption(action: MediaSheetAction.openNewTab, label: 'Abrir imagem num novo separador', icon: AppIcons.arrowUpLeft));
      options.add(const MediaSheetOption(action: MediaSheetAction.preview, label: 'Pré-visualizar imagem', icon: AppIcons.eye));
      if (!widget.isIncognito) options.add(const MediaSheetOption(action: MediaSheetAction.download, label: 'Transferir imagem', icon: AppIcons.downloadSimple));
      options.add(const MediaSheetOption(action: MediaSheetAction.copyLink, label: 'Copiar imagem', icon: AppIcons.copy));
      options.add(const MediaSheetOption(action: MediaSheetAction.shareLink, label: 'Partilhar imagem', icon: AppIcons.uploadSimple));
    } else if (isVideoOrAudio) {
      options.add(const MediaSheetOption(action: MediaSheetAction.openNewTab, label: 'Abrir num novo separador', icon: AppIcons.arrowUpLeft));
      if (!widget.isIncognito) options.add(const MediaSheetOption(action: MediaSheetAction.download, label: 'Transferir vídeo', icon: AppIcons.downloadSimple));
      options.add(const MediaSheetOption(action: MediaSheetAction.copyLink, label: 'Copiar ligação', icon: AppIcons.copy));
      options.add(const MediaSheetOption(action: MediaSheetAction.shareLink, label: 'Partilhar ligação', icon: AppIcons.uploadSimple));
    } else {
      options.add(const MediaSheetOption(action: MediaSheetAction.openNewTab, label: 'Abrir num novo separador', icon: AppIcons.arrowUpLeft));
      options.add(const MediaSheetOption(action: MediaSheetAction.preview, label: 'Pré-visualizar página', icon: AppIcons.eye));
      options.add(const MediaSheetOption(action: MediaSheetAction.copyLink, label: 'Copiar ligação', icon: AppIcons.copy));
      options.add(const MediaSheetOption(action: MediaSheetAction.bookmarkLink, label: 'Adicionar aos favoritos', icon: AppIcons.bookmarkSimple));
      options.add(const MediaSheetOption(action: MediaSheetAction.shareLink, label: 'Partilhar ligação', icon: AppIcons.uploadSimple));
    }

    Uint8List? faviconBytes;
    final encoded = isLink ? browserFaviconCache.forUrl(extra) : null;
    if (encoded != null) {
      try { faviconBytes = base64Decode(encoded); } catch (_) {}
    } else if (isLink) {
      unawaited(browserFaviconCache.fetchForUrl(extra));
    }
    if (!mounted) return;
    final action = await showMediaContextSheet(
      context: context, kind: kind, url: extra, faviconBytes: faviconBytes, options: options,
    );
    if (action != null) unawaited(_runMediaSheetAction(action, extra));
  }
  bool _looksLikeMediaUrl(String url) {
    final lower = url.toLowerCase();
    const videoExtensions = ['.mp4', '.webm', '.mov', '.m3u8', '.mkv', '.avi'];
    const audioExtensions = ['.mp3', '.wav', '.ogg', '.m4a', '.flac'];
    return videoExtensions.any(lower.contains) || audioExtensions.any(lower.contains);
  }

  Future<void> _runMediaSheetAction(MediaSheetAction action, String url) async {
    switch (action) {
      case MediaSheetAction.download:
        if (!widget.isIncognito) {
          downloadsController.register(url: url);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('download_received'))));
        }
        break;
      case MediaSheetAction.openNewTab:
        final newTab = tabsController.createBrowserTab(url, isIncognito: widget.isIncognito);
        ShellTabRequest.instance.requestBrowser(newTab.id);
        break;
      case MediaSheetAction.preview:
        await PagePreviewModal.show(
          context: context,
          url: url,
          onOpenInNewTab: () {
            final newTab = tabsController.createBrowserTab(url, isIncognito: widget.isIncognito);
            ShellTabRequest.instance.requestBrowser(newTab.id);
          },
        );
        break;
      case MediaSheetAction.copyLink:
      case MediaSheetAction.shareLink:
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('copied')), duration: const Duration(seconds: 2)));
        break;
      case MediaSheetAction.bookmarkLink:
        if (bookmarksController.contains(url)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('already_bookmarked'))));
        } else {
          bookmarksController.add(url, url);
          unawaited(browserFaviconCache.fetchForUrl(url));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('bookmark_saved'))));
        }
        break;
    }
  }

  // ---------------------------------------------------------------------
  // Toolbar que esconde/mostra conforme o scroll da página, ligada 1:1
  // ao gesto do dedo. Ao contrário da versão anterior (Transform.translate
  // sobre um Stack), aqui a appbar faz parte de uma Column normal com o
  // WebView; o valor de _toolbarVisibility controla diretamente a ALTURA
  // que ela ocupa no layout. Isto significa que quando ela encolhe, o
  // espaço dela desaparece de verdade e o Expanded do WebView cresce
  // para ocupar esse espaço — nunca há conteúdo do site escondido atrás
  // da appbar, porque não existe sobreposição nenhuma.
  // ---------------------------------------------------------------------

  void _onWebViewScrollChanged(int x, int y) {
    if (_isFindInPage || _isExpandingToSearch) return;
    final yd = y.toDouble();
    if (!_hasScrollBaseline) {
      _lastScrollY = yd;
      _hasScrollBaseline = true;
      return;
    }
    final delta = yd - _lastScrollY;
    _lastScrollY = yd;
    if (delta == 0) return;

    // Perto do topo da página a toolbar fica sempre visível, como nos
    // browsers nativos (evita escondê-la logo no primeiro pixel de scroll).
    if (yd <= 4) {
      if (_toolbarVisibility.value != 1.0) {
        _toolbarVisibility.value = 1.0;
      }
      return;
    }

    // Sem animação: o valor segue o delta do dedo diretamente, frame a
    // frame, tal como o scroll físico da página — por isso não há atraso.
    final toolbarHeight = kToolbarHeight + 2.4;
    final next = (_toolbarVisibility.value - (delta / toolbarHeight)).clamp(0.0, 1.0);
    _toolbarVisibility.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final useAdaptiveToolbar = !widget.isIncognito && !_isAiSearchPage && adaptiveToolbarColorEnabled.value && _siteToolbarColor != null;
    final toolbarColor = _isAiSearchPage ? bg : (useAdaptiveToolbar ? _siteToolbarColor! : bg);
    final toolbarText = useAdaptiveToolbar ? _contrastForeground(toolbarColor) : text;
    final pillBackground = useAdaptiveToolbar
        ? _adaptivePillColor(toolbarColor)
        : pillColor(context);
    final parsedUri = Uri.tryParse(_currentUrl);
    final fallbackTitle = _isAiSearchPage
        ? appText('research_ai')
        : (parsedUri?.host.isNotEmpty == true ? parsedUri!.host : 'Orbit Browser');

    // A status bar usa EXATAMENTE a mesma cor da appbar — sem mistura,
    // sem dessaturação. Se o site mudar de tom, a status bar muda junto,
    // 100% do mesmo valor, no mesmo frame.
    final statusBarSurface = toolbarColor;
    final statusBarIsLight = _isLightSurface(statusBarSurface);

    final fullToolbarHeight = kToolbarHeight + 2.4;
    final currentToolbarHeight = fullToolbarHeight * _toolbarVisibility.value;

    return PopScope<void>(
      // Esta tela só existe para a aba ativa; por isso apenas ela intercepta
      // o botão Voltar e não há WebViews Offstage a interferir na navegação.
      canPop: !widget.isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !widget.isActive) return;
        await _handleSystemBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (statusBarIsLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIsLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: statusBarIsLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: bg,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: bg,
          extendBodyBehindAppBar: false,
          // Column normal: status bar, appbar (altura variável, nunca
          // sobreposta a nada), e o WebView a ocupar o resto do espaço
          // via Expanded. Sem Stack, sem flutuação — redimensionamento
          // real, como os browsers nativos fazem.
          body: Column(
            children: [
              // Faixa de status bar: sempre a MESMA cor exata da appbar,
              // sempre visível (não esconde com o scroll).
              Container(
                color: statusBarSurface,
                height: MediaQuery.paddingOf(context).top,
                width: double.infinity,
              ),
              // Appbar com altura controlada diretamente por
              // _toolbarVisibility: quando ela chega a 0, a altura real
              // no layout é 0 — o espaço dela desaparece de verdade.
              ClipRect(
                child: SizedBox(
                  height: currentToolbarHeight,
                  child: OverflowBox(
                    maxHeight: fullToolbarHeight,
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: toolbarColor,
                      elevation: 0,
                      child: SizedBox(
                        height: fullToolbarHeight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: kToolbarHeight,
                              child: _buildAppBarContent(
                                context: context,
                                toolbarText: toolbarText,
                                pillBackground: pillBackground,
                                muted: muted,
                                fallbackTitle: fallbackTitle,
                              ),
                            ),
                            SizedBox(
                              height: 2.4,
                              child: AnimatedOpacity(
                                opacity: _showProgress ? 1 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(end: _progress.clamp(0.0, 1.0)),
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animatedProgress, _) => LinearProgressIndicator(
                                    value: animatedProgress,
                                    minHeight: 2.4,
                                    color: accentColor(context),
                                    backgroundColor: Colors.transparent,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RepaintBoundary(
                  key: widget.viewportKey,
                  child: _buildWebView(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarContent({
    required BuildContext context,
    required Color toolbarText,
    required Color pillBackground,
    required Color muted,
    required String fallbackTitle,
  }) {
    return Row(
      children: [
        const SizedBox(width: 4),
        AnimatedOpacity(
          opacity: _isExpandingToSearch ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: _isExpandingToSearch,
            // Modo IA: sem pill de fundo no botão — ícone solto, mais limpo,
            // interface de browser mais completa sem pills extra competindo
            // com a UI de chat.
            child: _isAiSearchPage
                ? IconButton(
                    tooltip: appText('home'),
                    icon: AppSvgIcon(AppIcons.list, color: toolbarText),
                    onPressed: _openNativeDrawer,
                  )
                : IconButton(
                    tooltip: appText('home'),
                    icon: AppSvgIcon(AppIcons.house, color: toolbarText),
                    onPressed: () => ShellTabRequest.instance.request(0),
                  ),
          ),
        ),
        Expanded(
          child: _isFindInPage
              ? _buildFindInPageBar(toolbarText, muted)
              : _buildTitlePill(context, toolbarText, pillBackground, muted, fallbackTitle),
        ),
        if (!_isFindInPage)
          AnimatedOpacity(
            opacity: _isExpandingToSearch ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: _isExpandingToSearch,
              child: _isAiSearchPage
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: tabsController,
                          builder: (context, _) => IconButton(
                            tooltip: appText('tabs'),
                            icon: _TabsCountIcon(count: tabsController.count, color: toolbarText),
                            onPressed: _openTabsGrid,
                          ),
                        ),
                        IconButton(
                          tooltip: appText('new_chat'),
                          icon: AppSvgIcon(AppIcons.plus, color: toolbarText),
                          onPressed: _restartAiChat,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: tabsController,
                          builder: (context, _) => IconButton(
                            tooltip: appText('tabs'),
                            icon: _TabsCountIcon(count: tabsController.count, color: toolbarText),
                            onPressed: _openTabsGrid,
                          ),
                        ),
                        IconButton(
                          tooltip: appText('more_options'),
                          icon: AppSvgIcon(AppIcons.dotsThreeVertical, color: toolbarText),
                          onPressed: _showBrowserOptionsSheet,
                        ),
                      ],
                    ),
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildFindInPageBar(Color toolbarText, Color muted) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _findController,
            focusNode: _findFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onFindTextChanged,
            onSubmitted: (_) => _moveFindResult(true),
            style: TextStyle(color: toolbarText, fontSize: 14),
            decoration: InputDecoration(
              hintText: appText('search_in_page'),
              hintStyle: TextStyle(color: muted, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        IconButton(
          tooltip: appText('previous_result'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _moveFindResult(false),
          icon: AppSvgIcon(AppIcons.caretUp, color: toolbarText),
        ),
        IconButton(
          tooltip: appText('next_result'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _moveFindResult(true),
          icon: AppSvgIcon(AppIcons.caretDown, color: toolbarText),
        ),
        IconButton(
          tooltip: appText('close_search'),
          visualDensity: VisualDensity.compact,
          onPressed: _exitFindInPage,
          icon: AppSvgIcon(AppIcons.x, color: toolbarText),
        ),
      ],
    );
  }

  Widget _buildPillFavicon(Color muted) {
    const size = 19.0;
    final favicon = _currentFavicon;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: favicon != null
            ? Image.memory(
                favicon,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => AppSvgIcon(AppIcons.magnifyingGlass, color: muted, size: size),
              )
            : AppSvgIcon(AppIcons.magnifyingGlass, color: muted, size: size),
      ),
    );
  }
  Widget _buildTitlePill(BuildContext context, Color toolbarText, Color pillBackground, Color muted, String fallbackTitle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsedWidth = constraints.maxWidth;
        const leadingWidth = 56.0;
        const actionsWidth = 96.0;
        final expandedWidth = collapsedWidth + leadingWidth + actionsWidth;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _isExpandingToSearch ? 1 : 0),
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            final width = collapsedWidth + (expandedWidth - collapsedWidth) * t;
            return SizedBox(width: _isAiSearchPage ? null : width, child: child);
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _isAiSearchPage ? null : _openSearchWithExpandAnimation,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  // Modo IA: sem pill — título solto sobre o appbar.
                  color: _isAiSearchPage ? Colors.transparent : pillBackground,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisSize: _isAiSearchPage ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    if (!_isAiSearchPage) ...[
                      _buildPillFavicon(muted),
                      const SizedBox(width: 9),
                    ],
                    _isAiSearchPage
                        ? Text(_currentTitle.isNotEmpty ? _currentTitle : fallbackTitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: toolbarText, fontSize: 14, fontWeight: FontWeight.w600))
                        : Expanded(
                            child: Text(
                              _currentTitle.isNotEmpty ? _currentTitle : fallbackTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: toolbarText, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebView(BuildContext context) => _buildPluginWebView(context);

  Widget _buildPluginWebView(BuildContext context) {
    // Fundo igual ao fundo real do tema atual (claro ou escuro) — nunca
    // uma cor escura fixa independente do tema. É isto que fica visível
    // por trás da WebView durante o instante inicial do carregamento,
    // antes de o HTML/CSS da página pintar o próprio fundo.
    final bg = pageBg(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        if (!_renderProcessCrashed && (!_isAiSearchPage || _aiPageHtml != null))
          // Overscan: a WebView é desenhada 2px lógicos além da margem
          // direita e inferior reais; o Stack pai corta esse excesso. O
          // arredondamento de sub-pixel que causava a linha branca cai
          // agora na parte cortada, fora do que é visível.
          Positioned(
            left: 0,
            top: 0,
            right: -_kWebViewOverscan,
            bottom: -_kWebViewOverscan,
            child: InAppWebView(
              key: _webViewKey,
              initialUrlRequest: _isAiSearchPage ? null : URLRequest(
                url: WebUri(_currentUrl),
                headers: <String, String>{'Accept-Language': _acceptLanguageHeader},
              ),
              initialData: _isAiSearchPage
                  ? InAppWebViewInitialData(
                      data: _aiPageHtml!,
                      baseUrl: WebUri('https://browseit.local/'),
                    )
                  : null,
              pullToRefreshController: _pullToRefreshController,
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                mediaPlaybackRequiresUserGesture: false,

                // Fundo OPACO, nunca transparente: um WebView transparente
                // deixaria ver o que está por trás dele (que, antes do
                // body/CSS da página pintar, seria o fundo do app) — mas
                // crucialmente a cor por trás (ColoredBox acima) já segue
                // o tema atual, então aqui o importante é não somar uma
                // segunda camada transparente que possa escurecer por
                // composição. O WebView pinta a própria cor real da
                // página assim que ela carrega, por cima desta base.
                transparentBackground: false,

                // A sessão privada desativa cache HTTP e gravação de formulários.
                // O isolamento de cookies/WebStorage depende do perfil nativo;
                // ver NOTA_MODO_PRIVADO_ANDROID.md.
                cacheEnabled: !widget.isIncognito && navigationAcceleratorEnabled.value,
                cacheMode: !widget.isIncognito && navigationAcceleratorEnabled.value
                    ? CacheMode.LOAD_DEFAULT
                    : CacheMode.LOAD_NO_CACHE,
                algorithmicDarkeningAllowed: !_isAiSearchPage &&
                    (forceDarkWebsitesEnabled.value ||
                        (siteThemeFollowsAppEnabled.value &&
                            Theme.of(context).brightness == Brightness.dark)),

                hardwareAcceleration: true,
                useHybridComposition: true,

                textZoom: 100,
                minimumFontSize: 1,

                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                preferredContentMode: UserPreferredContentMode.MOBILE,

                // Scrollbar vertical fina, estilo overlay: aparece só
                // durante o scroll e desvanece, em vez da barra espessa
                // clássica do WebView antigo.
                verticalScrollBarEnabled: true,
                horizontalScrollBarEnabled: false,
                scrollBarStyle: ScrollBarStyle.SCROLLBARS_INSIDE_OVERLAY,
                scrollbarFadingEnabled: true,
                overScrollMode: OverScrollMode.NEVER,

                // Compatibilidade com sites reais.
                mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                thirdPartyCookiesEnabled: !widget.isIncognito,
                saveFormData: !widget.isIncognito,

                // iOS
                enableViewportScale: true,
                allowsInlineMediaPlayback: true,
                allowsBackForwardNavigationGestures: true,

                isInspectable: kDebugMode,

                // Não ativar InAppWebViewSettings.incognito aqui: na implementação
                // Android desse plugin, essa opção remove cookies do CookieManager
                // global e pode terminar sessões normais. O isolamento completo por
                // perfil requer suporte nativo AndroidX Multi-Profile no plugin.
                useOnDownloadStart: true,
                useShouldOverrideUrlLoading: true,
                contentBlockers: buildPlatformAdBlockers(enabled: adBlockEnabled.value),
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: false,
              ),
              onLongPressHitTestResult: (controller, hitTestResult) {
                unawaited(_handleLongPressHitTest(hitTestResult));
              },
              onScrollChanged: (controller, x, y) {
                _onWebViewScrollChanged(x, y);
              },
              shouldOverrideUrlLoading: (controller, action) async {
                final uri = action.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;
                final scheme = uri.scheme.toLowerCase();
                if (scheme == 'http' ||
                    scheme == 'https' ||
                    scheme == 'about' ||
                    scheme == 'data' ||
                    scheme == 'blob' ||
                    scheme == 'javascript') {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy.CANCEL;
              },
              onCreateWindow: (controller, action) async {
                // Links target="_blank" abrem no separador atual em vez de
                // criarem uma janela nativa invisível que pode bloquear o WebView.
                final target = action.request.url;
                if (target == null || action.hasGesture != true) return false;
                if (isAdBlockedUrl(target.toString())) return false;
                final scheme = target.scheme.toLowerCase();
                if (scheme != 'http' && scheme != 'https') return false;
                try {
                  await controller.loadUrl(
                    urlRequest: URLRequest(url: target),
                  );
                } catch (_) {}
                // A navegação já foi encaminhada para a WebView atual; cancela
                // apenas a criação do popup separado.
                return false;
              },
              onWebViewCreated: (controller) async {
                final orbitController = _OrbitWebViewController(controller);
                _controller = orbitController;
                if (!widget.isIncognito) BrowserPreconnectHints.attach(widget.tabId, orbitController.evaluateJavascript);
                if (_isAiSearchPage) {
                  controller.addJavaScriptHandler(
                    handlerName: 'browseItAiSearchSubmit',
                    callback: (arguments) {
                      final query = arguments.isNotEmpty ? arguments.first.toString().trim() : '';
                      if (query.isEmpty) return false;
                      if (!widget.isIncognito) searchHistoryController.add(query);
                      if (mounted) {
                        setState(() {
                          _currentTitle = query;
                          _currentUrl = 'looply://ai-search?q=${Uri.encodeComponent(query)}';
                        });
                        _updateTabState();
                      }
                      return true;
                    },
                  );
                }
                await installNativeAdBlocker();
                unawaited(_applyRuntimeWebViewSettings(orbitController));
                final ready = widget.browserReadyCompleter;
                if (ready != null && !ready.isCompleted) ready.complete();
                unawaited(_refreshNavigationState());
              },
              onProgressChanged: (controller, progress) {
                if (!mounted) return;
                _progressHideTimer?.cancel();
                setState(() {
                  _showProgress = true;
                  _progress = (progress / 100).clamp(0.0, 1.0);
                  if (progress < 100) _isLoading = true;
                });
              },
              onLoadStart: (controller, url) {
                if (!mounted) return;
                _progressHideTimer?.cancel();
                final nextUrl = url?.toString();
                if (_isAiSearchPage && nextUrl != null && !nextUrl.startsWith('https://browseit.local/')) {
                  _isAiSearchPage = false;
                  _siteToolbarColor = null;
                }
                _hasScrollBaseline = false;
                if (_toolbarVisibility.value != 1.0) {
                  _toolbarVisibility.animateTo(1.0, curve: Curves.easeOutCubic);
                }
                setState(() {
                  if (!_isAiSearchPage) _siteToolbarColor = null;
                  _isLoading = true;
                  _showProgress = true;
                  _progress = 0;
                  _loadError = null;
                  if (nextUrl != null && !_isAiSearchPage) _currentUrl = nextUrl;
                });
                _pageIsTranslated = false;
                _updateTabState();
                _onFaviconCacheChanged();
              },
              onTitleChanged: (controller, title) {
                if (!mounted) return;
                if (!_isAiSearchPage) _currentTitle = title ?? '';
                _updateTabState();
                setState(() {});
              },
              onUpdateVisitedHistory: (controller, url, isReload) async {
                if (!mounted || url == null) return;
                final nextUrl = url.toString();
                bool canBack = _canGoBack;
                bool canForward = _canGoForward;
                String? title;
                try {
                  canBack = await controller.canGoBack();
                  canForward = await controller.canGoForward();
                  title = await controller.getTitle();
                } catch (_) {}
                if (!mounted) return;
                setState(() {
                  if (!_isAiSearchPage) {
                    _currentUrl = nextUrl;
                    if (title?.trim().isNotEmpty == true) _currentTitle = title!;
                  }
                  _canGoBack = canBack;
                  _canGoForward = canForward;
                });
                if (!widget.isIncognito && !_isAiSearchPage) {
                  activityController.log(
                    ActivityKind.site,
                    _currentTitle.trim().isEmpty ? nextUrl : _currentTitle,
                    nextUrl,
                  );
                  unawaited(browserFaviconCache.fetchForUrl(nextUrl));
                }
                _updateTabState();
              },
              onLoadStop: (controller, url) async {
                _pullToRefreshController?.endRefreshing();
                bool back = false;
                bool forward = false;
                try {
                  back = await controller.canGoBack();
                  forward = await controller.canGoForward();
                } catch (_) {}

                final loadedUrl = _isAiSearchPage ? _currentUrl : (url?.toString() ?? _currentUrl);
                final wrapped = _OrbitWebViewController(controller);
                if (_isAiSearchPage) {
                  await _configureAiSearchPage(controller);
                  await _applyWebsiteAppearance(wrapped);
                } else {
                  await _applyWebsiteAppearance(wrapped);
                  if (adaptiveToolbarColorEnabled.value) {
                    unawaited(_refreshAdaptiveToolbarColor(wrapped));
                  }
                }
                if (!widget.isIncognito && !_isAiSearchPage) {
                  activityController.log(
                    ActivityKind.site,
                    _currentTitle.trim().isEmpty ? loadedUrl : _currentTitle,
                    loadedUrl,
                  );
                  unawaited(browserFaviconCache.fetchForUrl(loadedUrl));
                }

                if (!mounted) {
                  _signalFirstLoad();
                  return;
                }

                // A página é marcada como carregada ANTES da miniatura, que
                // pode demorar até 2s e não deve segurar a barra de progresso.
                setState(() {
                  _isLoading = false;
                  _progress = 1;
                  _showProgress = true;
                  _loadError = null;
                  _canGoBack = back;
                  _canGoForward = forward;
                  if (url != null && !_isAiSearchPage) _currentUrl = url.toString();
                });
                _updateTabState();
                _signalFirstLoad();
                _progressHideTimer?.cancel();
                _progressHideTimer = Timer(
                  const Duration(milliseconds: 260),
                  () {
                    if (!mounted) return;
                    setState(() {
                      _showProgress = false;
                      _progress = 0;
                    });
                  },
                );

                if (!_isAiSearchPage) unawaited(_maybeOfferTranslation());

                // A miniatura NÃO é mais capturada automaticamente aqui.
                // A única captura de screenshot do browser acontece dentro
                // de _openTabsGrid(), exatamente no momento em que o
                // utilizador está de facto a sair para a grelha de abas —
                // é aí, e só aí, que uma miniatura atualizada é necessária.
                // Capturar em todo onLoadStop (incluindo navegações internas
                // de SPA, âncoras e redirects que nunca chegam a ser vistas
                // na grelha) era o que produzia o flash visível ao tocar em
                // "Abas": o takeScreenshot() força um frame extra do
                // WebView mesmo quando ninguém vai ver o resultado dessa
                // captura automática.
              },
              onReceivedError: (controller, request, error) {
                _pullToRefreshController?.endRefreshing();
                if (request.isForMainFrame == true) {
                  _signalFirstLoad();
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _progress = 1;
                      _loadError = error.description;
                    });
                    _progressHideTimer?.cancel();
                    _progressHideTimer = Timer(
                      const Duration(milliseconds: 260),
                      () {
                        if (!mounted) return;
                        setState(() => _showProgress = false);
                      },
                    );
                  }
                }
              },
              onDownloadStartRequest: (controller, request) {
                if (!widget.isIncognito) {
                  downloadsController.register(
                    url: request.url.toString(),
                    filename: request.suggestedFilename,
                    mimeType: request.mimeType,
                  );
                }
                if (mounted && !widget.isIncognito) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(appText('download_received'))),
                  );
                }
              },
              onRenderProcessGone: (controller, detail) {
                _pullToRefreshController?.endRefreshing();
                _signalFirstLoad();
                if (!mounted) return;
                setState(() {
                  _renderProcessCrashed = true;
                  _isLoading = false;
                  _showProgress = false;
                  _loadError = 'O motor da página foi reiniciado.';
                });
              },
            ),
          ),
        if (_renderProcessCrashed || _loadError != null)
          _buildWebViewErrorOverlay(context, bg),
      ],
    );
  }

  Future<void> _configureAiSearchPage(InAppWebViewController controller) async {
    try {
      final uri = Uri.tryParse(_currentUrl);
      final query = uri?.queryParameters['q'] ?? '';
      final queryJson = jsonEncode(query);
      await controller.evaluateJavascript(source: '''(() => {
        const input = document.getElementById('messageInput');
        const send = document.getElementById('btnSend');
        if (!input || !send) return false;
        const initialQuery = $queryJson;
        if (initialQuery && !input.value) {
          input.value = initialQuery;
          input.dispatchEvent(new Event('input', { bubbles: true }));
        }
        const dispatch = () => {
          const value = input.value.trim();
          if (value && window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('browseItAiSearchSubmit', value);
          }
        };
        if (!send.dataset.browseitBound) {
          send.dataset.browseitBound = '1';
          send.addEventListener('click', dispatch, true);
          input.addEventListener('keydown', event => {
            if (event.key === 'Enter' && !event.shiftKey) dispatch();
          }, true);
        }
        return true;
      })();''');
    } catch (_) {}
  }

  Widget _buildWebViewErrorOverlay(BuildContext context, Color bg) {
    return Positioned.fill(
      child: ColoredBox(
        color: bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  _renderProcessCrashed ? AppIcons.clockCounterClockwise : AppIcons.wifiSlash,
                  size: 42,
                  color: mutedText(context),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError ?? appText('loading_error'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mainText(context)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retryPage,
                  child: Text(appText('retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quantos pixels lógicos a WebView é desenhada além da margem direita e
/// inferior reais do ecrã. O Stack pai corta o excesso, então o único
/// efeito visível é cobrir a fresta de 1px onde a fronteira entre a
/// PlatformView nativa e o Flutter deixava a cor de fundo aparecer. Se a
/// linha persistir no teu aparelho, sobe este valor para 3.0 ou 4.0.
const double _kWebViewOverscan = 2.0;

enum _OrbitMenuAction {
  back,
  forward,
  copyAddress,
  siteInfo,
  reload,
  openSearch,
  findInPage,
  newTab,
  bookmarks,
  settings,
  goHome,
  history,
  downloads,
  bookmark,
  translate,
  desktopSite,
  zoomIn,
  zoomOut,
  print,
  addToHomeScreen,
}

class _BrowserQuickAction extends StatelessWidget {
  const _BrowserQuickAction({required this.icon, required this.label, required this.onTap, this.enabled = true});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = mainText(context);
    final muted = mutedText(context);
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : .38,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pillColor(context),
                  shape: BoxShape.circle,
                ),
                child: AppSvgIcon(icon, size: 23, color: enabled ? foreground : muted),
              ),
              const SizedBox(height: 8),
              Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: enabled ? foreground : muted, fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BrowserSheetListItem extends StatelessWidget {
  const _BrowserSheetListItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              SizedBox(width: 42, child: AppSvgIcon(icon, size: 23, color: mainText(context))),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: mainText(context), fontSize: 14, fontWeight: FontWeight.w500))),
            ]),
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
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(.88), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, height: 1),
            ),
          ),
        ),
      );
}