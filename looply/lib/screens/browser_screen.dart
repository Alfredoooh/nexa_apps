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

/// Abre o navegador como um ecrã normal do Flutter.
///
/// As entradas comuns (sites rápidos, pesquisa, histórico e atividade) usam
/// MaterialPageRoute para manter a transição normal do Android. A transição
/// especial de expansão da captura das abas é tratada separadamente pelo shell.
PageRoute<void> openBrowserRoute({
  required String tabId,
  required String initialUrl,
  GlobalKey? viewportKey,
  ValueListenable<bool>? revealWebView,
}) {
  return MaterialPageRoute<void>(
    builder: (context) => BrowserScreen(
      tabId: tabId,
      initialUrl: initialUrl,
      viewportKey: viewportKey,
      revealWebView: revealWebView,
    ),
  );
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.tabId,
    required this.initialUrl,
    this.viewportKey,
    this.revealWebView,
  });

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
  String? _loadError;
  bool _renderProcessCrashed = false;
  Key _webViewKey = UniqueKey();
  bool _addressBarVisible = true;
  int _lastScrollY = 0;
  Timer? _scrollDebounce;

  String _normalizeUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return 'https://www.google.com';

    final parsed = Uri.tryParse(raw);
    if (parsed != null) {
      final scheme = parsed.scheme.toLowerCase();
      if ((scheme == 'http' || scheme == 'https') && parsed.host.isNotEmpty) {
        return parsed.toString();
      }
      if (scheme.isNotEmpty) {
        return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(raw)}';
      }
    }

    if (raw.contains(' ')) {
      return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(raw)}';
    }
    return 'https://${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  @override
  void initState() {
    super.initState();
    final existingTab = tabsController.getTab(widget.tabId);
    _currentUrl = _normalizeUrl(
      existingTab != null && existingTab.url.trim().isNotEmpty
          ? existingTab.url
          : widget.initialUrl,
    );
    _currentTitle = existingTab?.title ?? '';
    tabsController.activate(widget.tabId);

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
    _scrollDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
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

  void _onScrollChanged(int y) {
    final dy = y - _lastScrollY;
    _lastScrollY = y;
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      if (dy > 14 && _addressBarVisible) {
        setState(() => _addressBarVisible = false);
      } else if (dy < -14 && !_addressBarVisible) {
        setState(() => _addressBarVisible = true);
      }
    });
  }

  Future<bool> _handleBack() async {
    final controller = _controller;
    if (_canGoBack && controller != null && !_renderProcessCrashed) {
      try {
        await controller.goBack();
        return false;
      } catch (_) {
        // Se o motor tiver sido reiniciado, regressa à navegação Flutter.
      }
    }
    _updateTabState();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final revealListenable = widget.revealWebView;
    if (revealListenable == null) {
      return _buildBrowserScreen(context, revealed: true);
    }

    return ValueListenableBuilder<bool>(
      valueListenable: revealListenable,
      builder: (context, revealed, _) =>
          _buildBrowserScreen(context, revealed: revealed),
    );
  }

  Widget _buildBrowserScreen(
    BuildContext context, {
    required bool revealed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final muted = mutedText(context);
    final pageColor = revealed ? bg : Colors.transparent;
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: revealed ? bg : Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: revealed ? bg : Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleBack() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: ColoredBox(
          color: pageColor,
          child: Scaffold(
            backgroundColor: pageColor,
            body: Column(
              children: [
                IgnorePointer(
                  ignoring: !revealed,
                  child: Opacity(
                    opacity: revealed ? 1 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      height: _addressBarVisible
                          ? 60 + MediaQuery.of(context).padding.top
                          : 0,
                      clipBehavior: Clip.hardEdge,
                      child: OverflowBox(
                        minHeight: 60 + MediaQuery.of(context).padding.top,
                        maxHeight: 60 + MediaQuery.of(context).padding.top,
                        alignment: Alignment.bottomCenter,
                        child: _AddressBar(
                          title: _currentTitle.isNotEmpty
                              ? _currentTitle
                              : _currentUrl,
                          url: _currentUrl,
                          isLoading: _isLoading,
                          onReload: () => _controller?.reload(),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 2,
                  child: Opacity(
                    opacity: revealed && _isLoading ? 1 : 0,
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      color: accentColor(context),
                      backgroundColor: muted.withOpacity(.15),
                    ),
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: widget.viewportKey,
                    child: revealed
                        ? _buildBrowserWebView(context)
                        : const ColoredBox(
                            color: Colors.transparent,
                            child: SizedBox.expand(),
                          ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !revealed,
                  child: Opacity(
                    opacity: revealed ? 1 : 0,
                    child: _BrowserBottomBar(
                      canGoBack: _canGoBack,
                      canGoForward: _canGoForward,
                      onBack: () => _controller?.goBack(),
                      onForward: () => _controller?.goForward(),
                      onMenu: () => _showPageMenu(context),
                      onTabs: () {
                        _updateTabState();
                        ShellTabRequest.instance.requestTabs();
                      },
                      onHome: () {
                        _updateTabState();
                        ShellTabRequest.instance.request(0);
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowserWebView(BuildContext context) {
    final bg = pageBg(context);
    return ColoredBox(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: bg),
          if (!_renderProcessCrashed)
            InAppWebView(
              key: _webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
              pullToRefreshController: _pullToRefreshController,
              // Esta é a configuração simples da versão antiga que funcionava.
              // Evita opções adicionais de composição/interceção que não são
              // necessárias para carregar páginas normais.
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
                cacheMode: CacheMode.LOAD_DEFAULT,
                hardwareAcceleration: true,
              ),
              shouldOverrideUrlLoading: (controller, action) async {
                final uri = action.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;
                final scheme = uri.scheme.toLowerCase();
                return {'http', 'https', 'about', 'data', 'blob'}
                        .contains(scheme)
                    ? NavigationActionPolicy.ALLOW
                    : NavigationActionPolicy.CANCEL;
              },
              shouldInterceptRequest: (controller, request) async {
                if (isAdBlockedUrl(request.url.toString())) {
                  return WebResourceResponse(
                    contentType: 'text/plain',
                    data: Uint8List(0),
                  );
                }
                return null;
              },
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onProgressChanged: (controller, progress) {
                if (mounted) {
                  setState(() => _progress = progress / 100);
                }
              },
              onLoadStart: (controller, url) {
                if (!mounted) return;
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
                _pullToRefreshController?.endRefreshing();
                bool canGoBack = false;
                bool canGoForward = false;
                Uint8List? screenshot;
                String? html;

                try {
                  canGoBack = await controller.canGoBack();
                  canGoForward = await controller.canGoForward();
                  screenshot = await controller.takeScreenshot();
                } catch (_) {}

                if (navigationAcceleratorEnabled.value) {
                  try {
                    html = await controller.getHtml();
                  } catch (_) {}
                }

                if (html != null && navigationAcceleratorEnabled.value) {
                  NavAccelerator.instance.cachePage(
                    url?.toString() ?? _currentUrl,
                    html,
                  );
                }

                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                  _progress = 1;
                  _loadError = null;
                  _canGoBack = canGoBack;
                  _canGoForward = canGoForward;
                  if (url != null) _currentUrl = url.toString();
                });
                _updateTabState(screenshot: screenshot);
              },
              onReceivedError: (controller, request, error) {
                _pullToRefreshController?.endRefreshing();
                if (request.isForMainFrame == true && mounted) {
                  setState(() {
                    _isLoading = false;
                    _loadError = error.description;
                  });
                }
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
                              _progress = 0;
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
      ),
    );
  }

  void _showPageMenu(BuildContext context) {
    final text = mainText(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panelColor(context),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Symbols.refresh_rounded, color: text),
                title: Text(
                  'Atualizar página',
                  style: TextStyle(color: text),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _controller?.reload();
                },
              ),
              ListTile(
                leading: Icon(Symbols.tab_rounded, color: text),
                title: Text('Nova aba', style: TextStyle(color: text)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  openNewTab(context, 'https://www.google.com');
                },
              ),
              ListTile(
                leading: Icon(Symbols.close_rounded, color: text),
                title: Text('Fechar aba', style: TextStyle(color: text)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  tabsController.closeTab(widget.tabId);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.title,
    required this.url,
    required this.isLoading,
    required this.onReload,
  });

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
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 8,
        12,
        8,
      ),
      color: bg,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: pillColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(Symbols.public_rounded, color: muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.isEmpty ? host : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onReload,
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor(context),
                      ),
                    )
                  : Icon(Symbols.refresh_rounded, color: muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserBottomBar extends StatelessWidget {
  const _BrowserBottomBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onMenu,
    required this.onTabs,
    required this.onHome,
  });

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
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: lineColor(context))),
        ),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Voltar',
                icon: Icon(
                  Symbols.arrow_back_rounded,
                  color: canGoBack ? text : muted.withOpacity(.4),
                ),
                onPressed: canGoBack ? onBack : null,
              ),
              IconButton(
                tooltip: 'Avançar',
                icon: Icon(
                  Symbols.arrow_forward_rounded,
                  color: canGoForward ? text : muted.withOpacity(.4),
                ),
                onPressed: canGoForward ? onForward : null,
              ),
              IconButton(
                tooltip: 'Menu',
                icon: Icon(Symbols.menu_rounded, color: text),
                onPressed: onMenu,
              ),
              IconButton(
                tooltip: 'Abas',
                icon: _TabsCountIcon(count: tabsController.count, color: text),
                onPressed: onTabs,
              ),
              IconButton(
                tooltip: 'Início',
                icon: Icon(Symbols.home_rounded, color: text),
                onPressed: onHome,
              ),
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
