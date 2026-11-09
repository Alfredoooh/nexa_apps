import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Tradução de página inteira através do endpoint web público do Google
/// Translate, sem chave de API e sem exibir a marca do Google na interface.
/// O endpoint não é uma API pública documentada; pode aplicar limites ou mudar.
class PageTranslateService {
  static const int _maxCharsPerChunk = 450;
  static const int _maxConcurrentRequests = 2;

  /// Recolhe os nós de texto visíveis, divide nós longos sem os truncar,
  /// traduz em pequenos lotes e devolve cada tradução ao respetivo nó DOM.
  static Future<bool> translateWebView({
    required InAppWebViewController controller,
    required String targetLanguageCode,
  }) async {
    final nodes = await _collectTextNodes(controller);
    if (nodes.isEmpty) return false;

    final chunks = _buildChunks(nodes);
    if (chunks.isEmpty) return false;

    final expectedParts = <String, int>{};
    for (final chunk in chunks) {
      for (final node in chunk.nodes) {
        expectedParts[node.id] = node.partCount;
      }
    }

    final translatedByNode = <String, Map<int, String>>{};
    final client = http.Client();
    try {
      for (var start = 0; start < chunks.length; start += _maxConcurrentRequests) {
        final batch = chunks.skip(start).take(_maxConcurrentRequests);
        await Future.wait(batch.map((chunk) async {
          final translated = await _translateChunk(
            client: client,
            chunk: chunk,
            targetLanguageCode: targetLanguageCode,
          );
          if (translated == null) return;

          for (var index = 0; index < chunk.nodes.length; index++) {
            final text = translated[index].trim();
            if (text.isEmpty) continue;
            final node = chunk.nodes[index];
            translatedByNode.putIfAbsent(node.id, () => <int, String>{})[node.partIndex] = text;
          }
        }));
      }
    } finally {
      client.close();
    }

    final replacements = <Map<String, String>>[];
    for (final entry in translatedByNode.entries) {
      final expected = expectedParts[entry.key] ?? 0;
      if (expected == 0 || entry.value.length != expected) continue;
      final orderedParts = <String>[];
      var complete = true;
      for (var index = 0; index < expected; index++) {
        final part = entry.value[index];
        if (part == null || part.isEmpty) {
          complete = false;
          break;
        }
        orderedParts.add(part);
      }
      if (!complete) continue;
      replacements.add(<String, String>{
        'id': entry.key,
        'text': orderedParts.join(' '),
      });
    }

    if (replacements.isEmpty) return false;
    await _applyTranslations(controller, replacements);
    return true;
  }

  static Future<List<_TextNodeRef>> _collectTextNodes(
    InAppWebViewController controller,
  ) async {
    final result = await controller.evaluateJavascript(source: r'''(() => {
      const skipTags = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEXTAREA', 'INPUT', 'CODE', 'PRE']);
      const nodes = [];
      let counter = 0;
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
        acceptNode(node) {
          const parent = node.parentElement;
          if (!parent || skipTags.has(parent.tagName)) return NodeFilter.FILTER_REJECT;
          const text = node.nodeValue.trim();
          if (text.length < 2) return NodeFilter.FILTER_REJECT;
          const style = getComputedStyle(parent);
          if (style.display === 'none' || style.visibility === 'hidden') return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      });
      let current;
      while ((current = walker.nextNode())) {
        const id = 'browseit-tx-' + (counter++);
        current.__browseitId = id;
        nodes.push({ id, text: current.nodeValue.trim() });
        if (!window.__browseitTxNodes) window.__browseitTxNodes = {};
        window.__browseitTxNodes[id] = current;
      }
      return JSON.stringify(nodes);
    })()''');

    if (result == null) return const [];
    try {
      final decoded = jsonDecode(result.toString()) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => _TextNodeRef(
                id: item['id'] as String,
                text: item['text'] as String,
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Divide nós grandes em partes completas de até 450 caracteres.
  /// Preferimos cortar junto de espaços/pontuação para evitar palavras partidas.
  static List<String> _splitLongText(String rawText) {
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return const [];
    if (text.length <= _maxCharsPerChunk) return <String>[text];

    final pieces = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = (start + _maxCharsPerChunk).clamp(0, text.length).toInt();
      if (end < text.length) {
        final boundary = text.lastIndexOf(RegExp(r'[\s.!?;,:]'), end - 1);
        if (boundary > start + 120) end = boundary + 1;
      }
      final piece = text.substring(start, end).trim();
      if (piece.isNotEmpty) pieces.add(piece);
      start = end;
    }
    return pieces;
  }

  /// Mantém o total de texto por pedido baixo e envia vários parâmetros `q`
  /// independentes, preservando a correspondência de cada resposta ao nó.
  static List<_TextChunk> _buildChunks(List<_TextNodeRef> nodes) {
    final chunks = <_TextChunk>[];
    var currentNodes = <_TextNodeRef>[];
    var currentLength = 0;

    void flush() {
      if (currentNodes.isEmpty) return;
      chunks.add(_TextChunk(List<_TextNodeRef>.unmodifiable(currentNodes)));
      currentNodes = <_TextNodeRef>[];
      currentLength = 0;
    }

    for (final node in nodes) {
      final pieces = _splitLongText(node.text);
      for (var index = 0; index < pieces.length; index++) {
        final piece = pieces[index];
        if (currentNodes.isNotEmpty && currentLength + piece.length > _maxCharsPerChunk) {
          flush();
        }
        currentNodes.add(_TextNodeRef(
          id: node.id,
          text: piece,
          partIndex: index,
          partCount: pieces.length,
        ));
        currentLength += piece.length;
      }
    }
    flush();
    return chunks;
  }

  static Future<List<String>?> _translateChunk({
    required http.Client client,
    required _TextChunk chunk,
    required String targetLanguageCode,
  }) async {
    try {
      // Google Translate Web usa GET e aceita q repetido quando a origem é auto.
      // Montamos a query manualmente para garantir parâmetros q independentes.
      final query = <String>[
        'client=${Uri.encodeQueryComponent('dict-chrome-ex')}',
        'sl=auto',
        'tl=${Uri.encodeQueryComponent(targetLanguageCode)}',
        ...chunk.nodes.map((node) => 'q=${Uri.encodeQueryComponent(node.text)}'),
      ].join('&');
      final uri = Uri.parse('https://translate.googleapis.com/translate_a/t?$query');

      var response = await client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 429 || response.statusCode == 503) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        response = await client.get(
          uri,
          headers: const <String, String>{'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 12));
      }
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      // Com sl=auto, cada item é [texto traduzido, idioma detetado].
      final translations = <String>[];
      for (final item in decoded) {
        if (item is! List || item.isEmpty || item.first is! String) return null;
        translations.add((item.first as String).trim());
      }
      if (translations.length != chunk.nodes.length) return null;
      return translations;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _applyTranslations(
    InAppWebViewController controller,
    List<Map<String, String>> replacements,
  ) async {
    final payload = jsonEncode(replacements);
    await controller.evaluateJavascript(source: '''(() => {
      try {
        const items = $payload;
        const registry = window.__browseitTxNodes || {};
        for (const item of items) {
          const node = registry[item.id];
          if (node) node.nodeValue = item.text;
        }
      } catch (_) {}
    })();''');
  }
}

class _TextNodeRef {
  const _TextNodeRef({
    required this.id,
    required this.text,
    this.partIndex = 0,
    this.partCount = 1,
  });

  final String id;
  final String text;
  final int partIndex;
  final int partCount;
}

class _TextChunk {
  const _TextChunk(this.nodes);
  final List<_TextNodeRef> nodes;
}
