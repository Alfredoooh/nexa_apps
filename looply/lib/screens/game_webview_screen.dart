import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';

class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key, required this.game});
  final LooplyGame game;
  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  bool _isLoading = true;
  bool _renderProcessCrashed = false;
  String? _loadError;
  InAppWebViewController? _webController;
  Key _webViewKey = UniqueKey();

  @override
  void dispose() {
    _webController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: Text(widget.game.title)),
        body: Container(
          color: bg,
          child: Stack(children: [
            if (!_renderProcessCrashed)
              InAppWebView(
                key: _webViewKey,
                initialUrlRequest: URLRequest(url: WebUri(widget.game.url!)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  transparentBackground: true,
                  cacheMode: CacheMode.LOAD_DEFAULT,
                  hardwareAcceleration: true,
                ),
                shouldInterceptRequest: (controller, request) async {
                  final url = request.url.toString();
                  if (isAdBlockedUrl(url)) return WebResourceResponse(contentType: 'text/plain', data: Uint8List(0));
                  if (url == widget.game.url && (request.method == null || request.method == 'GET')) {
                    try {
                      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
                      if (response.statusCode == 200) return WebResourceResponse(contentType: 'text/html', contentEncoding: 'utf-8', data: response.bodyBytes);
                    } catch (_) {}
                  }
                  return null;
                },
                onWebViewCreated: (controller) => _webController = controller,
                onLoadStart: (_, __) { if (mounted) setState(() { _isLoading = true; _loadError = null; }); },
                onLoadStop: (_, __) { if (mounted) setState(() => _isLoading = false); },
                onReceivedError: (controller, request, error) {
                  if (request.isForMainFrame == true && mounted) setState(() { _isLoading = false; _loadError = error.description; });
                },
                onRenderProcessGone: (controller, detail) {
                  if (!mounted) return;
                  setState(() { _renderProcessCrashed = true; _isLoading = false; _loadError = 'O motor de navegação foi reiniciado.'; });
                },
              ),
            if (_isLoading && !_renderProcessCrashed) Container(color: bg.withOpacity(.92), child: Center(child: CircularProgressIndicator(color: accentColor(context)))),
            if (_renderProcessCrashed || _loadError != null)
              Positioned.fill(child: ColoredBox(color: bg, child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_renderProcessCrashed ? Symbols.refresh_rounded : Symbols.wifi_off_rounded, size: 42, color: mutedText(context)),
                const SizedBox(height: 12),
                Text(_loadError ?? 'Não foi possível abrir o jogo.', textAlign: TextAlign.center, style: TextStyle(color: mainText(context))),
                const SizedBox(height: 16),
                FilledButton(onPressed: () { setState(() { _renderProcessCrashed = false; _loadError = null; _isLoading = true; _webController = null; _webViewKey = UniqueKey(); }); }, child: const Text('Tentar novamente')),
              ]))))),
          ]),
        ),
      ),
    );
  }
}
