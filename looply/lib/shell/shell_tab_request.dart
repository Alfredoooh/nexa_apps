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

  bool browserHomeRequested = false;
  String? browserHomeTabId;
  Uint8List? browserHomeScreenshot;
  Rect? browserHomeSourceRect;

  int? requestedIndex;

  bool browserPreviewRequested = false;
  String? browserPreviewTabId;
  Uint8List? browserPreviewScreenshot;
  Rect? browserPreviewSourceRect;

  void _clearBrowserCloseRequest() {
    browserCloseRequested = false;
    browserCloseScreenshot = null;
    browserCloseSourceRect = null;
    browserCloseTabId = null;
  }

  void _clearBrowserHomeRequest() {
    browserHomeRequested = false;
    browserHomeTabId = null;
    browserHomeScreenshot = null;
    browserHomeSourceRect = null;
  }

  void request(int index) {
    clearBrowserPreviewRequest();
    _clearBrowserCloseRequest();
    _clearBrowserHomeRequest();
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    requestedIndex = index;
    notifyListeners();
  }

  void requestTabs() {
    clearBrowserPreviewRequest();
    _clearBrowserCloseRequest();
    _clearBrowserHomeRequest();
    tabsRequested = true;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    requestedIndex = null;
    notifyListeners();
  }

  void requestOrbitBrowser() {
    clearBrowserPreviewRequest();
    _clearBrowserCloseRequest();
    _clearBrowserHomeRequest();
    tabsRequested = false;
    orbitBrowserRequested = true;
    browserTabRequested = null;
    requestedIndex = null;
    notifyListeners();
  }

  void requestBrowser(String tabId) {
    clearBrowserPreviewRequest();
    _clearBrowserCloseRequest();
    _clearBrowserHomeRequest();
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = tabId;
    requestedIndex = null;
    notifyListeners();
  }

  void requestBrowserFromPreview({
    required String tabId,
    required Uint8List screenshot,
    required Rect? sourceRect,
  }) {
    _clearBrowserCloseRequest();
    _clearBrowserHomeRequest();
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    requestedIndex = null;
    browserPreviewRequested = true;
    browserPreviewTabId = tabId;
    browserPreviewScreenshot = screenshot;
    browserPreviewSourceRect = sourceRect;
    notifyListeners();
  }

  void clearBrowserPreviewRequest() {
    browserPreviewRequested = false;
    browserPreviewTabId = null;
    browserPreviewScreenshot = null;
    browserPreviewSourceRect = null;
  }

  void requestCloseBrowser({
    required String tabId,
    required Uint8List? screenshot,
    required Rect? sourceRect,
  }) {
    clearBrowserPreviewRequest();
    _clearBrowserHomeRequest();
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

  void requestBrowserToHome({
    required String tabId,
    required Uint8List? screenshot,
    required Rect? sourceRect,
  }) {
    clearBrowserPreviewRequest();
    _clearBrowserCloseRequest();
    tabsRequested = false;
    orbitBrowserRequested = false;
    browserTabRequested = null;
    requestedIndex = null;
    browserHomeRequested = true;
    browserHomeTabId = tabId;
    browserHomeScreenshot = screenshot;
    browserHomeSourceRect = sourceRect;
    notifyListeners();
  }

  void clearBrowserHomeRequest() {
    _clearBrowserHomeRequest();
  }
}
