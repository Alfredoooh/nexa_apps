import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'models.dart';

/// Constrói regras nativas para WebKit. No Android, a contagem exata é feita
/// em shouldInterceptRequest, pois ContentBlocker não emite callback quando
/// bloqueia um recurso.
List<ContentBlocker> buildPlatformAdBlockers() {
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return const <ContentBlocker>[];
  }

  final escaped = adBlockDomains.map(RegExp.escape).join('|');
  final filter =
      '^https?://(?:[^/?#]+\\.)?(?:$escaped)(?::[0-9]+)?(?:[/?#]|$)';

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

/// Intercepta uma requisição de sub-recurso no Android WebView. A navegação
/// principal nunca é bloqueada, mesmo que o próprio site esteja numa lista.
WebResourceResponse? interceptAdRequest(
  WebResourceRequest request, {
  bool persistStats = true,
}) {
  if (request.isForMainFrame == true) return null;

  final url = request.url.toString();
  if (!isAdBlockedUrl(url)) return null;

  if (persistStats) AdBlockStats.instance.registerBlock();

  return WebResourceResponse(
    contentType: 'text/plain',
    contentEncoding: 'utf-8',
    data: Uint8List(0),
    statusCode: 204,
    reasonPhrase: 'No Content',
    headers: const <String, String>{
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': '*',
    },
  );
}
