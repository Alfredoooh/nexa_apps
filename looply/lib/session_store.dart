import 'dart:convert';
import 'dart:io';

/// Dados da última página que pode ser restaurada ao reabrir o Looply.
class RestorablePage {
  const RestorablePage({required this.url, required this.title});

  final String url;
  final String title;
}

/// Armazena temporariamente a última página visitada.
///
/// Usa o diretório temporário privado da aplicação para não depender de um
/// plugin adicional. A sessão expira após uma hora, conforme o comportamento
/// esperado pelo shell do Looply.
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  static const Duration _restoreWindow = Duration(hours: 1);
  static const String _fileName = 'looply_last_page_session.json';

  File get _sessionFile => File('${Directory.systemTemp.path}/$_fileName');

  Future<void> saveLastPage({
    required String url,
    required String title,
  }) async {
    final normalizedUrl = url.trim();
    if (!_isRestorableUrl(normalizedUrl)) return;

    final payload = <String, Object?>{
      'url': normalizedUrl,
      'title': title.trim().isEmpty ? normalizedUrl : title.trim(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _sessionFile.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // A falha de armazenamento não deve impedir a navegação.
    }
  }

  Future<RestorablePage?> getRestorablePage() async {
    try {
      final file = _sessionFile;
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;

      final url = decoded['url'];
      final title = decoded['title'];
      final savedAtRaw = decoded['savedAt'];
      if (url is! String || savedAtRaw is! String || !_isRestorableUrl(url)) {
        return null;
      }

      final savedAt = DateTime.tryParse(savedAtRaw);
      if (savedAt == null) return null;

      final age = DateTime.now().toUtc().difference(savedAt.toUtc());
      if (age.isNegative || age > _restoreWindow) {
        await _deleteSessionFile();
        return null;
      }

      return RestorablePage(
        url: url,
        title: title is String && title.trim().isNotEmpty ? title : url,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> markBackgrounded() async {
    try {
      final file = _sessionFile;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      decoded['backgroundedAt'] = DateTime.now().toUtc().toIso8601String();
      await file.writeAsString(jsonEncode(decoded), flush: true);
    } catch (_) {
      // A app continua normalmente mesmo se a sessão não puder ser gravada.
    }
  }

  bool _isRestorableUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<void> _deleteSessionFile() async {
    try {
      final file = _sessionFile;
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
