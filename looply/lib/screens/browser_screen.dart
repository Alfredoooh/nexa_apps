import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';
import 'home_screen.dart';

// Rota sem transição para o browser. As superfícies nativas do WebView não
// devem atravessar animações de página do Flutter: o conteúdo fica visível
// sem o flash da composição durante a entrada/saída da rota.
PageRoute<void> openBrowserRoute({required String tabId, required String initialUrl, GlobalKey? viewportKey, ValueListenable<bool>? revealWebView}) {
  return PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => BrowserScreen(
      tabId: tabId,
      initialUrl: initialUrl,
      viewportKey: viewportKey,
      revealWebView: revealWebView,
    ),
  );
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.tabId, required this.initialUrl, this.viewportKey, this.revealWebView});
  final String tabId;
  final String initialUrl;
  final GlobalKey? viewportKey;
  final ValueListenable<bool>? revealWebView;
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  bool _isLoading = true;
  double _progress = 0;
  late String _currentUrl;
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _renderProcessCrashed = false;
  String? _loadError;
  Key _webViewKey = UniqueKey();
  bool _addressBarVisible = true;
  int _lastScrollY = 0;
  Timer? _scrollDebounce;
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    final existingTab = tabsController.getTab(widget.tabId);
    _currentUrl = _normalizeBrowserUrl((existingTab != null && existingTab.url.isNotEmpty) ? existingTab.url : widget.initialUrl);
    _currentTitle = existingTab?.title ?? '';
    tabsController.activate(widget.tabId);
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: looplyPrimary),
      onRefresh: () async {
        try {
          if (_controller != null) {
            await _controller!.reload();
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
    _scrollDebounce?.cancel();
    _loadTimeout?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  String _normalizeBrowserUrl(String value) {
    final input = value.trim();
    if (input.isEmpty) return 'https://www.google.com';

    final parsed = Uri.tryParse(input);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https') &&
        parsed.hasAuthority) {
      return parsed.toString();
    }

    if (input.startsWith('www.')) return 'https://$input';
    if (!input.contains(' ') && input.contains('.')) return 'https://$input';
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(input)}';
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
    final controller = _controller;
    if (_canGoBack && controller != null && !_renderProcessCrashed) {
      try {
        await controller.goBack();
        return false;
      } catch (_) {
        // Fall through to route navigation when the native renderer is gone.
      }
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
        child: ColoredBox(
          color: bg,
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
                child: KeyedSubtree(
                  key: widget.viewportKey,
                  child: ColoredBox(
                    color: bg,
                    child: widget.revealWebView == null
                        ? _buildBrowserWebView(context)
                        : ValueListenableBuilder<bool>(
                            valueListenable: widget.revealWebView!,
                            builder: (context, revealed, _) => revealed
                                ? _buildBrowserWebView(context)
                                : ColoredBox(color: bg),
                          ),
                  ),
                ),
              ),
              _BrowserBottomBar(
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onBack: () => _controller?.goBack(),
                onForward: () => _controller?.goForward(),
                onMenu: () => _showPageMenu(context),
                onTabs: () { _updateTabState(); ShellTabRequest.instance.requestTabs(); },
                onHome: () { _updateTabState(); ShellTabRequest.instance.request(0); Navigator.of(context).popUntil((route) => route.isFirst); },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowserWebView(BuildContext context) {
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
              transparentBackground: false,
              underPageBackgroundColor: bg,
              cacheMode: CacheMode.LOAD_DEFAULT,
              hardwareAcceleration: true,
              // Usa a camada de textura integrada no Flutter. Isso mantém
              // a WebView limitada ao seu viewport e evita que a superfície
              // híbrida cubra os restantes controlos durante os morphs.
              useHybridComposition: false,
              useOnRenderProcessGone: true,
              safeBrowsingEnabled: true,
              useShouldInterceptRequest: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
              javaScriptCanOpenWindowsAutomatically: false,
              supportMultipleWindows: false,
              useShouldOverrideUrlLoading: true,
            ),
            shouldOverrideUrlLoading: (controller, action) async {
              final uri = action.request.url;
              if (uri == null) return NavigationActionPolicy.ALLOW;
              final scheme = uri.scheme.toLowerCase();
              return {'http', 'https', 'about', 'data', 'blob'}.contains(scheme)
                  ? NavigationActionPolicy.ALLOW
                  : NavigationActionPolicy.CANCEL;
            },
            shouldInterceptRequest: (controller, request) async {
              if (isAdBlockedUrl(request.url.toString())) {
                return WebResourceResponse(contentType: 'text/plain', data: Uint8List(0));
              }
              return null;
            },
            onWebViewCreated: (controller) => _controller = controller,
            onProgressChanged: (controller, progress) {
              if (mounted) setState(() => _progress = progress / 100);
            },
            onLoadStart: (controller, url) {
              if (!mounted) return;
              _loadTimeout?.cancel();
              _loadTimeout = Timer(const Duration(seconds: 30), () {
                if (!mounted || !_isLoading) return;
                setState(() {
                  _isLoading = false;
                  _loadError = 'A página está a demorar demasiado tempo a responder.';
                });
              });
              setState(() {
                _isLoading = true;
                _progress = 0;
                _loadError = null;
                if (url != null) _currentUrl = url.toString();
              });
            },
            onTitleChanged: (controller, title) {
              if (!mounted) return;
              _currentTitle = title ?? '';
              _updateTabState();
              setState(() {});
            },
            onLoadStop: (controller, url) async {
              _loadTimeout?.cancel();
              _pullToRefreshController?.endRefreshing();
              if (!mounted) return;

              // Liberta a interface imediatamente. A captura de screenshot e
              // do HTML é secundária e não deve atrasar o fim do carregamento.
              setState(() {
                _isLoading = false;
                _progress = 1;
                _loadError = null;
                if (url != null) _currentUrl = url.toString();
              });

              bool back = false;
              bool forward = false;
              Uint8List? screenshot;
              String? html;
              try {
                back = await controller.canGoBack();
                forward = await controller.canGoForward();
                screenshot = await controller.takeScreenshot();
                if (navigationAcceleratorEnabled.value) {
                  html = await controller.getHtml();
                }
              } catch (_) {}

              if (html != null && navigationAcceleratorEnabled.value) {
                NavAccelerator.instance.cachePage(url?.toString() ?? _currentUrl, html);
              }
              if (!mounted) return;
              setState(() {
                _canGoBack = back;
                _canGoForward = forward;
              });
              _updateTabState(screenshot: screenshot);
            },
            onReceivedError: (controller, request, error) {
              _pullToRefreshController?.endRefreshing();
              if (request.isForMainFrame == true && mounted) {
                _loadTimeout?.cancel();
                setState(() {
                  _isLoading = false;
                  _progress = 0;
                  _loadError = error.description;
                });
              }
            },
            onRenderProcessGone: (controller, detail) {
              _loadTimeout?.cancel();
              _pullToRefreshController?.endRefreshing();
              if (!mounted) return;
              setState(() {
                _renderProcessCrashed = true;
                _isLoading = false;
                _loadError = 'O motor da página foi reiniciado.';
              });
            },
            onScrollChanged: (controller, x, y) => _onScrollChanged(y),
          ),
        if (_renderProcessCrashed || _loadError != null)
          Positioned.fill(
            child: ColoredBox(
              color: bg,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_renderProcessCrashed ? Symbols.refresh_rounded : Symbols.wifi_off_rounded, size: 42, color: mutedText(context)),
                    const SizedBox(height: 12),
                    Text(_loadError ?? 'Não foi possível carregar esta página.', textAlign: TextAlign.center, style: TextStyle(color: mainText(context))),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        _loadTimeout?.cancel();
                        _controller?.dispose();
                        setState(() {
                          _renderProcessCrashed = false;
                          _loadError = null;
                          _isLoading = true;
                          _controller = null;
                          _webViewKey = UniqueKey();
                        });
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
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
          Icon(Symbols.public_rounded, color: muted, size: 20),
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
    final bg = browserBottomBarColor(context);
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