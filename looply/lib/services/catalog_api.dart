import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Único endereço de catálogo utilizado pelo cliente Flutter.
/// Configure-o no build com:
/// --dart-define=BROWSEIT_CATALOG_URL=https://seu-servico.onrender.com/api/v1/catalog
class BrowseItCatalogApi {
  BrowseItCatalogApi._();
  static final BrowseItCatalogApi instance = BrowseItCatalogApi._();

  static const String catalogUrl = String.fromEnvironment(
    'BROWSEIT_CATALOG_URL',
    defaultValue: '',
  );
  static const int _maxDownloadBytes = 512 * 1024 * 1024;
  static const int _maxExpandedBytes = 768 * 1024 * 1024;

  CatalogSnapshot? _memoryCache;
  DateTime? _cacheTime;
  Future<CatalogSnapshot>? _inflight;

  bool get isConfigured {
    final value = catalogUrl.trim();
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Uri? resolveRemote(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      return parsed.scheme == 'https' && parsed.host.isNotEmpty ? parsed : null;
    }
    final base = Uri.tryParse(catalogUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) return null;
    final resolved = base.resolve(value);
    return resolved.scheme == 'https' && resolved.host.isNotEmpty ? resolved : null;
  }

  Future<CatalogSnapshot> fetchCatalog({bool forceRefresh = false}) async {
    if (!isConfigured) {
      throw const CatalogConfigurationException(
        'BROWSEIT_CATALOG_URL não foi definido no build Android.',
      );
    }

    if (!forceRefresh && _memoryCache != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < const Duration(minutes: 2)) {
      return _memoryCache!;
    }
    if (!forceRefresh && _inflight != null) return _inflight!;

    final future = _fetchCatalogRequest();
    _inflight = future;
    try {
      final result = await future;
      _memoryCache = result;
      _cacheTime = DateTime.now();
      return result;
    } finally {
      _inflight = null;
    }
  }

  Future<CatalogSnapshot> _fetchCatalogRequest() async {
    final uri = Uri.parse(catalogUrl);
    final response = await http.get(
      uri,
      headers: const <String, String>{'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw CatalogApiException(
        'O servidor de catálogo respondeu HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('A resposta do catálogo não é um objeto JSON.');
    }
    final json = Map<String, dynamic>.from(decoded);
    final games = (json['games'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => CatalogGame.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final sites = (json['sites'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => CatalogSite.fromJson(Map<String, dynamic>.from(item)))
        .where((site) => site.url.isNotEmpty)
        .toList(growable: false);
    final categories = (json['categories'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => CatalogCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final events = (json['events'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => CatalogEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);

    return CatalogSnapshot(
      version: json['version']?.toString() ?? '1',
      games: games,
      sites: sites,
      categories: categories,
      events: events,
    );
  }

  Future<InstalledGame> downloadGame(
    CatalogGame game, {
    void Function(double)? onProgress,
  }) async {
    final downloadUri = resolveRemote(game.downloadUrl);
    if (downloadUri == null) {
      throw const CatalogApiException('O servidor não forneceu um link HTTPS válido para descarregar este jogo.');
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', downloadUri)
        ..headers['Accept'] = 'application/zip';
      final response = await client.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw CatalogApiException('Não foi possível descarregar o jogo (HTTP ${response.statusCode}).');
      }
      final expected = response.contentLength ?? 0;
      if (expected > _maxDownloadBytes) {
        throw const CatalogApiException('O pacote excede o limite de 512 MB.');
      }
      final bytes = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > _maxDownloadBytes) {
          throw const CatalogApiException('O pacote excede o limite de 512 MB.');
        }
        bytes.add(chunk);
        if (expected > 0) onProgress?.call((received / expected).clamp(0.0, 1.0).toDouble());
      }
      onProgress?.call(1);
      final archiveBytes = bytes.takeBytes();
      final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);

      final documents = await getApplicationDocumentsDirectory();
      final gamesRoot = Directory('${documents.path}${Platform.pathSeparator}browseit_games');
      await gamesRoot.create(recursive: true);
      final safeId = _safeId(game.id);
      final root = Directory('${gamesRoot.path}${Platform.pathSeparator}$safeId');
      final staging = Directory('${gamesRoot.path}${Platform.pathSeparator}.$safeId.installing');
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);

      try {
        var expandedBytes = 0;
        for (final item in archive.files) {
          if (!item.isFile) continue;
          final relativePath = _safeArchivePath(item.name);
          if (relativePath == null || relativePath.isEmpty) continue;
          final content = item.content;
          final data = content is List<int> ? content : List<int>.from(content as Iterable);
          expandedBytes += data.length;
          if (expandedBytes > _maxExpandedBytes) {
            throw const CatalogApiException('O conteúdo extraído excede o limite de segurança de 768 MB.');
          }
          final target = File('${staging.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}');
          await target.parent.create(recursive: true);
          await target.writeAsBytes(data, flush: false);
        }

        final entry = _safeArchivePath(game.offlineEntry) ?? 'index.html';
        final stagedEntry = File('${staging.path}${Platform.pathSeparator}${entry.replaceAll('/', Platform.pathSeparator)}');
        if (!await stagedEntry.exists()) {
          throw CatalogApiException('O pacote do jogo não contém ${game.offlineEntry}.');
        }
        if (await root.exists()) await root.delete(recursive: true);
        await staging.rename(root.path);
      } catch (_) {
        if (await staging.exists()) await staging.delete(recursive: true);
        rethrow;
      }

      final entry = _safeArchivePath(game.offlineEntry) ?? 'index.html';
      final entryFile = File('${root.path}${Platform.pathSeparator}${entry.replaceAll('/', Platform.pathSeparator)}');
      final baseUri = Uri.directory('${root.path}${Platform.pathSeparator}').toString();
      return InstalledGame(
        directoryPath: root.path,
        entryPath: entryFile.path,
        baseUrl: baseUri,
      );
    } finally {
      client.close();
    }
  }

  Future<InstalledGame?> findInstalledGame(CatalogGame game) async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(
      '${documents.path}${Platform.pathSeparator}browseit_games${Platform.pathSeparator}${_safeId(game.id)}',
    );
    final entry = _safeArchivePath(game.offlineEntry) ?? 'index.html';
    final entryFile = File('${root.path}${Platform.pathSeparator}${entry.replaceAll('/', Platform.pathSeparator)}');
    if (!await entryFile.exists()) return null;
    return InstalledGame(
      directoryPath: root.path,
      entryPath: entryFile.path,
      baseUrl: Uri.directory('${root.path}${Platform.pathSeparator}').toString(),
    );
  }

  String _safeId(String value) {
    final safe = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
    return safe.isEmpty ? 'game' : safe;
  }

  String? _safeArchivePath(String value) {
    final normalized = value.replaceAll('\\', '/').trim();
    if (normalized.isEmpty || normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) return null;
    final parts = normalized.split('/');
    if (parts.any((part) => part == '..' || part == '.')) return null;
    return parts.where((part) => part.isNotEmpty).join('/');
  }
}

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.version,
    required this.games,
    required this.sites,
    required this.categories,
    required this.events,
  });
  final String version;
  final List<CatalogGame> games;
  final List<CatalogSite> sites;
  final List<CatalogCategory> categories;
  final List<CatalogEvent> events;
}

class CatalogCategory {
  const CatalogCategory({required this.id, required this.name});
  final String id;
  final String name;
  factory CatalogCategory.fromJson(Map<String, dynamic> json) => CatalogCategory(
        id: json['id']?.toString() ?? 'other',
        name: json['name']?.toString() ?? 'Outros',
      );
}

class CatalogSite {
  const CatalogSite({
    required this.id,
    required this.name,
    required this.url,
    required this.logo,
    required this.description,
  });
  final String id;
  final String name;
  final String url;
  final String logo;
  final String description;

  factory CatalogSite.fromJson(Map<String, dynamic> json) => CatalogSite(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Site',
        url: _validWebUrl(json['url']?.toString() ?? ''),
        logo: json['logo']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );
}

class CatalogGame {
  const CatalogGame({
    required this.id,
    required this.name,
    required this.description,
    required this.longDescription,
    required this.developer,
    required this.category,
    required this.icon,
    required this.cover,
    required this.screenshots,
    required this.rating,
    required this.ratingsCount,
    required this.ageRating,
    required this.sizeBytes,
    required this.featured,
    required this.premium,
    required this.onlineUrl,
    required this.downloadUrl,
    required this.offlineEntry,
    required this.orientation,
    required this.features,
    required this.event,
  });

  final String id;
  final String name;
  final String description;
  final String longDescription;
  final String developer;
  final String category;
  final String icon;
  final String cover;
  final List<String> screenshots;
  final double rating;
  final int ratingsCount;
  final String ageRating;
  final int sizeBytes;
  final bool featured;
  final bool premium;
  final String onlineUrl;
  final String downloadUrl;
  final String offlineEntry;
  final String orientation;
  final List<String> features;
  final CatalogEvent? event;

  factory CatalogGame.fromJson(Map<String, dynamic> json) {
    final eventJson = json['event'];
    return CatalogGame(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Jogo',
      description: json['description']?.toString() ?? '',
      longDescription: json['long_description']?.toString() ?? json['longDescription']?.toString() ?? '',
      developer: json['developer']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      icon: json['icon']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      screenshots: (json['screenshots'] as List? ?? const <dynamic>[])
          .whereType<String>().toList(growable: false),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingsCount: (json['ratings_count'] as num?)?.toInt() ?? 0,
      ageRating: json['age_rating']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      featured: json['featured'] == true,
      premium: json['premium'] == true,
      onlineUrl: _validWebUrl(json['online_url']?.toString() ?? ''),
      downloadUrl: json['download_url']?.toString() ?? '',
      offlineEntry: json['offline_entry']?.toString() ?? 'index.html',
      orientation: json['orientation']?.toString() ?? 'auto',
      features: (json['features'] as List? ?? const <dynamic>[])
          .whereType<String>().toList(growable: false),
      event: eventJson is Map
          ? CatalogEvent.fromJson(Map<String, dynamic>.from(eventJson))
          : null,
    );
  }
}

class CatalogEvent {
  const CatalogEvent({required this.title, required this.banner, required this.subtitle, this.gameId = ''});
  final String title;
  final String banner;
  final String subtitle;
  final String gameId;
  factory CatalogEvent.fromJson(Map<String, dynamic> json) => CatalogEvent(
        title: json['title']?.toString() ?? '',
        banner: json['banner']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        gameId: json['game_id']?.toString() ?? json['gameId']?.toString() ?? '',
      );
}

class InstalledGame {
  const InstalledGame({required this.directoryPath, required this.entryPath, required this.baseUrl});
  final String directoryPath;
  final String entryPath;
  final String baseUrl;
}

class CatalogConfigurationException implements Exception {
  const CatalogConfigurationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CatalogApiException implements Exception {
  const CatalogApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _validWebUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) return '';
  return uri.toString();
}

String formatCatalogSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 10 * 1024 * 1024 ? 1 : 0)} MB';
}
