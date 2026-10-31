import 'package:flutter/material.dart';

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
