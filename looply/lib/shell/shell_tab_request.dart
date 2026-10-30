import 'package:flutter/foundation.dart';

/// Canal simples entre os ecrãs do navegador e o shell principal.
/// Permite pedir a abertura da grelha de abas ou mudar para um separador.
class ShellTabRequest extends ChangeNotifier {
  ShellTabRequest._();

  static final ShellTabRequest instance = ShellTabRequest._();

  bool tabsRequested = false;
  int? requestedIndex;

  void request(int index) {
    tabsRequested = false;
    requestedIndex = index;
    notifyListeners();
  }

  void requestTabs() {
    tabsRequested = true;
    requestedIndex = null;
    notifyListeners();
  }
}
