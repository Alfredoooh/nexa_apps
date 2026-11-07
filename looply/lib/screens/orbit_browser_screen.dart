import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
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
import '../widgets/looply_dialog.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../widgets/phosphor_svg_icon.dart';

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

class _OrbitBrowserScreenState extends State<OrbitBrowserScreen> {
  _OrbitWebViewController? _controller;
  bool _isAiSearchPage = false;
  String? _aiPageHtml;
  Color? _siteToolbarColor;
  Brightness? _lastAppBrightness;
  PullToRefreshController? _pullToRefreshController;
  Timer? _progressHideTimer;
  Timer? _findDebounce;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  bool _isFindInPage = false;
  bool _isExpandingToSearch = false;

  bool _isLoading = true;
  bool _showProgress = true;
  double _progress = 0;
  late String _currentUrl;
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _renderProcessCrashed = false;
  String? _loadError;
  Key _webViewKey = UniqueKey();
  bool _tabsRequestInProgress = false;
  bool _firstLoadSignaled = false;

  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');
  bool _nativeDrawerRequestInProgress = false;

  Future<void> _openNativeDrawer() async {
    if (_nativeDrawerRequestInProgress) return;
    _nativeDrawerRequestInProgress = true;
    try {
      final selected = await _nativeUi.invokeMethod<String>('showNativeDrawer', <String, Object>{
        'items': <Map<String, Object>>[
          {'label': appText('home'), 'value': 'home'},
          {'label': appText('history'), 'value': 'history'},
          {'label': appText('downloads'), 'value': 'downloads'},
          {'label': appText('bookmarks'), 'value': 'bookmarks'},
          {'label': appText('settings'), 'value': 'settings'},
        ],
      });
      if (!mounted || selected == null) return;
      switch (selected) {
        case 'home': ShellTabRequest.instance.request(0); break;
        case 'history': Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const HistoryScreen())); break;
        case 'downloads': Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const DownloadsScreen())); break;
        case 'bookmarks': Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const BookmarksScreen())); break;
        case 'settings': Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SettingsScreen())); break;
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

    adBlockEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    navigationAcceleratorEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    forceDarkWebsitesEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    siteThemeFollowsAppEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    adaptiveToolbarColorEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    appLanguageController.addListener(_onRuntimeWebViewSettingsChanged);
    themeController.addListener(_onRuntimeWebViewSettingsChanged);
    themeController.pureDark.addListener(_onRuntimeWebViewSettingsChanged);
    BrowserPreconnectHints.setActive(widget.tabId, widget.isActive);

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
    _progressHideTimer?.cancel();
    _findDebounce?.cancel();
    _findController.dispose();
    _findFocusNode.dispose();
    adBlockEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    navigationAcceleratorEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    forceDarkWebsitesEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    siteThemeFollowsAppEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    adaptiveToolbarColorEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    appLanguageController.removeListener(_onRuntimeWebViewSettingsChanged);
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
      BrowserPreconnectHints.setActive(widget.tabId, widget.isActive);
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

  Color _contrastForeground(Color color) {
    final luminance = color.computeLuminance();
    return luminance > .48 ? const Color(0xFF111111) : Colors.white;
  }

  Future<void> _applyWebsiteAppearance(_OrbitWebViewController controller) async {
    if (!mounted) return;
    final appIsDark = Theme.of(context).brightness == Brightness.dark;
    final forceDark = forceDarkWebsitesEnabled.value && !_isAiSearchPage;
    // Os sites seguem o modo efetivo do BrowseIt; não consultam o tema do SO.
    final followsApp = siteThemeFollowsAppEnabled.value;
    try {
      await controller.setSettings(
        cacheEnabled: navigationAcceleratorEnabled.value,
        adBlockEnabled: adBlockEnabled.value,
        forceDark: forceDark,
        followAppTheme: followsApp,
        appIsDark: appIsDark,
      );
      final scheme = followsApp ? (appIsDark ? 'dark' : 'light') : 'normal';
      final needsCssDarkFallback = defaultTargetPlatform != TargetPlatform.android;
      final targetLanguage = appLanguageController.value.code == 'zh'
          ? 'zh-CN'
          : appLanguageController.value.code;
      final script = '''(() => {
        try {
          const root = document.documentElement;
          root.style.setProperty('color-scheme', '$scheme');
          root.dataset.appTheme = '$scheme';
          root.lang = '$targetLanguage';
          const uiTranslations = {
            pt:{placeholder:'Pergunte, busque ou crie qualquer coisa',noResults:'Sem resultados'},
            en:{placeholder:'Ask, search or create anything',noResults:'No results'},
            es:{placeholder:'Pregunta, busca o crea cualquier cosa',noResults:'Sin resultados'},
            fr:{placeholder:'Demandez, recherchez ou créez',noResults:'Aucun résultat'},
            de:{placeholder:'Fragen, suchen oder etwas erstellen',noResults:'Keine Ergebnisse'},
            it:{placeholder:'Chiedi, cerca o crea qualsiasi cosa',noResults:'Nessun risultato'},
            ar:{placeholder:'اسأل أو ابحث أو أنشئ أي شيء',noResults:'لا توجد نتائج'},
            zh:{placeholder:'提问、搜索或创建任何内容',noResults:'没有结果'},
            ja:{placeholder:'質問、検索、または何かを作成',noResults:'結果がありません'},
            ru:{placeholder:'Спросите, найдите или создайте что угодно',noResults:'Нет результатов'},
            hi:{placeholder:'कुछ भी पूछें, खोजें या बनाएँ',noResults:'कोई परिणाम नहीं'},
            tr:{placeholder:'Sorun, arayın veya herhangi bir şey oluşturun',noResults:'Sonuç yok'}
          };
          const uiText = uiTranslations['$targetLanguage'] || uiTranslations['${appLanguageController.value.code}'] || uiTranslations.pt;
          const aiInput = document.getElementById('messageInput');
          if (aiInput) aiInput.placeholder = uiText.placeholder;
          const emptyText = document.querySelector('#emptyState p');
          if (emptyText) emptyText.textContent = uiText.noResults;
          let meta = document.querySelector('meta[name="color-scheme"]');
          if (!meta) { meta = document.createElement('meta'); meta.name = 'color-scheme'; document.head?.appendChild(meta); }
          meta.content = '$scheme';
          const id = 'browseit-forced-dark-style';
          let style = document.getElementById(id);
          if ($forceDark && $needsCssDarkFallback) {
            if (!style) { style = document.createElement('style'); style.id = id; document.head?.appendChild(style); }
            style.textContent = 'html{background:#111!important;filter:invert(1) hue-rotate(180deg)!important} img,video,canvas,picture,svg{filter:invert(1) hue-rotate(180deg)!important}';
          } else if (style) { style.remove(); }
          window.__browseitTargetLanguage = '$targetLanguage';
          window.__browseitApplyTranslation = () => {
            try {
              const select = document.querySelector('.goog-te-combo');
              const target = window.__browseitTargetLanguage;
              if (select && target && select.value !== target) {
                select.value = target;
                select.dispatchEvent(new Event('change', { bubbles:true }));
              }
            } catch (_) {}
          };
          if (!window.__browseitTranslateStarted) {
            window.__browseitTranslateStarted = true;
            window.googleTranslateElementInit = () => {
              try {
                new google.translate.TranslateElement({pageLanguage:'auto', includedLanguages:'pt,en,es,fr,de,it,ar,zh-CN,ja,ru,hi,tr', autoDisplay:false}, 'browseit-translate-root');
                setTimeout(() => window.__browseitApplyTranslation?.(), 650);
                setTimeout(() => window.__browseitApplyTranslation?.(), 1500);
              } catch (_) {}
            };
            const host = document.createElement('div');
            host.id = 'browseit-translate-root';
            host.style.cssText = 'position:fixed;left:-10000px;top:-10000px;width:1px;height:1px;overflow:hidden';
            document.body?.appendChild(host);
            const css = document.createElement('style');
            css.id = 'browseit-translate-css';
            css.textContent = '.goog-te-banner-frame,.goog-te-balloon-frame,#goog-gt-tt{display:none!important}body{top:0!important}.skiptranslate{display:none!important}';
            document.head?.appendChild(css);
            const translateScript = document.createElement('script');
            translateScript.id = 'browseit-google-translate';
            translateScript.src = 'https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';
            translateScript.async = true;
            document.head?.appendChild(translateScript);
          } else {
            setTimeout(() => window.__browseitApplyTranslation?.(), 300);
            setTimeout(() => window.__browseitApplyTranslation?.(), 900);
          }
        } catch (_) {}
      })();''';
      await controller.evaluateJavascript(script);
    } catch (_) {}
  }

  Future<void> _refreshAdaptiveToolbarColor(_OrbitWebViewController controller) async {
    if (!adaptiveToolbarColorEnabled.value || _isAiSearchPage) {
      if (mounted && _siteToolbarColor != null) setState(() => _siteToolbarColor = null);
      return;
    }
    final raw = await controller.getPageToolbarColor();
    final color = _parseCssColor(raw);
    if (!mounted || color == null) return;
    if (_siteToolbarColor != color) setState(() => _siteToolbarColor = color);
  }

  void _onRuntimeWebViewSettingsChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    unawaited(_applyWebsiteAppearance(controller));
    if (adaptiveToolbarColorEnabled.value) unawaited(_refreshAdaptiveToolbarColor(controller));
    if (mounted) setState(() {});
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
      return await controller
          .takeScreenshot()
          .timeout(const Duration(milliseconds: 900));
    } catch (_) {
      return null;
    }
  }

  /// Captura + redução da miniatura. Corre DEPOIS de a página ser marcada
  /// como carregada, para não atrasar a barra de progresso nem o first load.
  Future<Uint8List?> _captureThumbnail(InAppWebViewController controller) async {
    try {
      final raw = await controller
          .takeScreenshot()
          .timeout(const Duration(seconds: 2));
      if (raw == null) return null;
      return await _downscaleScreenshot(raw, targetWidth: 720);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _downscaleScreenshot(Uint8List bytes, {required int targetWidth}) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return bytes.length <= 165000 ? bytes : null;
    } finally {
      image?.dispose();
      codec?.dispose();
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
      // Captura apenas a área real da WebView. O Rect de origem aponta para
      // esta mesma área, mantendo a proporção e o alinhamento do Container Transform.
      final freshScreenshot = await _captureScreenshot();
      final oldScreenshot = tabsController.getTab(widget.tabId)?.thumbnail;
      _updateTabState(screenshot: freshScreenshot ?? oldScreenshot);

      if (!mounted) return;
      final viewportRect = _rectInRootOverlay(widget.viewportKey);
      ShellTabRequest.instance.requestCloseBrowser(
        tabId: widget.tabId,
        screenshot: freshScreenshot ?? oldScreenshot,
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
      FadePageRoute<void>(builder: (_) => const SearchScreen()),
    );

    if (!mounted) return;
    setState(() => _isExpandingToSearch = false);
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
        final newTab = tabsController.createBrowserTab('https://www.google.com');
        ShellTabRequest.instance.requestBrowser(newTab.id);
        break;
      case _OrbitMenuAction.bookmarks:
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const BookmarksScreen()));
        break;
      case _OrbitMenuAction.settings:
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SettingsScreen()));
        break;
      case _OrbitMenuAction.goHome:
        ShellTabRequest.instance.request(0);
        break;
      case _OrbitMenuAction.history:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const HistoryScreen()),
        );
        break;
      case _OrbitMenuAction.downloads:
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const DownloadsScreen()),
        );
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
    }
  }

  void _showBrowserOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = panelColor(context);
    final text = mainText(context);
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
                  child: Row(
                    children: [
                      _BrowserQuickAction(icon: PhosphorIcons.arrowLeft, label: appText('go_back'), enabled: _canGoBack, onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.back)),
                      _BrowserQuickAction(icon: PhosphorIcons.arrowRight, label: appText('go_forward'), enabled: _canGoForward, onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.forward)),
                      _BrowserQuickAction(icon: PhosphorIcons.plus, label: appText('new_tab'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.newTab)),
                      _BrowserQuickAction(icon: PhosphorIcons.bookmarksSimple, label: appText('bookmarks'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.bookmarks)),
                      _BrowserQuickAction(icon: PhosphorIcons.gear, label: appText('settings'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.settings)),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: muted.withOpacity(.18), indent: 22, endIndent: 22),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                    children: [
                      _BrowserSheetListItem(icon: PhosphorIcons.clockCounterClockwise, label: appText('history'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.history)),
                      _BrowserSheetListItem(icon: PhosphorIcons.downloadSimple, label: appText('downloads'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.downloads)),
                      _BrowserSheetListItem(icon: PhosphorIcons.magnifyingGlass, label: appText('find_in_page'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.findInPage)),
                      _BrowserSheetListItem(icon: PhosphorIcons.bookmarkSimple, label: appText('add_bookmark'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.bookmark)),
                      Divider(height: 18, color: muted.withOpacity(.18), indent: 12, endIndent: 12),
                      _BrowserSheetListItem(icon: PhosphorIcons.arrowClockwise, label: appText('reload_page'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.reload)),
                      _BrowserSheetListItem(icon: PhosphorIcons.copy, label: appText('copy_address'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.copyAddress)),
                      _BrowserSheetListItem(icon: PhosphorIcons.info, label: appText('site_info'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.siteInfo)),
                      _BrowserSheetListItem(icon: PhosphorIcons.house, label: appText('home_page'), onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.goHome)),
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
      icon: PhosphorIcons.info,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_currentTitle.isEmpty ? host : _currentTitle, style: TextStyle(color: mainText(context), fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          SelectableText(_currentUrl, style: TextStyle(color: mutedText(context), fontSize: 13)),
        ],
      ),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('close'), value: true),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final useAdaptiveToolbar = !_isAiSearchPage && adaptiveToolbarColorEnabled.value && _siteToolbarColor != null;
    final toolbarColor = _isAiSearchPage ? bg : (useAdaptiveToolbar ? _siteToolbarColor! : bg);
    final toolbarText = useAdaptiveToolbar ? _contrastForeground(toolbarColor) : text;
    final parsedUri = Uri.tryParse(_currentUrl);
    final fallbackTitle = _isAiSearchPage
        ? appText('research_ai')
        : (parsedUri?.host.isNotEmpty == true ? parsedUri!.host : 'Orbit Browser');

    return PopScope<void>(
      // Esta tela só existe para a aba ativa; por isso apenas ela intercepta
      // o botão Voltar e não há WebViews Offstage a interferir na navegação.
      canPop: !widget.isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !widget.isActive) return;
        await _handleSystemBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (toolbarColor.computeLuminance() > .48 ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: toolbarColor.computeLuminance() > .48 ? Brightness.dark : Brightness.light,
          statusBarBrightness: toolbarColor.computeLuminance() > .48 ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: bg,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: toolbarColor,
            foregroundColor: toolbarText,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: _isAiSearchPage && !_isFindInPage,
            leadingWidth: _isAiSearchPage ? 50 : null,
            leading: AnimatedOpacity(
              opacity: _isExpandingToSearch ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: _isExpandingToSearch,
                child: _isAiSearchPage
                    ? _BrowserToolbarCircleButton(
                        tooltip: appText('home'),
                        icon: PhosphorIcons.list,
                        foreground: toolbarText,
                        background: pillColor(context),
                        onPressed: _openNativeDrawer,
                      )
                    : IconButton(
                        tooltip: appText('home'),
                        icon: PhosphorSvgIcon(PhosphorIcons.house, color: toolbarText),
                        onPressed: () => ShellTabRequest.instance.request(0),
                      ),
              ),
            ),
            titleSpacing: 0,
            title: _isFindInPage
                ? Row(
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
                        icon: PhosphorSvgIcon(PhosphorIcons.caretUp, color: toolbarText),
                      ),
                      IconButton(
                        tooltip: appText('next_result'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _moveFindResult(true),
                        icon: PhosphorSvgIcon(PhosphorIcons.caretDown, color: toolbarText),
                      ),
                      IconButton(
                        tooltip: appText('close_search'),
                        visualDensity: VisualDensity.compact,
                        onPressed: _exitFindInPage,
                        icon: PhosphorSvgIcon(PhosphorIcons.x, color: toolbarText),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Largura disponível no title quando leading e actions
                      // ainda estão visíveis (estado "fechado").
                      final collapsedWidth = constraints.maxWidth;
                      // Ao expandir, o pill cresce até tomar o espaço extra
                      // que leading (56) e actions (~96) ocupavam, imitando
                      // a largura do input da tela de pesquisa.
                      const leadingWidth = 56.0;
                      const actionsWidth = 96.0;
                      final expandedWidth =
                          collapsedWidth + leadingWidth + actionsWidth;

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: _isExpandingToSearch ? 1 : 0,
                        ),
                        duration: const Duration(milliseconds: 190),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) {
                          final width =
                              collapsedWidth + (expandedWidth - collapsedWidth) * t;
                          return SizedBox(
                            width: _isAiSearchPage ? null : width,
                            child: child,
                          );
                        },
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _isAiSearchPage ? null : _openSearchWithExpandAnimation,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _isAiSearchPage ? bg : pillColor(context),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisSize: _isAiSearchPage ? MainAxisSize.min : MainAxisSize.max,
                              children: [
                                if (!_isAiSearchPage) ...[
                                  PhosphorSvgIcon(PhosphorIcons.magnifyingGlass, color: muted, size: 19),
                                  const SizedBox(width: 9),
                                ],
                                _isAiSearchPage
                                    ? Text(_currentTitle.isNotEmpty ? _currentTitle : fallbackTitle,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: toolbarText, fontSize: 14, fontWeight: FontWeight.w600))
                                    : Expanded(child: Text(
                                        _currentTitle.isNotEmpty ? _currentTitle : fallbackTitle,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: toolbarText, fontSize: 14, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            actions: _isFindInPage
                ? const []
                : [
                    AnimatedOpacity(
                      opacity: _isExpandingToSearch ? 0 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: IgnorePointer(
                        ignoring: _isExpandingToSearch,
                        child: _isAiSearchPage
                            ? Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _BrowserToolbarGroupedButtons(
                                  foreground: toolbarText,
                                  background: pillColor(context),
                                  tabsTooltip: appText('tabs'),
                                  tabsChild: AnimatedBuilder(
                                    animation: tabsController,
                                    builder: (context, _) => _TabsCountIcon(count: tabsController.count, color: toolbarText),
                                  ),
                                  onTabsPressed: _openTabsGrid,
                                  secondaryTooltip: appText('new_chat'),
                                  secondaryIcon: PhosphorIcons.plus,
                                  onSecondaryPressed: _restartAiChat,
                                ),
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
                                    icon: PhosphorSvgIcon(PhosphorIcons.dotsThreeVertical, color: toolbarText),
                                    onPressed: _showBrowserOptionsSheet,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 3,
                child: AnimatedOpacity(
                  opacity: _showProgress ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: TweenAnimationBuilder<double>(
                    // Sem um begin fixo: cada atualização parte do valor
                    // atualmente pintado, evitando saltar novamente para zero
                    // a cada evento de progresso enviado pelo WebView.
                    tween: Tween<double>(end: _progress.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedProgress, _) =>
                        LinearProgressIndicator(
                      value: animatedProgress,
                      minHeight: 3,
                      color: accentColor(context),
                      backgroundColor: muted.withOpacity(.13),
                      borderRadius: BorderRadius.zero,
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

  Widget _buildWebView(BuildContext context) => _buildPluginWebView(context);

  Widget _buildPluginWebView(BuildContext context) {
    final bg = pageBg(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        if (!_renderProcessCrashed && (!_isAiSearchPage || _aiPageHtml != null))
          // O _PixelSnappedViewport alinha a WebView à grelha de pixels
          // físicos (origem e tamanho). É isto que elimina as linhas brancas
          // à direita/em baixo e o leve desfoque causado por posições
          // fracionárias, exatamente como os browsers nativos fazem.
          _PixelSnappedViewport(
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

                // Fundo opaco: evita composição com alpha sobre o Flutter.
                transparentBackground: false,

                cacheEnabled: navigationAcceleratorEnabled.value,
                cacheMode: navigationAcceleratorEnabled.value
                    ? CacheMode.LOAD_DEFAULT
                    : CacheMode.LOAD_NO_CACHE,
                algorithmicDarkeningAllowed: !_isAiSearchPage &&
                    (forceDarkWebsitesEnabled.value ||
                        (siteThemeFollowsAppEnabled.value &&
                            Theme.of(context).brightness == Brightness.dark)),
                offscreenPreRaster: true,
                hardwareAcceleration: true,

                // PRINCIPAL CORREÇÃO DO DESFOQUE (Android): Hybrid Composition
                // desenha a WebView nativa no tamanho real, sem a textura
                // reescalada do Virtual Display.
                useHybridComposition: true,

                // Não deixa a escala de fonte do sistema alterar o layout
                // das páginas (o Chrome também ignora isto no conteúdo).
                textZoom: 100,
                minimumFontSize: 1,

                // Viewport e zoom iguais aos de um browser real.
                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                preferredContentMode: UserPreferredContentMode.MOBILE,

                // Scrollbars e glow de overscroll nativos desenham linhas
                // nas bordas direita/inferior. Os browsers móveis escondem-nos.
                verticalScrollBarEnabled: false,
                horizontalScrollBarEnabled: false,
                overScrollMode: OverScrollMode.NEVER,

                // Compatibilidade com sites reais.
                mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                thirdPartyCookiesEnabled: true,

                // iOS
                enableViewportScale: true,
                allowsInlineMediaPlayback: true,
                allowsBackForwardNavigationGestures: true,

                isInspectable: kDebugMode,

                incognito: widget.isIncognito,
                useOnDownloadStart: true,
                useShouldOverrideUrlLoading: true,
                contentBlockers: buildPlatformAdBlockers(enabled: adBlockEnabled.value),
                supportMultipleWindows: true,
                javaScriptCanOpenWindowsAutomatically: false,
              ),
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
                BrowserPreconnectHints.attach(widget.tabId, orbitController.evaluateJavascript);
                if (_isAiSearchPage) {
                  controller.addJavaScriptHandler(
                    handlerName: 'browseItAiSearchSubmit',
                    callback: (arguments) {
                      final query = arguments.isNotEmpty ? arguments.first.toString().trim() : '';
                      if (query.isEmpty) return false;
                      searchHistoryController.add(query);
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
                setState(() {
                  if (!_isAiSearchPage) _siteToolbarColor = null;
                  _isLoading = true;
                  _showProgress = true;
                  _progress = 0;
                  _loadError = null;
                  if (nextUrl != null && !_isAiSearchPage) _currentUrl = nextUrl;
                });
                _updateTabState();
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

                // Miniatura em segundo plano, a 720px de largura.
                final screenshot = await _captureThumbnail(controller);
                if (!mounted || screenshot == null) return;
                _updateTabState(screenshot: screenshot);
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
                PhosphorSvgIcon(
                  _renderProcessCrashed ? PhosphorIcons.arrowClockwise : PhosphorIcons.wifiSlash,
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

/// Alinha o filho (a WebView) à grelha de pixels físicos do ecrã.
///
/// Problema: AppBar + barra de progresso + status bar podem deixar a origem
/// da WebView num pixel físico fracionário (ex.: 157.5px em dpr 2.8125) e o
/// tamanho lógico multiplicado pelo devicePixelRatio também não é inteiro.
/// A PlatformView é então arredondada para baixo: sobra 1px de fundo à
/// direita/em baixo (linha branca) e o conteúdo é reamostrado (desfoque).
///
/// Solução: mede a origem real no ecrã, recua o filho para o pixel inteiro
/// anterior e arredonda o tamanho PARA CIMA em pixels físicos. O filho sangra
/// no máximo 1px para fora, onde não há nada a tapar.
class _PixelSnappedViewport extends StatefulWidget {
  const _PixelSnappedViewport({required this.child});

  final Widget child;

  @override
  State<_PixelSnappedViewport> createState() => _PixelSnappedViewportState();
}

class _PixelSnappedViewportState extends State<_PixelSnappedViewport>
    with WidgetsBindingObserver {
  /// Deslocamento em pixels lógicos (sempre <= 0) para cair no pixel inteiro.
  Offset _shift = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _scheduleMeasure();

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  double _fraction(double physical) {
    final nearest = physical.roundToDouble();
    // Tolera ruído de ponto flutuante (146.99999 / 147.00001).
    if ((physical - nearest).abs() < 0.02) return 0;
    return physical - physical.floorToDouble();
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final origin = box.localToGlobal(Offset.zero);
    final next = Offset(
      -_fraction(origin.dx * dpr) / dpr,
      -_fraction(origin.dy * dpr) / dpr,
    );
    if ((next - _shift).distance > 0.0005) {
      setState(() => _shift = next);
    }
  }

  /// Arredonda um tamanho lógico PARA CIMA para um número inteiro de pixels
  /// físicos, devolvendo o valor em pixels lógicos.
  double _snapUp(double logical, double dpr) =>
      ((logical * dpr) - 0.001).ceilToDouble() / dpr;

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _snapUp(constraints.maxWidth - _shift.dx, dpr);
        final height = _snapUp(constraints.maxHeight - _shift.dy, dpr);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _shift.dx,
              top: _shift.dy,
              width: width,
              height: height,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}

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
}

class _BrowserToolbarGroupedButtons extends StatelessWidget {
  const _BrowserToolbarGroupedButtons({required this.foreground, required this.background,
    required this.tabsTooltip, required this.tabsChild, required this.onTabsPressed,
    required this.secondaryTooltip, required this.secondaryIcon, required this.onSecondaryPressed});
  final Color foreground, background;
  final String tabsTooltip, secondaryTooltip;
  final Widget tabsChild;
  final VoidCallback onTabsPressed, onSecondaryPressed;
  final IconData secondaryIcon;
  @override
  Widget build(BuildContext context) => Material(
    color: background, borderRadius: BorderRadius.circular(100), clipBehavior: Clip.antiAlias,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Tooltip(message: tabsTooltip, child: InkWell(onTap: onTabsPressed,
        child: SizedBox(width: 40, height: 40, child: Center(child: tabsChild)))),
      Tooltip(message: secondaryTooltip, child: InkWell(onTap: onSecondaryPressed,
        child: SizedBox(width: 40, height: 40, child: Center(
          child: PhosphorSvgIcon(secondaryIcon, size: 20, color: foreground))))),
    ]),
  );
}

class _BrowserToolbarCircleButton extends StatelessWidget {
  const _BrowserToolbarCircleButton({
    required this.tooltip,
    required this.foreground,
    required this.background,
    required this.onPressed,
    this.icon,
    this.customChild,
  });

  final String tooltip;
  final IconData? icon;
  final Widget? customChild;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: customChild ?? PhosphorSvgIcon(icon ?? PhosphorIcons.circle, size: 21, color: foreground),
                ),
              ),
            ),
          ),
        ),
      );
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
                child: PhosphorSvgIcon(icon, size: 23, color: enabled ? foreground : muted),
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
              SizedBox(width: 42, child: PhosphorSvgIcon(icon, size: 23, color: mainText(context))),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: mainText(context), fontSize: 14, fontWeight: FontWeight.w500))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OrbitShortcut extends StatelessWidget {
  const _OrbitShortcut({
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = mainText(context);
    final circle = isDark
        ? const Color(0xFF20242C)
        : const Color(0xFFE4E7EC);
    return SizedBox(
      width: 45,
      height: 45,
      child: IconButton(
        tooltip: null,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: circle,
          foregroundColor: enabled ? foreground : foreground.withOpacity(.35),
          fixedSize: const Size(45, 45),
          shape: const CircleBorder(),
        ),
        onPressed: enabled ? onPressed : null,
        icon: PhosphorSvgIcon(icon, size: 22),
      ),
    );
  }
}

class _OrbitMenuItem extends StatelessWidget {
  const _OrbitMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PhosphorSvgIcon(icon, size: 20, color: mainText(context)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: mainText(context), fontSize: 14),
          ),
        ),
      ],
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