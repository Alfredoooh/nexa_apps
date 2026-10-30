import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';

// Tela de browser isolada, só para testar a Wikipedia. Diferente do
// browser principal, não tem endereço/voltar/avançar — mas agora FAZ
// PARTE do sistema de abas: aparece na grelha de Separadores via
// tabsController.upsertWikipediaTab(), conta no número de abas do
// bottom bar, e o botão "Abas" aqui encolhe para a grelha usando o
// morph de screenshot do main.dart — mas com ORIGEM NESTA TELA
// (ShellTabRequest.requestCloseWikipedia()), nunca na tela principal.
// Reaberta a partir do card na grelha, volta sempre a abrir esta mesma
// tela (nunca o BrowserScreen completo) — essa escolha é feita no
// main.dart, com base em tab.kind == TabKind.wikipedia.
const String _wikipediaUrl = 'https://www.wikipedia.org';

class WikipediaBrowserScreen extends StatefulWidget {
  const WikipediaBrowserScreen({super.key, this.viewportKey});
  // Key colocada à volta da área exata onde a InAppWebView fica, igual ao
  // viewportKey do BrowserScreen. O shell (main.dart) usa-a para medir o
  // Rect de origem/destino do morph quando esta tela é fechada para a
  // grelha de abas ou reaberta a partir do card na grelha.
  final GlobalKey? viewportKey;

  @override
  State<WikipediaBrowserScreen> createState() => _WikipediaBrowserScreenState();
}

class _WikipediaBrowserScreenState extends State<WikipediaBrowserScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0;
  String _currentTitle = '';
  bool _canGoBack = false;
  bool _renderProcessCrashed = false;
  String? _loadError;
  String? _tabId;

  @override
  void initState() {
    super.initState();
    // Regista (ou reaproveita) a aba única da Wikipédia assim que a tela
    // abre, para ela já aparecer corretamente na grelha e no contador do
    // bottom bar mesmo antes do primeiro screenshot existir.
    final existing = tabsController.getWikipediaTab();
    final tab = existing ?? tabsController.upsertWikipediaTab(null);
    _tabId = tab.id;
    tabsController.activate(tab.id);
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
    return true;
  }

  Future<Uint8List?> _captureScreenshot() async {
    try {
      return await _controller?.takeScreenshot();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openTabsGrid() async {
    // Captura o estado atual da WebView ANTES de pedir ao shell para
    // encolher esta tela para a grelha — assim o card já nasce com a
    // miniatura real, e o shell usa esta mesma screenshot como origem do
    // morph (esta tela encolhe, nunca a tela principal por baixo dela).
    final screenshot = await _captureScreenshot();
    final id = _tabId;
    if (id != null) {
      tabsController.updateTab(id, title: _currentTitle.isNotEmpty ? _currentTitle : 'Wikipédia', thumbnail: screenshot);
    } else {
      tabsController.upsertWikipediaTab(screenshot);
    }
    if (!mounted) return;
    ShellTabRequest.instance.requestCloseWikipedia(screenshot);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleBack() && mounted) Navigator.of(context).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Fechar',
              icon: Icon(Symbols.close_rounded, color: text),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              _currentTitle.isNotEmpty ? _currentTitle : 'Wikipédia',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w700),
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
            initialUrlRequest: URLRequest(url: WebUri(_wikipediaUrl)),
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
              if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'data' && scheme != 'blob') {
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
              });
            },
            onTitleChanged: (controller, title) {
              if (!mounted) return;
              setState(() => _currentTitle = title ?? '');
              final id = _tabId;
              if (id != null) tabsController.updateTab(id, title: _currentTitle.isNotEmpty ? _currentTitle : 'Wikipédia');
            },
            onLoadStop: (controller, url) async {
              bool back = false;
              Uint8List? screenshot;
              try {
                back = await controller.canGoBack();
                screenshot = await controller.takeScreenshot();
              } catch (_) {}
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _loadError = null;
                _canGoBack = back;
              });
              final id = _tabId;
              if (id != null) {
                tabsController.updateTab(id, title: _currentTitle.isNotEmpty ? _currentTitle : 'Wikipédia', thumbnail: screenshot);
              }
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame == true && mounted) {
                setState(() {
                  _isLoading = false;
                  _loadError = error.description;
                });
              }
            },
            onRenderProcessGone: (controller, detail) {
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
                          });
                          _controller?.reload();
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
    width: 23, height: 23, alignment: Alignment.center,
    decoration: BoxDecoration(border: Border.all(color: color.withOpacity(.85), width: 1.5), borderRadius: BorderRadius.circular(6)),
    child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, height: 1)),
  );
}