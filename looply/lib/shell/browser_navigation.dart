import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models.dart';
import 'shell_tab_request.dart';

/// Cria uma aba de navegador e solicita à shell que a apresente.
/// As rotas temporárias (Pesquisa, Todos os sites, Histórico) são fechadas
/// primeiro; a instância Orbit fica depois preservada no IndexedStack.
BrowserTab openOrbitTab(
  BuildContext context,
  String url, {
  String? title,
}) {
  final tab = tabsController.createBrowserTab(url);
  tabsController.activate(tab.id);
  activityController.log(ActivityKind.site, title ?? url, url);

  Navigator.of(context).popUntil((route) => route.isFirst);
  ShellTabRequest.instance.requestBrowser(tab.id);
  return tab;
}

/// Abre a aba única do Orbit Browser através da sua instância persistente.
void openOrbitBrowserTab(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  ShellTabRequest.instance.requestOrbitBrowser();
}

/// Envia dicas de DNS/TLS e prefetch ao motor Chromium da própria WebView.
/// Diferente de um HTTP HEAD feito pelo Dart, estes hints usam o mesmo motor
/// de rede que fará a navegação real.
class BrowserPreconnectHints {
  BrowserPreconnectHints._();

  static final Map<String, InAppWebViewController> _controllers =
      <String, InAppWebViewController>{};
  static String? _lastControllerId;
  static final Set<String> _hintedOrigins = <String>{};

  static void attach(String tabId, InAppWebViewController controller) {
    _controllers[tabId] = controller;
    _lastControllerId = tabId;
  }

  static void setActive(String tabId, bool active) {
    if (active && _controllers.containsKey(tabId)) {
      _lastControllerId = tabId;
    }
  }

  static void detach(String tabId) {
    _controllers.remove(tabId);
    if (_lastControllerId == tabId) {
      _lastControllerId = _controllers.keys.isEmpty
          ? null
          : _controllers.keys.last;
    }
  }

  static Future<void> preconnect(String target) async {
    if (!navigationAcceleratorEnabled.value) return;
    final uri = Uri.tryParse(target);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return;
    }

    final origin = uri.origin;
    final controller = _lastControllerId == null
        ? null
        : _controllers[_lastControllerId!];
    if (controller == null) return;

    if (!_hintedOrigins.add(origin)) return;
    if (_hintedOrigins.length > 80) _hintedOrigins.clear();

    final originJson = jsonEncode(origin);
    final targetJson = jsonEncode(uri.toString());
    final script = '''
      (() => {
        try {
          const head = document.head || document.documentElement;
          if (!head) return false;
          const addHint = (rel, href, crossOrigin) => {
            const exists = Array.from(document.querySelectorAll('link[rel]'))
              .some(link => link.rel === rel && link.href === href);
            if (exists) return;
            const link = document.createElement('link');
            link.rel = rel;
            link.href = href;
            if (crossOrigin) link.crossOrigin = 'anonymous';
            head.appendChild(link);
          };
          const origin = $originJson;
          const target = $targetJson;
          addHint('dns-prefetch', origin, false);
          addHint('preconnect', origin, true);
          if (target.startsWith(origin + '/') && target !== location.href) {
            addHint('prefetch', target, false);
          }
          return true;
        } catch (_) { return false; }
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
    } catch (_) {
      // A página pode ainda estar a arrancar ou o separador pode estar oculto.
    }
  }
}
