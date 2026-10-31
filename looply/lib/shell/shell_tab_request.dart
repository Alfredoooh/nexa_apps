import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// Canal simples entre os ecrãs do navegador e o shell principal.
/// Permite pedir a abertura da grelha de abas ou mudar para um separador.
class ShellTabRequest extends ChangeNotifier {
  ShellTabRequest._();

  static final ShellTabRequest instance = ShellTabRequest._();

  bool tabsRequested = false;
  bool wikipediaRequested = false;
  bool browserCloseRequested = false;
  Uint8List? browserCloseScreenshot;
  Rect? browserCloseSourceRect;
  String? browserCloseTabId;
  int? requestedIndex;

  // Pedido específico vindo do botão Abas da página persistente Wikipédia.
  // O shell mede o viewport dela e a mantém montada no IndexedStack durante
  // toda a animação e enquanto a grelha estiver visível.
  bool wikipediaCloseRequested = false;
  Uint8List? wikipediaCloseScreenshot;

  void request(int index) {
    tabsRequested = false;
    wikipediaRequested = false;
    wikipediaCloseRequested = false;
    wikipediaCloseScreenshot = null;
    browserCloseRequested = false;
    browserCloseScreenshot = null;
    browserCloseSourceRect = null;
    browserCloseTabId = null;
    requestedIndex = index;
    notifyListeners();
  }

  void requestTabs() {
    tabsRequested = true;
    wikipediaRequested = false;
    wikipediaCloseRequested = false;
    wikipediaCloseScreenshot = null;
    browserCloseRequested = false;
    browserCloseScreenshot = null;
    browserCloseSourceRect = null;
    browserCloseTabId = null;
    requestedIndex = null;
    notifyListeners();
  }

  void requestWikipedia() {
    tabsRequested = false;
    wikipediaRequested = true;
    wikipediaCloseRequested = false;
    wikipediaCloseScreenshot = null;
    browserCloseRequested = false;
    browserCloseScreenshot = null;
    browserCloseSourceRect = null;
    browserCloseTabId = null;
    requestedIndex = null;
    notifyListeners();
  }

  void requestCloseWikipedia(Uint8List? screenshot) {
    tabsRequested = false;
    wikipediaRequested = false;
    requestedIndex = null;
    wikipediaCloseRequested = true;
    wikipediaCloseScreenshot = screenshot;
    browserCloseRequested = false;
    browserCloseScreenshot = null;
    browserCloseSourceRect = null;
    browserCloseTabId = null;
    notifyListeners();
  }

  void requestCloseBrowser({
    required String tabId,
    required Uint8List? screenshot,
    required Rect? sourceRect,
  }) {
    tabsRequested = false;
    wikipediaRequested = false;
    requestedIndex = null;
    wikipediaCloseRequested = false;
    wikipediaCloseScreenshot = null;
    browserCloseRequested = true;
    browserCloseScreenshot = screenshot;
    browserCloseSourceRect = sourceRect;
    browserCloseTabId = tabId;
    notifyListeners();
  }
}