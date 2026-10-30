import 'package:flutter/foundation.dart';

class ShellTabRequest extends ChangeNotifier {
  ShellTabRequest._();
  static final ShellTabRequest instance = ShellTabRequest._();
  int? requestedIndex;
  bool tabsRequested = false;

  void request(int index) {
    requestedIndex = index;
    tabsRequested = false;
    notifyListeners();
  }

  void requestTabs() {
    requestedIndex = null;
    tabsRequested = true;
    notifyListeners();
  }
}
