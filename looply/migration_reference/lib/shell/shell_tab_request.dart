import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// Canal de comunicação entre o navegador persistente e a shell principal.
/// Todas as abas Orbit ficam montadas no IndexedStack; este canal apenas
/// altera a aba ativa ou pede a abertura da grelha de separadores.
class ShellTabRequest extends ChangeNotifier {
  ShellTabRequest._();

  static final ShellTabRequest instance = ShellTabRequest._();

  bool tabsRequested = false;
  bool orbitBrowserRequested = false;
  String? browserTabRequested;

  bool browserCloseRequested = false;
  Uint8List? browserCloseScreenshot;
  Rect? browserCloseSourceRect;
  String? browserCloseTabId;

  int? requestedIndex;

  void _clearBrowserCloseRequest() {
    browserCloseRequested = false;
    browserCloseScreenshot = null;
    browserCloseSourceRect = null;
    browserCloseTabId = null;
  }

  void request(int index) {
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    _clearBrowserCloseRequest();
    requestedIndex = index;
    notifyListeners();
  }

  void requestTabs() {
    tabsRequested = true;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    _clearBrowserCloseRequest();
    requestedIndex = null;
    notifyListeners();
  }

  void requestOrbitBrowser() {
    tabsRequested = false;
    orbitBrowserRequested = true;
    browserTabRequested = null;
    _clearBrowserCloseRequest();
    requestedIndex = null;
    notifyListeners();
  }

  void requestBrowser(String tabId) {
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = tabId;
    _clearBrowserCloseRequest();
    requestedIndex = null;
    notifyListeners();
  }

  void requestCloseBrowser({
    required String tabId,
    required Uint8List? screenshot,
    required Rect? sourceRect,
  }) {
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    requestedIndex = null;
    browserCloseRequested = true;
    browserCloseScreenshot = screenshot;
    browserCloseSourceRect = sourceRect;
    browserCloseTabId = tabId;
    notifyListeners();
  }
}
