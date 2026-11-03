import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
    await evaluateJavascriptResult(source);
  }

  Future<dynamic> evaluateJavascriptResult(String source) async {
    if (native != null) {
      return native!.invokeMethod<dynamic>(
        'evaluateJavascript',
        <String, Object>{'source': source},
      );
    }
    return plugin!.evaluateJavascript(source: source);
  }

  Future<void> setZoom(double scale) async {
    if (native != null) {
      await native!.invokeMethod<void>('setZoom', <String, Object>{'scale': scale});
    } else {
      final value = scale.clamp(.5, 2.0).toStringAsFixed(2);
      await plugin!.evaluateJavascript(
        source: "document.documentElement.style.zoom='$value';",
      );
    }
  }

  Future<void> setDesktopMode(bool enabled) async {
    if (native != null) {
      await native!.invokeMethod<void>('setDesktopMode', <String, Object>{'enabled': enabled});
    } else {
      await plugin!.evaluateJavascript(
        source: "(function(){let m=document.querySelector('meta[name=viewport]');if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}m.content='width=${enabled ? '1024' : 'device-width'}, initial-scale=1';})();",
      );
    }
  }

  Future<Map<String, dynamic>> getSiteInfo() async {
    if (native == null) return <String, dynamic>{};
    final value = await native!.invokeMapMethod<String, dynamic>('getSiteInfo');
    return value ?? <String, dynamic>{};
  }

  Future<void> clearSiteData() async {
    if (native != null) {
      await native!.invokeMethod<void>('clearSiteData');
    } else {
      await plugin!.evaluateJavascript(
        source: "localStorage.clear();sessionStorage.clear();caches.keys().then(keys=>keys.forEach(k=>caches.delete(k)));",
      );
    }
  }

  Future<void> downloadUrl(String url) async {
    if (native != null) {
      await native!.invokeMethod<void>('downloadUrl', <String, Object>{'url': url});
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
  double _pageZoom = 1.0;
  bool _desktopMode = false;
  bool _readerMode = false;
  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');

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
      case _OrbitMenuAction.zoom:
        _showZoomSheet();
        break;
      case _OrbitMenuAction.readerMode:
        await _toggleReaderMode();
        break;
      case _OrbitMenuAction.desktopMode:
        await _toggleDesktopMode();
        break;
      case _OrbitMenuAction.shareLink:
        _showShareSheet(_currentUrl, _currentTitle);
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
                      _BrowserQuickAction(icon: Symbols.zoom_in_rounded, label: 'Zoom', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.zoom)),
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
                      _BrowserSheetListItem(icon: Icons.menu_book_rounded, label: _readerMode ? 'Sair do modo de leitura' : 'Modo de leitura', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.readerMode)),
                      _BrowserSheetListItem(icon: Icons.desktop_windows_rounded, label: _desktopMode ? 'Desativar modo computador' : 'Modo computador', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.desktopMode)),
                      _BrowserSheetListItem(icon: Icons.share_rounded, label: 'Partilhar ligação', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.shareLink)),
                      _BrowserSheetListItem(icon: Icons.info_outline_rounded, label: 'Informações do site', onTap: () => _selectSheetAction(sheetContext, _OrbitMenuAction.siteInfo)),
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

  Future<void> _showSiteInfo() async {
    final uri = Uri.tryParse(_currentUrl);
    final host = uri?.host.isNotEmpty == true ? uri!.host : _currentUrl;
    Map<String, dynamic> info = <String, dynamic>{};
    try {
      info = await _controller?.getSiteInfo() ?? <String, dynamic>{};
    } catch (_) {}
    if (!mounted) return;
    final cookieCount = (info['cookieCount'] as num?)?.toInt() ?? 0;
    final memoryBytes = (info['memoryBytes'] as num?)?.toInt() ?? 0;
    final storageBytes = (info['storageBytes'] as num?)?.toInt() ?? 0;
    final secure = uri?.scheme.toLowerCase() == 'https';
    final cookieNames = (info['cookieNames'] as List?)?.whereType<String>().toList() ?? <String>[];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: pillColor(context),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: secure ? const Color(0xFF1E8E5A).withOpacity(.15) : Colors.orange.withOpacity(.14), shape: BoxShape.circle), child: Icon(secure ? Icons.lock_rounded : Icons.warning_amber_rounded, color: secure ? const Color(0xFF35B878) : Colors.orange, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_currentTitle.trim().isEmpty ? host : _currentTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainText(context), fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
                ])),
              ]),
              const SizedBox(height: 17),
              _SiteInfoRow(label: 'Segurança', value: secure ? 'Ligação encriptada (HTTPS)' : 'Ligação sem HTTPS'),
              _SiteInfoRow(label: 'Cookies', value: '$cookieCount guardados'),
              _SiteInfoRow(label: 'Memória JavaScript', value: memoryBytes > 0 ? _formatBytes(memoryBytes) : 'Não disponibilizada pelo site'),
              _SiteInfoRow(label: 'Armazenamento local JS', value: storageBytes > 0 ? _formatBytes(storageBytes) : 'Não disponibilizado'),
              if (cookieNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Cookies detetados', style: TextStyle(color: mutedText(context), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(cookieNames.take(5).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedText(context), fontSize: 10.5)),
              ],
              const SizedBox(height: 17),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    try {
                      await _controller?.clearSiteData();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cookies e armazenamento deste site eliminados.')));
                    } catch (_) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível limpar os dados deste site.')));
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar dados do site'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Fechar')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _showZoomSheet() async {
    var zoom = _pageZoom;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Material(
            color: panelColor(context),
            surfaceTintColor: Colors.transparent,
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: mutedText(context).withOpacity(.45), borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.zoom_in_rounded, color: accentColor(context)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Zoom da página', style: TextStyle(color: mainText(context), fontWeight: FontWeight.w700, fontSize: 16))),
                  Text('${(zoom * 100).round()}%', style: TextStyle(color: mainText(context), fontWeight: FontWeight.w700)),
                  TextButton(onPressed: () { setSheetState(() => zoom = 1); setState(() => _pageZoom = 1); unawaited(_controller?.setZoom(1)); }, child: const Text('Repor')),
                ]),
                Slider(
                  value: zoom,
                  min: .5,
                  max: 2,
                  divisions: 30,
                  label: '${(zoom * 100).round()}%',
                  onChanged: (value) {
                    setSheetState(() => zoom = value);
                    setState(() => _pageZoom = value);
                    unawaited(_controller?.setZoom(value));
                  },
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('50%', style: TextStyle(color: mutedText(context), fontSize: 11)),
                  Text('200%', style: TextStyle(color: mutedText(context), fontSize: 11)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReaderMode() async {
    final script = _readerMode
        ? "(function(){if(!window.__looplyReaderBackup)return 'off';document.getElementById('__looplyReaderStyle')?.remove();document.body.innerHTML=window.__looplyReaderBackup.html;document.title=window.__looplyReaderBackup.title;document.documentElement.style.cssText=window.__looplyReaderBackup.htmlStyle;delete window.__looplyReaderBackup;return 'off';})()"
        : "(function(){if(window.__looplyReaderBackup)return 'on';const candidates=[...document.querySelectorAll('article,main,[role=main],section,div')].filter(e=>e.innerText&&e.innerText.trim().length>350);candidates.sort((a,b)=>b.innerText.length-a.innerText.length);const target=candidates[0]||document.body;const clone=target.cloneNode(true);clone.querySelectorAll('script,style,nav,footer,header,aside,button,form,[aria-hidden=true]').forEach(e=>e.remove());const text=clone.innerText||'';if(text.trim().length<180)return 'unavailable';window.__looplyReaderBackup={html:document.body.innerHTML,title:document.title,htmlStyle:document.documentElement.style.cssText};const wrap=document.createElement('main');wrap.id='__looplyReaderView';wrap.appendChild(clone);document.body.innerHTML='';document.body.appendChild(wrap);const style=document.createElement('style');style.id='__looplyReaderStyle';style.textContent='html,body{background:#f7f5ef!important;color:#202124!important}body{margin:0!important;padding:28px 22px!important;font:18px/1.75 Georgia,serif!important}#__looplyReaderView{max-width:720px;margin:0 auto!important}#__looplyReaderView img{max-width:100%;height:auto}#__looplyReaderView h1,#__looplyReaderView h2,#__looplyReaderView h3{line-height:1.25;color:#17191b}#__looplyReaderView p{margin:0 0 1.15em}';document.head.appendChild(style);document.documentElement.style.background='#f7f5ef';return 'on';})()";
    try {
      final result = await _controller?.evaluateJavascriptResult(script);
      if (result?.toString().contains('unavailable') == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta página não contém um artigo adequado ao modo de leitura.')));
        return;
      }
      if (!mounted) return;
      setState(() => _readerMode = !_readerMode);
    } catch (_) {}
  }

  Future<void> _toggleDesktopMode() async {
    final enabled = !_desktopMode;
    try {
      await _controller?.setDesktopMode(enabled);
      if (!mounted) return;
      setState(() => _desktopMode = enabled);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'Modo computador ativado.' : 'Modo móvel ativado.')));
    } catch (_) {}
  }

  Future<void> _showShareSheet(String url, String title) async {
    if (url.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Material(
          color: panelColor(context),
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: mutedText(context).withOpacity(.45), borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: Text('Partilhar ligação', style: TextStyle(color: mainText(context), fontWeight: FontWeight.w800, fontSize: 17))),
              const SizedBox(height: 14),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(16)), child: Text(title.trim().isEmpty ? url : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainText(context), fontSize: 13))),
              const SizedBox(height: 18),
              Row(children: [
                _ShareTarget(asset: 'assets/images/share/whatsapp.png', color: const Color(0xFF25D366), label: 'WhatsApp', onTap: () => _shareTo(url, 'com.whatsapp', sheetContext)),
                _ShareTarget(asset: 'assets/images/share/telegram.png', color: const Color(0xFF26A5E4), label: 'Telegram', onTap: () => _shareTo(url, 'org.telegram.messenger', sheetContext)),
                _ShareTarget(asset: 'assets/images/quick_sites/gmail.webp', color: const Color(0xFFEA4335), label: 'Gmail', onTap: () => _shareTo(url, 'com.google.android.gm', sheetContext)),
                _ShareTarget(icon: Icons.more_horiz_rounded, color: accentColor(context), label: 'Demais', onTap: () => _shareTo(url, null, sheetContext)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _shareTo(String url, String? packageName, BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    try {
      await _nativeUi.invokeMethod<void>('shareLink', <String, Object?>{
        'url': url,
        if (packageName != null) 'packageName': packageName,
      });
    } catch (_) {
      if (mounted) await Clipboard.setData(ClipboardData(text: url));
    }
  }

  void _openContextTarget(String url) {
    if (url.trim().isEmpty) return;
    final tab = tabsController.createBrowserTab(url);
    ShellTabRequest.instance.requestBrowser(tab.id);
  }

  Future<void> _showContextMenu(Map<dynamic, dynamic> args) async {
    final type = args['type']?.toString() ?? 'link';
    final isImage = type == 'image';
    final url = (isImage ? args['imageUrl'] : args['linkUrl'])?.toString().trim() ?? '';
    final linkUrl = args['linkUrl']?.toString().trim() ?? '';
    final label = args['linkText']?.toString().trim() ?? '';
    final width = (args['imageWidth'] as num?)?.toInt() ?? 0;
    final height = (args['imageHeight'] as num?)?.toInt() ?? 0;
    if (url.isEmpty || !mounted) return;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF343740),
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 430, maxHeight: MediaQuery.sizeOf(context).height * .82),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
              child: Row(children: [
                if (isImage)
                  ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(url, width: 60, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 60, height: 48, child: Icon(Icons.image_rounded, color: Colors.white70))))
                else
                  Container(width: 48, height: 48, decoration: const BoxDecoration(color: Color(0xFF4A4D55), shape: BoxShape.circle), alignment: Alignment.center, child: Text(host.isEmpty ? '↗' : host[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20))),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isImage ? (width > 0 && height > 0 ? 'Imagem ($width×$height)' : 'Imagem') : (label.isEmpty ? host : label), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF3F4F6), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(isImage ? host : url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFB7BBC3), fontSize: 11.5)),
                ])),
                IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFF4A4D55)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 7),
                children: isImage ? [
                  _ContextAction(title: 'Abrir imagem num novo separador', onTap: () { Navigator.of(dialogContext).pop(); _openContextTarget(url); }),
                  _ContextAction(title: 'Pré-visualizar imagem', onTap: () { Navigator.of(dialogContext).pop(); _showWebPreview(url, 'Imagem'); }),
                  _ContextAction(title: 'Copiar imagem', onTap: () async { await Clipboard.setData(ClipboardData(text: url)); if (dialogContext.mounted) Navigator.of(dialogContext).pop(); }),
                  _ContextAction(title: 'Transferir imagem', onTap: () async { Navigator.of(dialogContext).pop(); await _controller?.downloadUrl(url); }),
                  _ContextAction(title: 'Pesquisar a imagem no Google', onTap: () { Navigator.of(dialogContext).pop(); _openContextTarget('https://www.google.com/searchbyimage?image_url=${Uri.encodeComponent(url)}'); }),
                  _ContextAction(title: 'Partilhar imagem', onTap: () { Navigator.of(dialogContext).pop(); _showShareSheet(url, 'Imagem'); }),
                ] : [
                  _ContextAction(title: 'Abrir num novo separador', onTap: () { Navigator.of(dialogContext).pop(); _openContextTarget(url); }),
                  _ContextAction(title: 'Pré-visualizar página', onTap: () { Navigator.of(dialogContext).pop(); _showWebPreview(url, label.isEmpty ? host : label); }),
                  _ContextAction(title: 'Copiar endereço do link', onTap: () async { await Clipboard.setData(ClipboardData(text: url)); if (dialogContext.mounted) Navigator.of(dialogContext).pop(); }),
                  if (label.isNotEmpty) _ContextAction(title: 'Copiar texto do link', onTap: () async { await Clipboard.setData(ClipboardData(text: label)); if (dialogContext.mounted) Navigator.of(dialogContext).pop(); }),
                  _ContextAction(title: 'Transferir link', onTap: () async { Navigator.of(dialogContext).pop(); await _controller?.downloadUrl(url); }),
                  _ContextAction(title: 'Adicionar à Lista de leitura', onTap: () { bookmarksController.add(label.isEmpty ? host : label, url); Navigator.of(dialogContext).pop(); }),
                  _ContextAction(title: 'Partilhar link', onTap: () { Navigator.of(dialogContext).pop(); _showShareSheet(url, label); }),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showWebPreview(String url, String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => _OrbitPreviewSheet(url: url, title: title, onOpen: () {
        Navigator.of(sheetContext).pop();
        _openContextTarget(url);
      }),
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
      case 'onLongPress':
        unawaited(_showContextMenu(Map<dynamic, dynamic>.from(args)));
        break;
      case 'onLoadStart':
        _progressHideTimer?.cancel();
        setState(() {
          _isLoading = true;
          _showProgress = true;
          _progress = 0;
          _loadError = null;
          _readerMode = false;
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
        if (_pageZoom != 1.0) unawaited(controller?.setZoom(_pageZoom));
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
  zoom,
  readerMode,
  desktopMode,
  shareLink,
  history,
  downloads,
  bookmark,
}

class _SiteInfoRow extends StatelessWidget {
  const _SiteInfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: mutedText(context), fontSize: 12))),
      const SizedBox(width: 12),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: mainText(context), fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _ContextAction extends StatelessWidget {
  const _ContextAction({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 13, 18, 13),
      child: Text(title, style: const TextStyle(color: Color(0xFFE7E9ED), fontSize: 15.5, fontWeight: FontWeight.w400)),
    ),
  );
}

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({this.icon, this.asset, required this.color, required this.label, required this.onTap});
  final IconData? icon;
  final String? asset;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(.16), shape: BoxShape.circle), alignment: Alignment.center,
            child: asset != null ? ClipOval(child: Image.asset(asset!, width: 27, height: 27, fit: BoxFit.contain)) : Icon(icon, color: color, size: 23)),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: mainText(context), fontSize: 10.5)),
        ]),
      ),
    ),
  );
}

class _OrbitPreviewSheet extends StatelessWidget {
  const _OrbitPreviewSheet({required this.url, required this.title, required this.onOpen});
  final String url;
  final String title;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Material(
      color: panelColor(context),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(children: [
          const SizedBox(height: 9),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: muted.withOpacity(.5), borderRadius: BorderRadius.circular(99))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(children: [
              Icon(Icons.public_rounded, color: mainText(context), size: 21),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.isEmpty ? Uri.tryParse(url)?.host ?? url : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainText(context), fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 10.5)),
              ])),
              IconButton(tooltip: 'Abrir no Orbit', onPressed: onOpen, icon: Icon(Icons.open_in_new_rounded, color: mainText(context))),
              IconButton(tooltip: 'Fechar', onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close_rounded, color: mainText(context))),
            ]),
          ),
          Expanded(
            child: defaultTargetPlatform == TargetPlatform.android
                ? AndroidView(
                    viewType: 'looply/orbit_native_webview',
                    layoutDirection: TextDirection.ltr,
                    creationParams: const <String, Object>{'isIncognito': false, 'cacheEnabled': true, 'adBlockEnabled': true},
                    creationParamsCodec: const StandardMessageCodec(),
                    onPlatformViewCreated: (viewId) {
                      final channel = MethodChannel('looply/orbit_webview_$viewId');
                      unawaited(channel.invokeMethod<void>('configure', <String, Object>{'url': url, 'cacheEnabled': true, 'adBlockEnabled': true}));
                    },
                  )
                : InAppWebView(initialUrlRequest: URLRequest(url: WebUri(url))),
          ),
        ]),
      ),
    );
  }
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
