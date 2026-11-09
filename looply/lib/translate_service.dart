import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Tradução de página inteira via API pública (MyMemory), sem chave e sem
/// o widget flutuante do Google Translate. A API tem um limite prático de
/// ~500 caracteres por requisição, por isso o texto da página é dividido
/// em blocos de nós de texto do DOM, traduzido em grupos com concorrência
/// limitada, e cada bloco é substituído assim que a sua tradução volta —
/// a página vai sendo traduzida progressivamente em vez de tudo de uma vez
/// no fim, e nenhum trecho fica de fora por exceder o limite de um único
/// pedido.
class PageTranslateService {
  static const int _maxCharsPerChunk = 450;
  static const int _maxConcurrentRequests = 4;

  /// Extrai os nós de texto visíveis da página, agrupa-os em blocos que
  /// cabem no limite da API, traduz cada bloco e escreve o resultado de
  /// volta no DOM assim que chega — sem esperar a página inteira terminar.
  static Future<void> translateWebView({
    required InAppWebViewController controller,
    required String targetLanguageCode,
  }) async {
    final nodes = await _collectTextNodes(controller);
    if (nodes.isEmpty) return;

    final chunks = _buildChunks(nodes);
    if (chunks.isEmpty) return;

    final client = http.Client();
    try {
      // Processa os blocos em grupos de _maxConcurrentRequests em paralelo,
      // em vez de todos de uma vez (evitando sobrecarregar a API pública
      // e levar a respostas 429) ou um de cada vez (demasiado lento numa
      // página com muito texto).
      for (var start = 0; start < chunks.length; start += _maxConcurrentRequests) {
        final batch = chunks.skip(start).take(_maxConcurrentRequests);
        await Future.wait(batch.map((chunk) async {
          final translated = await _translateChunk(
            client: client,
            chunk: chunk,
            targetLanguageCode: targetLanguageCode,
          );
          if (translated != null) {
            await _applyChunkTranslation(controller, chunk, translated);
          }
        }));
      }
    } finally {
      client.close();
    }
  }

  static Future<List<_TextNodeRef>> _collectTextNodes(InAppWebViewController controller) async {
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
        current.parentElement.dataset.browseitTxHolder = current.parentElement.dataset.browseitTxHolder || '1';
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
          .map((item) => _TextNodeRef(id: item['id'] as String, text: item['text'] as String))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Agrupa nós de texto em blocos cujo tamanho total não ultrapassa o
  /// limite por requisição, preservando a correspondência id→texto para
  /// poder repor cada tradução no nó certo do DOM depois.
  static List<_TextChunk> _buildChunks(List<_TextNodeRef> nodes) {
    final chunks = <_TextChunk>[];
    var currentNodes = <_TextNodeRef>[];
    var currentLength = 0;
    const separator = '\n§§\n';

    for (final node in nodes) {
      final addedLength = node.text.length + separator.length;
      if (currentNodes.isNotEmpty && currentLength + addedLength > _maxCharsPerChunk) {
        chunks.add(_TextChunk(currentNodes));
        currentNodes = [];
        currentLength = 0;
      }
      // Um único nó maior que o limite é truncado para a própria
      // requisição não ser rejeitada pela API — melhor traduzir parte do
      // texto do que nenhuma.
      if (node.text.length > _maxCharsPerChunk) {
        chunks.add(_TextChunk([_TextNodeRef(id: node.id, text: node.text.substring(0, _maxCharsPerChunk))]));
        continue;
      }
      currentNodes.add(node);
      currentLength += addedLength;
    }
    if (currentNodes.isNotEmpty) chunks.add(_TextChunk(currentNodes));
    return chunks;
  }

  static Future<List<String>?> _translateChunk({
    required http.Client client,
    required _TextChunk chunk,
    required String targetLanguageCode,
  }) async {
    const separator = '\n§§\n';
    final joined = chunk.nodes.map((node) => node.text).join(separator);

    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': joined,
        'langpair': 'autodetect|$targetLanguageCode',
      });
      final response = await client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final translatedText = decoded['responseData']?['translatedText'] as String?;
      if (translatedText == null || translatedText.isEmpty) return null;

      final parts = translatedText.split(RegExp(r'\n\s*§§\s*\n|\n§§\n'));
      // Se a API colapsar ou reordenar o separador de forma inesperada, o
      // número de partes não bate com o número de nós enviados — nesse
      // caso é mais seguro não aplicar nada a esse bloco do que aplicar
      // traduções trocadas em nós errados.
      if (parts.length != chunk.nodes.length) return null;
      return parts.map((part) => part.trim()).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _applyChunkTranslation(
    InAppWebViewController controller,
    _TextChunk chunk,
    List<String> translatedParts,
  ) async {
    final replacements = <Map<String, String>>[];
    for (var i = 0; i < chunk.nodes.length; i++) {
      if (translatedParts[i].isEmpty) continue;
      replacements.add({'id': chunk.nodes[i].id, 'text': translatedParts[i]});
    }
    if (replacements.isEmpty) return;

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
  const _TextNodeRef({required this.id, required this.text});
  final String id;
  final String text;
}

class _TextChunk {
  const _TextChunk(this.nodes);
  final List<_TextNodeRef> nodes;
}