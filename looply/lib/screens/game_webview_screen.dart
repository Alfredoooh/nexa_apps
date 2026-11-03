import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../browser_security.dart';
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
  void initState() {
    super.initState();
    adBlockEnabled.addListener(_applyRuntimeSettings);
    navigationAcceleratorEnabled.addListener(_applyRuntimeSettings);
  }

  @override
  void dispose() {
    adBlockEnabled.removeListener(_applyRuntimeSettings);
    navigationAcceleratorEnabled.removeListener(_applyRuntimeSettings);
    _webController?.dispose();
    super.dispose();
  }

  void _applyRuntimeSettings() {
    final controller = _webController;
    if (controller == null || !mounted) return;
    controller.setSettings(
      settings: InAppWebViewSettings(
        cacheEnabled: navigationAcceleratorEnabled.value,
        cacheMode: navigationAcceleratorEnabled.value
            ? CacheMode.LOAD_DEFAULT
            : CacheMode.LOAD_NO_CACHE,
        contentBlockers: buildPlatformAdBlockers(enabled: adBlockEnabled.value),
      ),
    ).catchError((_) {});
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.game.title),
        ),
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
                  cacheEnabled: navigationAcceleratorEnabled.value,
                  cacheMode: navigationAcceleratorEnabled.value
                      ? CacheMode.LOAD_DEFAULT
                      : CacheMode.LOAD_NO_CACHE,
                  offscreenPreRaster: true,
                  contentBlockers: buildPlatformAdBlockers(enabled: adBlockEnabled.value),
                  hardwareAcceleration: true,
                ),
                onWebViewCreated: (controller) async {
                  _webController = controller;
                  await installNativeAdBlocker();
                  _applyRuntimeSettings();
                },
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
