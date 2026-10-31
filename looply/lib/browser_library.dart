import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cache persistente de favicons. Guarda os bytes, não apenas o URL remoto,
/// para que Histórico e Separadores continuem a mostrar o ícone offline.
class BrowserFaviconCache extends ChangeNotifier {
  BrowserFaviconCache._();
  static final BrowserFaviconCache instance = BrowserFaviconCache._();

  static const _storageKey = 'looply_favicon_cache_v1';
  final Map<String, String> _iconsByHost = <String, String>{};
  final Set<String> _loadingHosts = <String>{};

  String? forUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return null;
    return _iconsByHost[host];
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _iconsByHost
        ..clear()
        ..addEntries(decoded.entries.where((entry) =>
            entry.key is String && entry.value is String &&
            (entry.value as String).length <= 90000).map((entry) =>
              MapEntry(entry.key as String, entry.value as String)));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchForUrl(String url) async {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase();
    if (uri == null || host == null || host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        _iconsByHost.containsKey(host) || !_loadingHosts.add(host)) {
      return;
    }

    try {
      final iconUri = Uri.https('www.google.com', '/s2/favicons', {
        'domain': host,
        'sz': '64',
      });
      final response = await http.get(iconUri).timeout(const Duration(seconds: 6));
      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty &&
          response.bodyBytes.length <= 65000 &&
          (contentType.contains('image') || response.bodyBytes.length > 100)) {
        _iconsByHost[host] = base64Encode(response.bodyBytes);
        while (_iconsByHost.length > 260) {
          _iconsByHost.remove(_iconsByHost.keys.first);
        }
        notifyListeners();
        await _persist();
      }
    } catch (_) {
      // O histórico mantém um ícone neutro se o servidor de favicon falhar.
    } finally {
      _loadingHosts.remove(host);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_iconsByHost));
    } catch (_) {}
  }
}

final BrowserFaviconCache browserFaviconCache = BrowserFaviconCache.instance;

class BookmarkEntry {
  const BookmarkEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String url;
  final DateTime createdAt;
}

class BookmarksController extends ChangeNotifier {
  static const _storageKey = 'looply_bookmarks_v1';
  final List<BookmarkEntry> _entries = <BookmarkEntry>[];
  List<BookmarkEntry> get entries => List.unmodifiable(_entries);

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _entries
        ..clear()
        ..addAll(decoded.whereType<Map>().map((item) {
          final url = item['url'];
          if (url is! String || url.isEmpty) return null;
          final title = item['title'];
          final created = item['createdAt'];
          return BookmarkEntry(
            id: item['id'] is String ? item['id'] as String : url,
            title: title is String && title.isNotEmpty ? title : url,
            url: url,
            createdAt: created is String ? DateTime.tryParse(created) ?? DateTime.now() : DateTime.now(),
          );
        }).whereType<BookmarkEntry>());
      notifyListeners();
    } catch (_) {}
  }

  bool contains(String url) => _entries.any((entry) => entry.url == url);

  void add(String title, String url) {
    if (url.trim().isEmpty || contains(url)) return;
    _entries.insert(0, BookmarkEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? url : title.trim(),
      url: url,
      createdAt: DateTime.now(),
    ));
    if (_entries.length > 300) _entries.removeLast();
    notifyListeners();
    unawaited(_persist());
  }

  void remove(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_entries.map((entry) => {
        'id': entry.id,
        'title': entry.title,
        'url': entry.url,
        'createdAt': entry.createdAt.toIso8601String(),
      }).toList()));
    } catch (_) {}
  }
}

final BookmarksController bookmarksController = BookmarksController();

class DownloadEntry {
  const DownloadEntry({
    required this.id,
    required this.url,
    required this.filename,
    required this.createdAt,
    this.mimeType,
  });

  final String id;
  final String url;
  final String filename;
  final DateTime createdAt;
  final String? mimeType;
}

/// Guarda os pedidos de transferência recebidos pelas WebViews. O ficheiro
/// é apresentado como pedido/ligação até o motor de transferência do sistema
/// confirmar que foi descarregado para armazenamento local.
class DownloadsController extends ChangeNotifier {
  static const _storageKey = 'looply_download_requests_v1';
  final List<DownloadEntry> _entries = <DownloadEntry>[];
  List<DownloadEntry> get entries => List.unmodifiable(_entries);

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _entries
        ..clear()
        ..addAll(decoded.whereType<Map>().map((item) {
          final url = item['url'];
          if (url is! String || url.isEmpty) return null;
          return DownloadEntry(
            id: item['id'] is String ? item['id'] as String : url,
            url: url,
            filename: item['filename'] is String ? item['filename'] as String : _filenameFromUrl(url),
            mimeType: item['mimeType'] is String ? item['mimeType'] as String : null,
            createdAt: item['createdAt'] is String ? DateTime.tryParse(item['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
          );
        }).whereType<DownloadEntry>());
      notifyListeners();
    } catch (_) {}
  }

  void register({required String url, String? filename, String? mimeType}) {
    if (url.trim().isEmpty) return;
    final parsedName = _filenameFromUrl(url);
    _entries.insert(0, DownloadEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      url: url,
      filename: filename?.trim().isNotEmpty == true ? filename!.trim() : (parsedName ?? 'Ficheiro'),
      mimeType: mimeType,
      createdAt: DateTime.now(),
    ));
    if (_entries.length > 100) _entries.removeLast();
    notifyListeners();
    unawaited(_persist());
  }

  void remove(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_entries.map((entry) => {
        'id': entry.id,
        'url': entry.url,
        'filename': entry.filename,
        'mimeType': entry.mimeType,
        'createdAt': entry.createdAt.toIso8601String(),
      }).toList()));
    } catch (_) {}
  }
}

final DownloadsController downloadsController = DownloadsController();

String _filenameFromUrl(String url) {
  final segments = Uri.tryParse(url)?.pathSegments.where((part) => part.isNotEmpty).toList(growable: false) ?? const <String>[];
  return segments.isEmpty ? 'Ficheiro' : segments.last;
}
