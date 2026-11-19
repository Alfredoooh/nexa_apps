import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../cloud_sync.dart';

/// Imagem anexada a um pedido de pesquisa com IA.
class BrowseItAiImage {
  const BrowseItAiImage({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Cliente HTTP da pesquisa com IA.
///
/// O endereço é fornecido no build, sem embutir chaves privadas no APK:
/// --dart-define=BROWSEIT_AI_SEARCH_URL=https://teu-worker.example/api/ai/search
///
/// Contrato: POST JSON com query, anexos multimodais em attachments[],
/// instruções Markdown e schemas dos widgets. O servidor deve descodificar
/// data_base64 e encaminhar as imagens ao modelo multimodal.
/// Resposta JSON {answer: Markdown} ou SSE compatível com OpenAI.
/// O serviço não inclui chaves privadas no APK nem assume uma rota inexistente.
class BrowseItAiSearchService {
  BrowseItAiSearchService._();

  static const String _endpoint = String.fromEnvironment(
    'BROWSEIT_AI_SEARCH_URL',
    defaultValue: '',
  );

  static bool get isConfigured => _endpoint.trim().isNotEmpty;

  static Future<String> search(
    String query, {
    List<BrowseItAiImage> images = const <BrowseItAiImage>[],
    void Function(String token)? onToken,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) throw ArgumentError('A pesquisa está vazia.');
    if (!isConfigured) {
      throw StateError(
        'A pesquisa com IA ainda não está ligada a um servidor. '
        'Define BROWSEIT_AI_SEARCH_URL no build do Android.',
      );
    }

    final uri = Uri.tryParse(_endpoint.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.scheme != 'https') {
      throw StateError('BROWSEIT_AI_SEARCH_URL tem de ser um endereço HTTPS válido.');
    }

    final client = http.Client();
    try {
      final authorization = await BrowseItCloudSync.aiAuthorizationHeaders();
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Accept': 'application/json, text/event-stream',
          'Content-Type': 'application/json; charset=utf-8',
          ...authorization,
        })
        ..body = jsonEncode({
          'query': cleanQuery,
          'attachments': images
              .map((image) => <String, Object>{
                    'type': 'image',
                    'name': image.name,
                    'mime_type': image.mimeType,
                    'data_base64': base64Encode(image.bytes),
                  })
              .toList(growable: false),
          'stream': true,
          'format': 'markdown',
          'rich_widgets': true,
          'rich_text_version': 2,
          'supported_widgets': const [
            'widget_market',
            'widget_calendar',
            'widget_map',
            'widget_chart',
            'widget_metric',
            'widget_steps',
            'widget_table',
            'widget_comparison',
            'widget_progress',
            'widget_checklist',
            'widget_timeline',
            'widget_alert',
            'widget_faq',
            'widget_sources',
            'widget_weather',
            'widget_news',
            'widget_product',
            'widget_rating',
            'widget_key_values',
            'widget_bar_chart',
            'widget_image_gallery',
          ],
          'widget_schemas': const {
            'widget_market': {'name': 'Bitcoin', 'symbol': 'BTC', 'price': '...', 'currency': r'$','changePercent': 0.0, 'series': [1, 2, 3], 'high24h': '...', 'low24h': '...', 'volume24h': '...'},
            'widget_calendar': {'title': 'Agenda', 'date': 'YYYY-MM-DD', 'humanLabel': '...', 'events': [{'title': '...', 'time': '...'}]},
            'widget_map': {'name': 'Local', 'address': '...', 'lat': 0.0, 'lng': 0.0, 'description': '...'},
            'widget_chart': {'title': 'Gráfico', 'subtitle': '...', 'values': [12, 18, 15], 'labels': ['A', 'B', 'C']},
            'widget_metric': {'title': 'Indicadores', 'metrics': [{'label': '...', 'value': '...', 'unit': '...'}]},
            'widget_steps': {'title': 'Etapas', 'steps': [{'title': '...', 'description': '...'}]},
            'widget_table': {'headers': ['Coluna A', 'Coluna B'], 'rows': [['...', '...']]},
            'widget_comparison': {'title': 'Comparação', 'items': [{'name': '...', 'summary': '...', 'pros': ['...'], 'cons': ['...'], 'attributes': {'Preço': '...'}}], 'verdict': '...'},
            'widget_progress': {'title': 'Progresso', 'items': [{'label': '...', 'value': 75, 'description': '...'}]},
            'widget_checklist': {'title': 'Lista', 'items': [{'title': '...', 'description': '...', 'done': false}]},
            'widget_timeline': {'title': 'Cronologia', 'items': [{'date': '...', 'title': '...', 'description': '...'}]},
            'widget_alert': {'type': 'info|warning|success|error', 'title': '...', 'message': '...'},
            'widget_faq': {'title': 'Perguntas frequentes', 'items': [{'question': '...', 'answer': '...'}]},
            'widget_sources': {'title': 'Fontes e referências', 'items': [{'title': '...', 'publisher': '...', 'date': '...', 'snippet': '...', 'url': 'https://...'}]},
            'widget_weather': {'city': '...', 'updatedAt': '...', 'temperature': '...', 'condition': '...', 'high': '...', 'low': '...', 'humidity': '...', 'wind': '...', 'forecast': [{'day': '...', 'temperature': '...'}]},
            'widget_news': {'title': 'Notícias', 'items': [{'title': '...', 'publisher': '...', 'date': '...', 'summary': '...', 'imageUrl': 'https://...'}]},
            'widget_product': {'title': 'Produtos', 'items': [{'name': '...', 'brand': '...', 'price': '...', 'description': '...', 'features': ['...'], 'imageUrl': 'https://...'}]},
            'widget_rating': {'title': 'Avaliação', 'score': 4.5, 'maxScore': 5, 'reviewCount': 0, 'summary': '...'},
            'widget_key_values': {'title': 'Dados principais', 'items': [{'label': '...', 'value': '...'}]},
            'widget_bar_chart': {'title': 'Gráfico de barras', 'items': [{'label': '...', 'value': 12, 'display': '12'}]},
            'widget_image_gallery': {'title': 'Galeria', 'items': [{'url': 'https://...', 'caption': '...'}]},
          },
          'rendering_preferences': const {
            'use_app_primary_color': true,
            'prefer_compact_cards': true,
            'include_sources_for_current_facts': true,
            'do_not_invent_missing_values': true,
          },
          'format_instructions':
              'Devolve respostas completas e bem estruturadas em Markdown. Usa títulos hierárquicos, introdução breve, secções temáticas, parágrafos objetivos, listas ordenadas e não ordenadas, tabelas quando facilitarem a comparação, citações e blocos NOTE/TIP/IMPORTANT/WARNING. Usa LaTeX para matemática, unidades e fórmulas quando for útil. Usa blocos de código fenced com a linguagem correta para código. Quando ajudar a compreensão, gera blocos visuais fenced em JSON válido: widget_market, widget_calendar, widget_map, widget_chart, widget_metric, widget_steps, widget_table, widget_comparison, widget_progress, widget_checklist, widget_timeline, widget_alert, widget_faq, widget_sources, widget_weather, widget_news, widget_product, widget_rating, widget_key_values, widget_bar_chart, widget_image_gallery. Inclui fontes verificáveis em widget_sources quando pesquisares factos atuais. Não inventes preços, estatísticas, datas, avaliações, fontes, coordenadas nem imagens. Se não tiveres dados reais para um campo, omite-o em vez de fabricar valores. Mantém o texto e os blocos coerentes e não repitas a mesma informação em vários formatos.',
        });

      final response = await client.send(request).timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await response.stream.bytesToString();
        throw StateError(_readServerError(errorBody, response.statusCode));
      }

      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.contains('text/event-stream')) {
        final answer = await _readEventStream(response, onToken);
        if (answer.trim().isEmpty) {
          throw StateError('O servidor terminou a pesquisa sem devolver uma resposta.');
        }
        return answer.trim();
      }

      final body = await response.stream.bytesToString();
      final answer = _extractAnswer(body);
      if (answer.trim().isEmpty) {
        throw StateError('O servidor não devolveu o campo answer.');
      }
      onToken?.call(answer);
      return answer.trim();
    } on TimeoutException {
      throw StateError('A pesquisa demorou demasiado. Tenta novamente.');
    } finally {
      client.close();
    }
  }

  static Future<String> _readEventStream(
    http.StreamedResponse response,
    void Function(String token)? onToken,
  ) async {
    final answer = StringBuffer();
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(const Duration(seconds: 90))) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      String chunk;
      try {
        final decoded = jsonDecode(payload);
        chunk = _extractStreamToken(decoded);
      } catch (_) {
        // Alguns Workers enviam diretamente texto depois de "data:".
        chunk = payload;
      }

      if (chunk.isNotEmpty) {
        answer.write(chunk);
        onToken?.call(chunk);
      }
    }
    return answer.toString();
  }

  static String _extractStreamToken(dynamic decoded) {
    if (decoded is! Map) return decoded?.toString() ?? '';

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final choice = choices.first as Map;
      final delta = choice['delta'];
      if (delta is Map && delta['content'] != null) {
        return delta['content'].toString();
      }
      final message = choice['message'];
      if (message is Map && message['content'] != null) {
        return message['content'].toString();
      }
    }

    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty && candidates.first is Map) {
      final content = (candidates.first as Map)['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is List) {
        return parts
            .whereType<Map>()
            .map((part) => part['text']?.toString() ?? '')
            .join();
      }
    }

    for (final key in const ['delta', 'token', 'content', 'answer', 'text']) {
      final value = decoded[key];
      if (value is String) return value;
    }
    return '';
  }

  static String _extractAnswer(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        for (final key in const ['answer', 'content', 'text', 'output']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
        final message = decoded['message'];
        if (message is Map && message['content'] is String) {
          return message['content'] as String;
        }
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final choice = choices.first as Map;
          final content = (choice['message'] is Map)
              ? (choice['message'] as Map)['content']
              : null;
          if (content is String) return content;
        }
      }
    } catch (_) {
      // O servidor também pode responder com Markdown em texto simples.
    }
    return raw;
  }

  static String _readServerError(String raw, int statusCode) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final error = decoded['error'] ?? decoded['message'];
        if (error != null && error.toString().trim().isNotEmpty) {
          return error.toString();
        }
      }
    } catch (_) {}
    return 'O servidor de IA respondeu com o código $statusCode.';
  }
}
