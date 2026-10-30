import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';
import 'home_screen.dart';

// O browser entra sem uma transição de rota que altere a composição da
// PlatformView. A animação entre o ecrã principal e a grelha de abas é
// feita no shell, sem capturar imagens da WebView.
PageRoute<void> openBrowserRoute({required String tabId, required String initialUrl}) {
  return PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => BrowserScreen(
      tabId: tabId,
      initialUrl: initialUrl,
    ),
  );
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.tabId, required this.initialUrl});
  final String tabId;
  final String initialUrl;
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
  Timer? _grayCheckTimer;
  int _navigationSequence = 0;
  bool _showGrayDiagnostic = false;
  bool _useOpaqueWebView = false;
  double _diagnosticGrayCoverage = 0;
  Color _diagnosticGrayColor = const Color(0xFFBDBDBD);
  _PageDomInfo? _diagnosticDomInfo;
  bool _diagnosticWasStillLoading = false;

  @override
  void initState() {
    super.initState();
    final existingTab = tabsController.getTab(widget.tabId);
    _currentUrl = (existingTab != null && existingTab.url.isNotEmpty) ? existingTab.url : widget.initialUrl;
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
    _grayCheckTimer?.cancel();
    _controller?.dispose();
    super.dispose();
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
    if (_showGrayDiagnostic) {
      _updateTabState();
      return true;
    }
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
            body: _showGrayDiagnostic
                ? _buildGrayDiagnostic(context)
                : Column(children: [
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
                child: ColoredBox(color: bg, child: _buildBrowserWebView(context)),
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

  void _scheduleGrayScreenCheck(
    InAppWebViewController controller,
    int sequence, {
    Duration delay = const Duration(milliseconds: 1800),
    bool allowWhileLoading = false,
  }) {
    _grayCheckTimer?.cancel();
    _grayCheckTimer = Timer(delay, () {
      unawaited(_detectPersistentGrayScreen(
        controller,
        sequence,
        allowWhileLoading: allowWhileLoading,
      ));
    });
  }

  Future<void> _detectPersistentGrayScreen(
    InAppWebViewController controller,
    int sequence, {
    required bool allowWhileLoading,
  }) async {
    if (!mounted || sequence != _navigationSequence ||
        (_isLoading && !allowWhileLoading) ||
        _showGrayDiagnostic || !identical(controller, _controller)) {
      return;
    }

    Uint8List? firstScreenshot;
    try {
      firstScreenshot = await controller.takeScreenshot();
    } catch (_) {
      return;
    }
    if (firstScreenshot == null || firstScreenshot.isEmpty) return;

    final firstAnalysis = await _analyzeGrayScreenshot(firstScreenshot);
    if (firstAnalysis == null || !firstAnalysis.looksLikeGrayScreen) return;

    // Uma segunda captura impede que um frame cinzento transitório durante a
    // composição da WebView seja confundido com uma falha persistente.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || sequence != _navigationSequence ||
        (_isLoading && !allowWhileLoading) || _showGrayDiagnostic ||
        !identical(controller, _controller)) {
      return;
    }

    Uint8List? secondScreenshot;
    try {
      secondScreenshot = await controller.takeScreenshot();
    } catch (_) {
      return;
    }
    if (secondScreenshot == null || secondScreenshot.isEmpty) return;

    final secondAnalysis = await _analyzeGrayScreenshot(secondScreenshot);
    if (secondAnalysis == null || !secondAnalysis.looksLikeGrayScreen) return;

    final domInfo = await _readPageDomInfo(controller);
    if (!mounted || sequence != _navigationSequence ||
        !identical(controller, _controller)) {
      return;
    }

    setState(() {
      _showGrayDiagnostic = true;
      _diagnosticGrayCoverage = secondAnalysis.dominantCoverage;
      _diagnosticGrayColor = secondAnalysis.dominantColor;
      _diagnosticDomInfo = domInfo;
      _diagnosticWasStillLoading = _isLoading;
    });
  }

  Future<_GrayScreenAnalysis?> _analyzeGrayScreenshot(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 40,
        targetHeight: 40,
      );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final bins = <int, int>{};
      var opaqueSamples = 0;
      const sampleSide = 40;
      for (var sampleY = 0; sampleY < sampleSide; sampleY++) {
        final y = (sampleY * image.height / sampleSide).floor();
        for (var sampleX = 0; sampleX < sampleSide; sampleX++) {
          final x = (sampleX * image.width / sampleSide).floor();
          final offset = (y * image.width + x) * 4;
          final alpha = byteData.getUint8(offset + 3);
          if (alpha < 180) continue;

          final red = byteData.getUint8(offset);
          final green = byteData.getUint8(offset + 1);
          final blue = byteData.getUint8(offset + 2);
          final key = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4);
          bins[key] = (bins[key] ?? 0) + 1;
          opaqueSamples++;
        }
      }

      // Capturas quase transparentes não são consideradas um ecrã cinzento.
      if (opaqueSamples < 500 || bins.isEmpty) return null;

      var dominantKey = 0;
      var dominantCount = 0;
      bins.forEach((key, count) {
        if (count > dominantCount) {
          dominantKey = key;
          dominantCount = count;
        }
      });

      final red = (((dominantKey >> 8) & 0xF) * 16) + 8;
      final green = (((dominantKey >> 4) & 0xF) * 16) + 8;
      final blue = ((dominantKey & 0xF) * 16) + 8;
      final coverage = dominantCount / opaqueSamples;
      final isNeutral = (red - green).abs() <= 20 &&
          (green - blue).abs() <= 20 &&
          (red - blue).abs() <= 20;
      final luminance = (red + green + blue) / 3;

      return _GrayScreenAnalysis(
        dominantCoverage: coverage,
        dominantColor: Color.fromARGB(255, red, green, blue),
        looksLikeGrayScreen: coverage >= 0.94 &&
            isNeutral &&
            luminance >= 45 &&
            luminance <= 248,
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<_PageDomInfo?> _readPageDomInfo(
    InAppWebViewController controller,
  ) async {
    try {
      final dynamic result = await controller.evaluateJavascript(source: '''
        (function() {
          const body = document.body;
          const root = document.documentElement;
          const textLength = body ? (body.innerText || '').trim().length : 0;
          const elementCount = body
            ? body.querySelectorAll('img, video, canvas, svg, iframe, button, a').length
            : 0;
          return JSON.stringify({
            readyState: document.readyState || 'desconhecido',
            textLength: textLength,
            elementCount: elementCount,
            bodyBackground: body ? getComputedStyle(body).backgroundColor : 'indisponível',
            rootBackground: root ? getComputedStyle(root).backgroundColor : 'indisponível'
          });
        })();
      ''');

      Map<String, dynamic>? values;
      if (result is String) {
        final decoded = jsonDecode(result);
        if (decoded is Map) values = Map<String, dynamic>.from(decoded);
      } else if (result is Map) {
        values = Map<String, dynamic>.from(result);
      }
      if (values == null) return null;

      return _PageDomInfo(
        readyState: values['readyState']?.toString() ?? 'desconhecido',
        textLength: int.tryParse(values['textLength']?.toString() ?? '') ?? 0,
        elementCount: int.tryParse(
              values['elementCount']?.toString() ?? '',
            ) ??
            0,
        bodyBackground: values['bodyBackground']?.toString() ?? 'indisponível',
        rootBackground: values['rootBackground']?.toString() ?? 'indisponível',
      );
    } catch (_) {
      return null;
    }
  }

  void _retryWithOpaqueBackground() {
    _grayCheckTimer?.cancel();
    final retryUrl = _currentUrl;
    setState(() {
      _navigationSequence++;
      _showGrayDiagnostic = false;
      _diagnosticDomInfo = null;
      _diagnosticWasStillLoading = false;
      _renderProcessCrashed = false;
      _loadError = null;
      _isLoading = true;
      _progress = 0;
      _canGoBack = false;
      _canGoForward = false;
      _useOpaqueWebView = true;
      _controller = null;
      _currentUrl = retryUrl;
      _webViewKey = UniqueKey();
    });
  }

  Widget _buildGrayDiagnostic(BuildContext context) {
    final background = pageBg(context);
    final surface = panelColor(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final info = _diagnosticDomInfo;
    final domHasContent = info != null &&
        (info.textLength > 30 || info.elementCount >= 3);
    final host = Uri.tryParse(_currentUrl)?.host;
    final grayPercent = (_diagnosticGrayCoverage * 100).round();
    final colorHex = '#${_diagnosticGrayColor.red.toRadixString(16).padLeft(2, '0')}${_diagnosticGrayColor.green.toRadixString(16).padLeft(2, '0')}${_diagnosticGrayColor.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 54, color: accentColor(context)),
                  const SizedBox(height: 18),
                  Text(
                    'Ecrã cinzento detectado',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A página terminou o carregamento, mas a área do site permaneceu praticamente toda cinzenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: lineColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.search_rounded, color: accentColor(context), size: 20),
                          const SizedBox(width: 9),
                          Text('Causa provável', style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          _renderProcessCrashed
                              ? 'O processo de renderização do Android WebView foi encerrado ou reiniciado. Isso aponta para uma falha do motor do navegador ou do processo gráfico do dispositivo.'
                              : _loadError != null
                                  ? 'O Android WebView reportou um erro de carregamento: $_loadError. Isto aponta primeiro para um problema de rede, DNS, certificado ou resposta do servidor. A captura cinzenta pode ser um efeito desse erro.'
                                  : domHasContent
                                      ? 'O site respondeu e contém dados na página, mas esses dados não foram desenhados no ecrã. Isto aponta para uma falha de renderização/composição do Android System WebView ou do processo gráfico do dispositivo. A camada transparente da WebView também pode estar envolvida.'
                                      : _diagnosticWasStillLoading
                                          ? 'A página permaneceu cinzenta e continuou em carregamento durante vários segundos. As causas mais prováveis são ligação/DNS lento ou bloqueado, servidor sem resposta, scripts que impedem a conclusão do carregamento ou falha do motor WebView.'
                                          : 'A WebView não apresentou conteúdo suficiente no documento. As possibilidades incluem falha de rede ou DNS, scripts do site que não terminaram, bloqueio de recursos ou falha do motor de renderização. A cor, sozinha, não permite confirmar uma causa única.',
                          style: TextStyle(color: text, fontSize: 13, height: 1.55),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: lineColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.terminal_rounded, color: accentColor(context), size: 20),
                          const SizedBox(width: 9),
                          Text('Dados do diagnóstico', style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                        const SizedBox(height: 13),
                        _DiagnosticRow(
                          label: 'Site',
                          value: host?.isNotEmpty == true ? host! : _currentUrl,
                          textColor: text,
                          mutedColor: muted,
                        ),
                        _DiagnosticRow(
                          label: 'Captura cinzenta',
                          value: '$grayPercent% do ecrã',
                          textColor: text,
                          mutedColor: muted,
                        ),
                        if (_loadError != null)
                          _DiagnosticRow(
                            label: 'Erro reportado',
                            value: _loadError!,
                            textColor: text,
                            mutedColor: muted,
                          ),
                        _DiagnosticRow(
                          label: 'Tom predominante',
                          value: '$colorHex (RGB)',
                          textColor: text,
                          mutedColor: muted,
                          trailing: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _diagnosticGrayColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: muted.withOpacity(.3)),
                            ),
                          ),
                        ),
                        if (info != null) ...[
                          _DiagnosticRow(label: 'Documento', value: info.readyState, textColor: text, mutedColor: muted),
                          _DiagnosticRow(label: 'Caracteres de texto', value: '${info.textLength}', textColor: text, mutedColor: muted),
                          _DiagnosticRow(label: 'Elementos na página', value: '${info.elementCount}', textColor: text, mutedColor: muted),
                          _DiagnosticRow(label: 'Fundo HTML', value: info.bodyBackground, textColor: text, mutedColor: muted),
                          _DiagnosticRow(label: 'Fundo do documento', value: info.rootBackground, textColor: text, mutedColor: muted),
                        ] else
                          Text('A página não permitiu recolher todos os dados internos.', style: TextStyle(color: muted, fontSize: 12, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _retryWithOpaqueBackground,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_useOpaqueWebView ? 'Recarregar página' : 'Tentar correção e recarregar'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await _handleBack() && mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Fechar navegador'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: text),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'O Looply verificou duas capturas consecutivas depois do carregamento. O diagnóstico indica a causa mais provável, mas não substitui os registos internos do Android WebView.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11, height: 1.45),
                  ),
                ],
              ),
            ),
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
              // Igual à versão antiga que carregava as páginas corretamente.
              // O fundo transparente evita que a WebView mostre o cinzento
              // nativo enquanto o primeiro frame HTML ainda não foi pintado.
              transparentBackground: !_useOpaqueWebView,
              cacheMode: CacheMode.LOAD_DEFAULT,
              hardwareAcceleration: true,
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
              _grayCheckTimer?.cancel();
              _navigationSequence++;
              setState(() {
                _showGrayDiagnostic = false;
                _diagnosticDomInfo = null;
                _diagnosticWasStillLoading = false;
                _isLoading = true;
                _loadError = null;
                if (url != null) _currentUrl = url.toString();
              });
              _scheduleGrayScreenCheck(
                controller,
                _navigationSequence,
                delay: const Duration(seconds: 8),
                allowWhileLoading: true,
              );
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
                if (navigationAcceleratorEnabled.value) html = await controller.getHtml();
              } catch (_) {}
              if (html != null && navigationAcceleratorEnabled.value) {
                NavAccelerator.instance.cachePage(url?.toString() ?? _currentUrl, html);
              }
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _loadError = null;
                _canGoBack = back;
                _canGoForward = forward;
                if (url != null) _currentUrl = url.toString();
              });
              _updateTabState(screenshot: screenshot);
              _scheduleGrayScreenCheck(controller, _navigationSequence);
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
            onRenderProcessGone: (controller, detail) {
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

class _GrayScreenAnalysis {
  const _GrayScreenAnalysis({
    required this.dominantCoverage,
    required this.dominantColor,
    required this.looksLikeGrayScreen,
  });

  final double dominantCoverage;
  final Color dominantColor;
  final bool looksLikeGrayScreen;
}

class _PageDomInfo {
  const _PageDomInfo({
    required this.readyState,
    required this.textLength,
    required this.elementCount,
    required this.bodyBackground,
    required this.rootBackground,
  });

  final String readyState;
  final int textLength;
  final int elementCount;
  final String bodyBackground;
  final String rootBackground;
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: mutedColor, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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