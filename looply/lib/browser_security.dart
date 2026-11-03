import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models.dart';

const MethodChannel _nativeAdBlockChannel = MethodChannel('looply/native_adblock');

/// Entrega a instalação do filtro ao Android antes da primeira navegação.
/// As requisições são avaliadas no worker nativo do WebView, sem passar pelo Dart.
Future<void> installNativeAdBlocker() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _nativeAdBlockChannel.invokeMethod<bool>('install');
  } on PlatformException {
    // A navegação continua disponível mesmo que uma versão do plugin não
    // permita a instalação do hook nativo.
  } on MissingPluginException {
    // iOS, desktop e builds sem a implementação Kotlin usam o caminho próprio.
  }
}

/// Android recebe uma regra sentinela (nunca corresponde a URLs) para manter
/// ativo o pipeline nativo de ContentBlocker do plugin. O handler Kotlin
/// substitui a implementação genérica e faz a filtragem sem pedidos HEAD.
/// WebKit continua a usar as regras por domínio do próprio ContentBlocker.
List<ContentBlocker> buildPlatformAdBlockers({bool enabled = true}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return <ContentBlocker>[
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: r'(?!)'),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    ];
  }

  if (!enabled ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS)) {
    return const <ContentBlocker>[];
  }

  final escaped = adBlockDomains.map(RegExp.escape).join('|');
  final filter =
      '^https?://(?:[^/?#]+\\.)*(?:$escaped)(?::[0-9]+)?(?:[/?#]|\$)';

  return <ContentBlocker>[
    ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: filter,
        resourceType: <ContentBlockerTriggerResourceType>[
          ContentBlockerTriggerResourceType.DOCUMENT,
          ContentBlockerTriggerResourceType.IMAGE,
          ContentBlockerTriggerResourceType.STYLE_SHEET,
          ContentBlockerTriggerResourceType.SCRIPT,
          ContentBlockerTriggerResourceType.FONT,
          ContentBlockerTriggerResourceType.MEDIA,
          ContentBlockerTriggerResourceType.SVG_DOCUMENT,
          ContentBlockerTriggerResourceType.RAW,
        ],
      ),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
  ];
}
