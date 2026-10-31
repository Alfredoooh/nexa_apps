import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';

const String _wikipediaUrl = 'https://www.wikipedia.org';

/// A única implementação de navegador do Looply.
/// Todas as URLs (incluindo a Wikipédia) são abertas por este ecrã.
/// A rota tem duração zero; o Container Transform das abas continua a ser
/// controlado pelo shell, sem qualquer alteração à sua implementação.
PageRoute<void> openBrowserRoute({
  required String tabId,
  required String initialUrl,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        WikipediaBrowserScreen.forTab(
      tabId: tabId,
      initialUrl: initialUrl,
    ),
  );
}

class WikipediaBrowserScreen extends StatefulWidget {
  /// Instância persistente da página Wikipédia dentro do IndexedStack.
  const WikipediaBrowserScreen({
    super.key,
    required this.tabId,
    this.viewportKey,
    this.isActive = false,
  })  : initialUrl = _wikipediaUrl,
        isShellPage = true,
        firstLoadCompleter = null;

  /// Mesmo ecrã para os restantes separadores e endereços.
  const WikipediaBrowserScreen.forTab({
    super.key,
    required this.tabId,
    required this.initialUrl,
    this.viewportKey,
    this.firstLoadCompleter,
  })  : isActive = true,
        isShellPage = false;

  final String tabId;
  final String initialUrl;
  final GlobalKey? viewportKey;
  final bool isActive;
  final bool isShellPage;
  final Completer<void>? firstLoadCompleter;

  @override
  State<WikipediaBrowserScreen> createState() =>
      _WikipediaBrowserScreenState();
}

class _WikipediaBrowserScreenState extends State<WikipediaBrowserScreen> {
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

    // A página persistente é ativada pelo shell antes da construção.
    // Nas rotas de navegação, a própria tela ativa o respetivo separador.
    if (!widget.isShellPage) {
      tabsController.activate(widget.tabId);
    }

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
  void didUpdateWidget(covariant WikipediaBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId && widget.isShellPage) {
      final tab = tabsController.getTab(widget.tabId);
      final nextUrl = (tab?.url.isNotEmpty ?? false)
          ? tab!.url
          : widget.initialUrl;
      _currentUrl = nextUrl;
      _currentTitle = tab?.title ?? '';
      _canGoBack = false;
      _canGoForward = false;
      final controller = _controller;
      if (controller != null) {
        unawaited(
          controller.loadUrl(
            urlRequest: URLRequest(url: WebUri(nextUrl)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _signalFirstLoad();
    super.dispose();
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
      title: _currentTitle.isNotEmpty ? _currentTitle : _currentUrl,
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
      thumbnail: screenshot,
    );
  }

  Future<bool> _tryWebViewBack() async {
    final controller = _controller;
    if (_canGoBack && controller != null && !_renderProcessCrashed) {
      try {
        await controller.goBack();
        return true;
      } catch (_) {
        // O renderer pode ter sido encerrado; nesse caso sai da página.
      }
    }
    return false;
  }

  Future<void> _handleSystemBack() async {
    if (await _tryWebViewBack()) return;
    if (!mounted) return;

    if (widget.isShellPage) {
      ShellTabRequest.instance.request(0);
    } else {
      _updateTabState();
      Navigator.of(context).pop();
    }
  }

  Future<Uint8List?> _captureScreenshot() async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      return await controller
          .takeScreenshot()
          .timeout(const Duration(milliseconds: 700));
    } catch (_) {
      return null;
    }
  }

  Future<void> _openTabsGrid() async {
    if (_tabsRequestInProgress) return;
    _tabsRequestInProgress = true;
    try {
      final freshScreenshot = await _captureScreenshot();
      final oldScreenshot = tabsController.getTab(widget.tabId)?.thumbnail;
      _updateTabState(screenshot: freshScreenshot ?? oldScreenshot);

      if (!mounted) return;
      if (widget.isShellPage) {
        ShellTabRequest.instance
            .requestCloseWikipedia(freshScreenshot ?? oldScreenshot);
      } else {
        ShellTabRequest.instance.requestTabs();
      }
    } finally {
      _tabsRequestInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final fallbackTitle = widget.isShellPage
        ? 'Wikipédia'
        : (Uri.tryParse(_currentUrl)?.host.isNotEmpty == true
            ? Uri.parse(_currentUrl).host
            : 'Navegador');

    return PopScope(
      canPop: widget.isShellPage ? !widget.isActive : false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleSystemBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: bg,
                statusBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: bg,
                statusBarIconBrightness: Brightness.dark,
              ),
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Fechar',
              icon: Icon(Symbols.close_rounded, color: text),
              onPressed: () {
                if (widget.isShellPage) {
                  ShellTabRequest.instance.request(0);
                } else {
                  _updateTabState();
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text(
              _currentTitle.isNotEmpty ? _currentTitle : fallbackTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              AnimatedBuilder(
                animation: tabsController,
                builder: (context, _) => IconButton(
                  tooltip: 'Abas',
                  icon: _TabsCountIcon(count: tabsController.count, color: text),
                  onPressed: _openTabsGrid,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_isLoading)
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                    color: accentColor(context),
                    backgroundColor: muted.withOpacity(.15),
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
              cacheMode: CacheMode.LOAD_DEFAULT,
              hardwareAcceleration: true,
            ),
            shouldOverrideUrlLoading: (controller, action) async {
              final uri = action.request.url;
              if (uri == null) return NavigationActionPolicy.ALLOW;
              final scheme = uri.scheme.toLowerCase();
              if (scheme != 'http' &&
                  scheme != 'https' &&
                  scheme != 'about' &&
                  scheme != 'data' &&
                  scheme != 'blob') {
                return NavigationActionPolicy.CANCEL;
              }
              return null;
            },
            onWebViewCreated: (controller) => _controller = controller,
            onProgressChanged: (controller, progress) {
              if (mounted) setState(() => _progress = progress / 100);
            },
            onLoadStart: (controller, url) {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
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
            onLoadStop: (controller, url) async {
              _pullToRefreshController?.endRefreshing();
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

              final loadedUrl = url?.toString() ?? _currentUrl;
              if (html != null && navigationAcceleratorEnabled.value) {
                NavAccelerator.instance.cachePage(loadedUrl, html);
              }

              if (!mounted) {
                _signalFirstLoad();
                return;
              }

              setState(() {
                _isLoading = false;
                _loadError = null;
                _canGoBack = back;
                _canGoForward = forward;
                if (url != null) _currentUrl = url.toString();
              });
              _updateTabState(screenshot: screenshot);
              _signalFirstLoad();
            },
            onReceivedError: (controller, request, error) {
              _pullToRefreshController?.endRefreshing();
              if (request.isForMainFrame == true) {
                _signalFirstLoad();
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                    _loadError = error.description;
                  });
                }
              }
            },
            onRenderProcessGone: (controller, detail) {
              _pullToRefreshController?.endRefreshing();
              _signalFirstLoad();
              if (!mounted) return;
              setState(() {
                _renderProcessCrashed = true;
                _isLoading = false;
                _loadError = 'O motor da página foi reiniciado.';
              });
            },
          ),
        if (_renderProcessCrashed || _loadError != null)
          Positioned.fill(
            child: ColoredBox(
              color: bg,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _renderProcessCrashed
                            ? Symbols.refresh_rounded
                            : Symbols.wifi_off_rounded,
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
                        onPressed: () {
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
                    ],
                  ),
                ),
              ),
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
        width: 23,
        height: 23,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(.85), width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      );
}
