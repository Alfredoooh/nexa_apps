import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'search_screen.dart';

/// Browser único do Looply. Cada separador mantém a sua própria instância
/// deste widget e da InAppWebView dentro do IndexedStack. As páginas inativas
/// ficam Offstage, sem remover o WebView nem reconstruir o documento.
class OrbitBrowserScreen extends StatefulWidget {
  const OrbitBrowserScreen({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.isActive,
    required this.viewportKey,
    this.firstLoadCompleter,
  });

  final String tabId;
  final String initialUrl;
  final bool isActive;
  final GlobalKey viewportKey;
  final Completer<void>? firstLoadCompleter;

  @override
  State<OrbitBrowserScreen> createState() => _OrbitBrowserScreenState();
}

class _OrbitBrowserScreenState extends State<OrbitBrowserScreen> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  Timer? _progressHideTimer;

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
    // Este State só é descartado quando o separador é realmente fechado.
    // Ao alternar entre abas, o IndexedStack mantém este widget montado.
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
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
        break;
      case _OrbitMenuAction.goHome:
        ShellTabRequest.instance.request(0);
        break;
      case _OrbitMenuAction.history:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        );
        break;
    }
  }

  void _triggerShortcut(_OrbitMenuAction action) {
    Navigator.of(context).pop();
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
    final popupWidth = (MediaQuery.sizeOf(context).width - 24)
        .clamp(286.0, 520.0)
        .toDouble();

    return PopScope<void>(
      // Apenas o separador visível intercepta o botão Voltar. As restantes
      // OrbitBrowserScreens permanecem no IndexedStack, mas não podem
      // interferir no gesto/ação de voltar enquanto estão Offstage.
      canPop: !widget.isActive,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !widget.isActive) return;
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
              tooltip: 'Início',
              icon: Icon(Symbols.home_rounded, color: text),
              onPressed: () => ShellTabRequest.instance.request(0),
            ),
            titleSpacing: 0,
            title: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
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
                        _currentTitle.isNotEmpty
                            ? _currentTitle
                            : fallbackTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              AnimatedBuilder(
                animation: tabsController,
                builder: (context, _) => IconButton(
                  tooltip: 'Abas',
                  icon: _TabsCountIcon(
                    count: tabsController.count,
                    color: text,
                  ),
                  onPressed: _openTabsGrid,
                ),
              ),
              PopupMenuButton<_OrbitMenuAction>(
                tooltip: 'Mais opções',
                icon: Icon(Symbols.more_vert_rounded, color: text),
                position: PopupMenuPosition.under,
                alignment: AlignmentDirectional.topEnd,
                color: pillColor(context),
                surfaceTintColor: Colors.transparent,
                elevation: 14,
                shadowColor: Colors.black.withOpacity(.24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                menuPadding: const EdgeInsets.symmetric(vertical: 9),
                constraints: BoxConstraints(
                  minWidth: popupWidth,
                  maxWidth: popupWidth,
                ),
                popUpAnimationStyle: AnimationStyle(
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                  duration: const Duration(milliseconds: 270),
                  reverseDuration: const Duration(milliseconds: 190),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem<_OrbitMenuAction>(
                    enabled: false,
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OrbitShortcut(
                          icon: Icons.arrow_back_rounded,
                          enabled: _canGoBack,
                          onPressed: () =>
                              _triggerShortcut(_OrbitMenuAction.back),
                        ),
                        _OrbitShortcut(
                          icon: Icons.arrow_forward_rounded,
                          enabled: _canGoForward,
                          onPressed: () =>
                              _triggerShortcut(_OrbitMenuAction.forward),
                        ),
                        _OrbitShortcut(
                          icon: Icons.content_copy_rounded,
                          onPressed: () => _triggerShortcut(
                            _OrbitMenuAction.copyAddress,
                          ),
                        ),
                        _OrbitShortcut(
                          icon: Icons.info_outline_rounded,
                          onPressed: () =>
                              _triggerShortcut(_OrbitMenuAction.siteInfo),
                        ),
                        _OrbitShortcut(
                          icon: Icons.refresh_rounded,
                          onPressed: () =>
                              _triggerShortcut(_OrbitMenuAction.reload),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 9),
                  PopupMenuItem<_OrbitMenuAction>(
                    enabled: false,
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTitle.isEmpty ? fallbackTitle : _currentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _currentUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 9),
                  PopupMenuItem<_OrbitMenuAction>(
                    value: _OrbitMenuAction.reload,
                    child: const _OrbitMenuItem(
                      icon: Icons.refresh_rounded,
                      label: 'Atualizar página',
                    ),
                  ),
                  PopupMenuItem<_OrbitMenuAction>(
                    value: _OrbitMenuAction.copyAddress,
                    child: const _OrbitMenuItem(
                      icon: Icons.content_copy_rounded,
                      label: 'Copiar endereço',
                    ),
                  ),
                  PopupMenuItem<_OrbitMenuAction>(
                    value: _OrbitMenuAction.siteInfo,
                    child: const _OrbitMenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'Informações do site',
                    ),
                  ),
                  PopupMenuItem<_OrbitMenuAction>(
                    value: _OrbitMenuAction.openSearch,
                    child: const _OrbitMenuItem(
                      icon: Icons.search_rounded,
                      label: 'Pesquisar ou escrever endereço',
                    ),
                  ),
                  const PopupMenuDivider(height: 9),
                  PopupMenuItem<_OrbitMenuAction>(
                    value: _OrbitMenuAction.history,
                    child: const _OrbitMenuItem(
                      icon: Icons.history_rounded,
                      label: 'Histórico',
                    ),
                  ),
                  PopupMenuItem<_OrbitMenuAction>(
                    value: _OrbitMenuAction.goHome,
                    child: const _OrbitMenuItem(
                      icon: Icons.home_rounded,
                      label: 'Página inicial',
                    ),
                  ),
                ],
                onSelected: (action) => unawaited(_runShortcut(action)),
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
              useShouldOverrideUrlLoading: true,
              supportMultipleWindows: true,
              javaScriptCanOpenWindowsAutomatically: true,
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
              if (target == null) return false;
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
            onWebViewCreated: (controller) {
              _controller = controller;
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
              _updateTabState();
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
                screenshot = await controller
                    .takeScreenshot()
                    .timeout(const Duration(seconds: 2));
                if (navigationAcceleratorEnabled.value) {
                  html = await controller
                      .getHtml()
                      .timeout(const Duration(seconds: 2));
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
                        _loadError ??
                            'Não foi possível carregar esta página.',
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
          ),
      ],
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
  goHome,
  history,
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
