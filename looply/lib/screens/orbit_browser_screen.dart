import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../browser_security.dart';
import '../browser_library.dart';
import '../shell/shell_tab_request.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';

/// Adaptador único para o WebView Android nativo e para o fallback das
/// restantes plataformas. A UI do Orbit continua integralmente em Flutter.
class _OrbitWebViewController {
  _OrbitWebViewController._({this.plugin, this.native});

  factory _OrbitWebViewController.plugin(InAppWebViewController controller) =>
      _OrbitWebViewController._(plugin: controller);

  factory _OrbitWebViewController.native(MethodChannel channel) =>
      _OrbitWebViewController._(native: channel);

  final InAppWebViewController? plugin;
  final MethodChannel? native;

  Future<bool> canGoBack() async => native != null
      ? (await native!.invokeMethod<bool>('canGoBack') ?? false)
      : (await plugin!.canGoBack());

  Future<bool> canGoForward() async => native != null
      ? (await native!.invokeMethod<bool>('canGoForward') ?? false)
      : (await plugin!.canGoForward());

  Future<String?> getUrl() async => native != null
      ? native!.invokeMethod<String>('getUrl')
      : (await plugin!.getUrl())?.toString();

  Future<String?> getTitle() async => native != null
      ? native!.invokeMethod<String>('getTitle')
      : plugin!.getTitle();

  Future<Uint8List?> takeScreenshot() async => native != null
      ? native!.invokeMethod<Uint8List>('takeScreenshot')
      : plugin!.takeScreenshot();

  Future<void> goBack() async {
    if (native != null) {
      await native!.invokeMethod<void>('goBack');
    } else {
      await plugin!.goBack();
    }
  }

  Future<void> goForward() async {
    if (native != null) {
      await native!.invokeMethod<void>('goForward');
    } else {
      await plugin!.goForward();
    }
  }

  Future<void> reload() async {
    if (native != null) {
      await native!.invokeMethod<void>('reload');
    } else {
      await plugin!.reload();
    }
  }

  Future<void> clearMatches() async {
    if (native != null) {
      await native!.invokeMethod<void>('clearMatches');
    } else {
      await plugin!.clearMatches();
    }
  }

  Future<void> findAll(String query) async {
    if (native != null) {
      await native!.invokeMethod<void>('findAll', <String, Object>{'query': query});
    } else {
      await plugin!.findAllAsync(find: query);
    }
  }

  Future<void> findNext(bool forward) async {
    if (native != null) {
      await native!.invokeMethod<void>('findNext', <String, Object>{'forward': forward});
    } else {
      await plugin!.findNext(forward: forward);
    }
  }

  Future<void> evaluateJavascript(String source) async {
    if (native != null) {
      await native!.invokeMethod<dynamic>(
        'evaluateJavascript',
        <String, Object>{'source': source},
      );
    } else {
      await plugin!.evaluateJavascript(source: source);
    }
  }

  Future<void> setSettings({
    required bool cacheEnabled,
    required bool adBlockEnabled,
  }) async {
    if (native != null) {
      await native!.invokeMethod<void>('setSettings', <String, Object>{
        'cacheEnabled': cacheEnabled,
        'adBlockEnabled': adBlockEnabled,
      });
    } else {
      await plugin!.setSettings(
        settings: InAppWebViewSettings(
          cacheEnabled: cacheEnabled,
          cacheMode: cacheEnabled ? CacheMode.LOAD_DEFAULT : CacheMode.LOAD_NO_CACHE,
          contentBlockers: buildPlatformAdBlockers(enabled: adBlockEnabled),
        ),
      );
    }
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
  MethodChannel? _nativeWebViewChannel;
  PullToRefreshController? _pullToRefreshController;
  Timer? _progressHideTimer;
  Timer? _findDebounce;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  bool _isFindInPage = false;

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

  @override
  void initState() {
    super.initState();
    final existingTab = tabsController.getTab(widget.tabId);
    _currentUrl = existingTab != null && existingTab.url.isNotEmpty
        ? existingTab.url
        : widget.initialUrl;
    _currentTitle = existingTab?.title ?? '';
    _canGoBack = existingTab?.canGoBack ?? false;
    _canGoForward = existingTab?.canGoForward ?? false;
    // Quando já existe miniatura, a página tem histórico de carregamento;
    // evita-se apresentar um indicador de carregamento falso ao selecioná-la.
    _isLoading = existingTab?.thumbnail == null;
    _showProgress = _isLoading;

    adBlockEnabled.addListener(_onRuntimeWebViewSettingsChanged);
    navigationAcceleratorEnabled.addListener(_onRuntimeWebViewSettingsChanged);
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
  void dispose() {
    _progressHideTimer?.cancel();
    _findDebounce?.cancel();
    _findController.dispose();
    _findFocusNode.dispose();
    adBlockEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    navigationAcceleratorEnabled.removeListener(_onRuntimeWebViewSettingsChanged);
    BrowserPreconnectHints.detach(widget.tabId);
    _nativeWebViewChannel?.setMethodCallHandler(null);
    _nativeWebViewChannel = null;
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

  void _onRuntimeWebViewSettingsChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    unawaited(_applyRuntimeWebViewSettings(controller));
  }

  Future<void> _applyRuntimeWebViewSettings(
    _OrbitWebViewController controller,
  ) async {
    try {
      await controller.setSettings(
        cacheEnabled: navigationAcceleratorEnabled.value,
        adBlockEnabled: adBlockEnabled.value,
      );
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
        if (liveUrl != null) _currentUrl = liveUrl.toString();
        if (liveTitle?.trim().isNotEmpty == true) _currentTitle = liveTitle!;
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
            const SnackBar(
              content: Text('Endereço copiado.'),
              duration: Duration(seconds: 2),
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
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const SearchScreen()),
        );
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
              const SnackBar(content: Text('Esta página já está nos marcadores.')),
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
              const SnackBar(content: Text('Marcador guardado.')),
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
                      _BrowserQuickAction(icon: Symbols.arrow_back_rounded, label: 'Retroceder', enabled: _canGoBack, onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.back)),
                      _BrowserQuickAction(icon: Symbols.arrow_forward_rounded, label: 'Avançar', enabled: _canGoForward, onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.forward)),
                      _BrowserQuickAction(icon: Symbols.add_rounded, label: 'Novo separador', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.newTab)),
                      _BrowserQuickAction(icon: Symbols.bookmarks_rounded, label: 'Marcadores', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.bookmarks)),
                      _BrowserQuickAction(icon: Symbols.settings_rounded, label: 'Definições', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.settings)),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: muted.withOpacity(.18), indent: 22, endIndent: 22),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                    children: [
                      _BrowserSheetListItem(icon: Symbols.history_rounded, label: 'Histórico', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.history)),
                      _BrowserSheetListItem(icon: Symbols.download_rounded, label: 'Transferências', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.downloads)),
                      _BrowserSheetListItem(icon: Symbols.search_rounded, label: 'Pesquisar na página', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.findInPage)),
                      _BrowserSheetListItem(icon: Symbols.bookmark_add_rounded, label: 'Adicionar marcador', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.bookmark)),
                      Divider(height: 18, color: muted.withOpacity(.18), indent: 12, endIndent: 12),
                      _BrowserSheetListItem(icon: Symbols.refresh_rounded, label: 'Atualizar página', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.reload)),
                      _BrowserSheetListItem(icon: Symbols.content_copy_rounded, label: 'Copiar endereço', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.copyAddress)),
                      _BrowserSheetListItem(icon: Icons.info_outline_rounded, label: 'Informações do site', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.siteInfo)),
                      _BrowserSheetListItem(icon: Symbols.home_rounded, label: 'Página inicial', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.goHome)),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: pillColor(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        title: Text(
          'Informações do site',
          style: TextStyle(color: mainText(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTitle.isEmpty ? host : _currentTitle,
              style: TextStyle(
                color: mainText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            SelectableText(
              _currentUrl,
              style: TextStyle(color: mutedText(context), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final parsedUri = Uri.tryParse(_currentUrl);
    final fallbackTitle = parsedUri?.host.isNotEmpty == true
        ? parsedUri!.host
        : 'Orbit Browser';

    return PopScope<void>(
      // Esta tela só existe para a aba ativa; por isso apenas ela intercepta
      // o botão Voltar e não há WebViews Offstage a interferir na navegação.
      canPop: !widget.isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !widget.isActive) return;
        await _handleSystemBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
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
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Início',
              icon: Icon(Symbols.home_rounded, color: text),
              onPressed: () => ShellTabRequest.instance.request(0),
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
                          style: TextStyle(color: text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar na página',
                            hintStyle: TextStyle(color: muted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Resultado anterior',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _moveFindResult(false),
                        icon: Icon(Symbols.keyboard_arrow_up_rounded, color: text),
                      ),
                      IconButton(
                        tooltip: 'Próximo resultado',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _moveFindResult(true),
                        icon: Icon(Symbols.keyboard_arrow_down_rounded, color: text),
                      ),
                      IconButton(
                        tooltip: 'Fechar pesquisa',
                        visualDensity: VisualDensity.compact,
                        onPressed: _exitFindInPage,
                        icon: Icon(Symbols.close_rounded, color: text),
                      ),
                    ],
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: pillColor(context),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Icon(Symbols.search_rounded, color: muted, size: 19),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _currentTitle.isNotEmpty ? _currentTitle : fallbackTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            actions: _isFindInPage
                ? const []
                : [
                    AnimatedBuilder(
                      animation: tabsController,
                      builder: (context, _) => IconButton(
                        tooltip: 'Abas',
                        icon: _TabsCountIcon(count: tabsController.count, color: text),
                        onPressed: _openTabsGrid,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mais opções',
                      icon: Icon(Symbols.more_vert_rounded, color: text),
                      onPressed: _showBrowserOptionsSheet,
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

  Widget _buildWebView(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _buildAndroidNativeWebView(context);
    }
    return _buildPluginWebView(context);
  }

  Widget _buildAndroidNativeWebView(BuildContext context) {
    final bg = pageBg(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        if (!_renderProcessCrashed)
          AndroidView(
            key: _webViewKey,
            viewType: 'looply/orbit_native_webview',
            layoutDirection: TextDirection.ltr,
            creationParams: <String, Object>{
              'isIncognito': widget.isIncognito,
              'cacheEnabled': navigationAcceleratorEnabled.value,
              'adBlockEnabled': adBlockEnabled.value,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onNativePlatformViewCreated,
          ),
        if (_renderProcessCrashed || _loadError != null)
          _buildWebViewErrorOverlay(context, bg),
      ],
    );
  }

  Future<void> _onNativePlatformViewCreated(int viewId) async {
    if (!mounted) return;
    final channel = MethodChannel('looply/orbit_webview_$viewId');
    _nativeWebViewChannel = channel;
    channel.setMethodCallHandler(_handleNativeWebViewCall);
    final controller = _OrbitWebViewController.native(channel);
    _controller = controller;
    BrowserPreconnectHints.attach(widget.tabId, controller.evaluateJavascript);

    try {
      await channel.invokeMethod<bool>('configure', <String, Object>{
        'url': _currentUrl,
        'cacheEnabled': navigationAcceleratorEnabled.value,
        'adBlockEnabled': adBlockEnabled.value,
      });
      final ready = widget.browserReadyCompleter;
      if (ready != null && !ready.isCompleted) ready.complete();
      unawaited(_refreshNavigationState());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Não foi possível iniciar o WebView nativo do Android.';
        _isLoading = false;
        _showProgress = false;
      });
      _signalFirstLoad();
    }
  }

  Future<dynamic> _handleNativeWebViewCall(MethodCall call) async {
    if (!mounted || call.method != 'event') return null;
    final event = call.arguments;
    if (event is! Map) return null;
    final name = event['name']?.toString() ?? '';
    final rawArguments = event['arguments'];
    final args = rawArguments is Map ? rawArguments : const <Object?, Object?>{};

    switch (name) {
      case 'onLoadStart':
        _progressHideTimer?.cancel();
        setState(() {
          _isLoading = true;
          _showProgress = true;
          _progress = 0;
          _loadError = null;
          final url = args['url']?.toString();
          if (url != null) _currentUrl = url;
        });
        _updateTabState();
        break;
      case 'onProgressChanged':
        final progress = (args['progress'] as num?)?.toInt() ?? 0;
        _progressHideTimer?.cancel();
        setState(() {
          _showProgress = true;
          _progress = (progress / 100).clamp(0.0, 1.0);
          if (progress < 100) _isLoading = true;
        });
        break;
      case 'onTitleChanged':
        _currentTitle = args['title']?.toString() ?? '';
        _updateTabState();
        setState(() {});
        break;
      case 'onUpdateVisitedHistory':
        final url = args['url']?.toString();
        if (url == null || url.isEmpty) break;
        setState(() {
          _currentUrl = url;
          _canGoBack = args['canGoBack'] as bool? ?? _canGoBack;
          _canGoForward = args['canGoForward'] as bool? ?? _canGoForward;
          final title = args['title']?.toString();
          if (title != null && title.trim().isNotEmpty) _currentTitle = title;
        });
        if (!widget.isIncognito) {
          activityController.log(
            ActivityKind.site,
            _currentTitle.trim().isEmpty ? url : _currentTitle,
            url,
          );
          unawaited(browserFaviconCache.fetchForUrl(url));
        }
        _updateTabState();
        break;
      case 'onLoadStop':
        final url = args['url']?.toString() ?? _currentUrl;
        bool back = false;
        bool forward = false;
        Uint8List? screenshot;
        try {
          final controller = _controller;
          if (controller != null) {
            back = await controller.canGoBack();
            forward = await controller.canGoForward();
            screenshot = await controller
                .takeScreenshot()
                .timeout(const Duration(seconds: 2));
          }
        } catch (_) {}
        if (screenshot != null) {
          screenshot = await _downscaleScreenshot(screenshot, targetWidth: 420);
        }
        if (!widget.isIncognito) {
          activityController.log(
            ActivityKind.site,
            _currentTitle.trim().isEmpty ? url : _currentTitle,
            url,
          );
          unawaited(browserFaviconCache.fetchForUrl(url));
        }
        if (!mounted) {
          _signalFirstLoad();
          break;
        }
        setState(() {
          _isLoading = false;
          _progress = 1;
          _showProgress = true;
          _loadError = null;
          _canGoBack = back;
          _canGoForward = forward;
          _currentUrl = url;
        });
        _updateTabState(screenshot: screenshot);
        _signalFirstLoad();
        _progressHideTimer?.cancel();
        _progressHideTimer = Timer(const Duration(milliseconds: 260), () {
          if (!mounted) return;
          setState(() {
            _showProgress = false;
            _progress = 0;
          });
        });
        break;
      case 'onReceivedError':
        if (args['isForMainFrame'] == true) {
          _signalFirstLoad();
          setState(() {
            _isLoading = false;
            _progress = 1;
            _loadError = args['description']?.toString() ?? 'Não foi possível carregar esta página.';
          });
          _progressHideTimer?.cancel();
          _progressHideTimer = Timer(const Duration(milliseconds: 260), () {
            if (mounted) setState(() => _showProgress = false);
          });
        }
        break;
      case 'onDownloadStartRequest':
        if (!widget.isIncognito) {
          downloadsController.register(
            url: args['url']?.toString() ?? '',
            filename: args['suggestedFilename']?.toString(),
            mimeType: args['mimeType']?.toString(),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pedido de transferência recebido.')),
          );
        }
        break;
      case 'onRenderProcessGone':
        _signalFirstLoad();
        setState(() {
          _renderProcessCrashed = true;
          _isLoading = false;
          _showProgress = false;
          _loadError = 'O motor da página foi reiniciado.';
        });
        break;
    }
    return null;
  }

  Widget _buildPluginWebView(BuildContext context) {
    final bg = pageBg(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        if (!_renderProcessCrashed)
          InAppWebView(
            key: _webViewKey,
            initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
            pullToRefreshController: _pullToRefreshController,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
              cacheEnabled: navigationAcceleratorEnabled.value,
              cacheMode: navigationAcceleratorEnabled.value
                  ? CacheMode.LOAD_DEFAULT
                  : CacheMode.LOAD_NO_CACHE,
              offscreenPreRaster: true,
              hardwareAcceleration: true,
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
              final orbitController = _OrbitWebViewController.plugin(controller);
              _controller = orbitController;
              BrowserPreconnectHints.attach(widget.tabId, orbitController.evaluateJavascript);
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
              setState(() {
                _isLoading = true;
                _showProgress = true;
                _progress = 0;
                _loadError = null;
                if (url != null) _currentUrl = url.toString();
              });
              _updateTabState();
            },
            onTitleChanged: (controller, title) {
              if (!mounted) return;
              _currentTitle = title ?? '';
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
                _currentUrl = nextUrl;
                _canGoBack = canBack;
                _canGoForward = canForward;
                if (title?.trim().isNotEmpty == true) _currentTitle = title!;
              });
              if (!widget.isIncognito) {
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
              Uint8List? screenshot;
              try {
                back = await controller.canGoBack();
                forward = await controller.canGoForward();
                screenshot = await controller
                    .takeScreenshot()
                    .timeout(const Duration(seconds: 2));
              } catch (_) {}

              if (screenshot != null) {
                screenshot = await _downscaleScreenshot(screenshot, targetWidth: 420);
              }
              final loadedUrl = url?.toString() ?? _currentUrl;
              if (!widget.isIncognito) {
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

              setState(() {
                _isLoading = false;
                _progress = 1;
                _showProgress = true;
                _loadError = null;
                _canGoBack = back;
                _canGoForward = forward;
                if (url != null) _currentUrl = url.toString();
              });
              _updateTabState(screenshot: screenshot);
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
                  const SnackBar(content: Text('Pedido de transferência recebido.')),
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
        if (_renderProcessCrashed || _loadError != null)
          _buildWebViewErrorOverlay(context, bg),
      ],
    );
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
                Icon(
                  _renderProcessCrashed ? Symbols.refresh_rounded : Symbols.wifi_off_rounded,
                  size: 42,
                  color: mutedText(context),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError ?? 'Não foi possível carregar esta página.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mainText(context)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retryPage,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
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
                child: Icon(icon, size: 23, color: enabled ? foreground : muted),
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
              SizedBox(width: 42, child: Icon(icon, size: 23, color: mainText(context))),
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
        icon: Icon(icon, size: 22),
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
        Icon(icon, size: 20, color: mainText(context)),
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
