import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Canal simples entre os ecrãs do navegador e o shell principal.
/// Permite pedir a abertura da grelha de abas ou mudar para um separador.
class ShellTabRequest extends ChangeNotifier {
  ShellTabRequest._();

  static final ShellTabRequest instance = ShellTabRequest._();

  bool tabsRequested = false;
  int? requestedIndex;

  // Pedido específico de fechamento vindo da própria WikipediaBrowserScreen
  // (botão "Abas" dela). Diferente de requestTabs(): aqui a origem do morph
  // de encolhimento para a grelha é a WikipediaBrowserScreen (medida via
  // _wikipediaViewportKey no shell), NUNCA a tela principal (_repaintKey).
  // O shell não faz popUntil(route.isFirst) para este caso — a rota da
  // Wikipédia só é removida depois de o morph já ter começado a animar,
  // para a screenshot de origem ser sempre a dela mesma, nunca da Home.
  bool wikipediaCloseRequested = false;
  Uint8List? wikipediaCloseScreenshot;

  void request(int index) {
    tabsRequested = false;
    wikipediaCloseRequested = false;
    wikipediaCloseScreenshot = null;
    requestedIndex = index;
    notifyListeners();
  }

  void requestTabs() {
    tabsRequested = true;
    wikipediaCloseRequested = false;
    wikipediaCloseScreenshot = null;
    requestedIndex = null;
    notifyListeners();
  }

  void requestCloseWikipedia(Uint8List? screenshot) {
    tabsRequested = false;
    requestedIndex = null;
    wikipediaCloseRequested = true;
    wikipediaCloseScreenshot = screenshot;
    notifyListeners();
  }
}