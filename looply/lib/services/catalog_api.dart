import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Único endereço de catálogo utilizado pelo cliente Flutter.
/// Configure-o no build com:
/// --dart-define=BROWSEIT_CATALOG_URL=https://seu-servico.onrender.com/catalog.json
class BrowseItCatalogApi {
  BrowseItCatalogApi._();
  static final BrowseItCatalogApi instance = BrowseItCatalogApi._();

  static const String catalogUrl = String.fromEnvironment(
    'BROWSEIT_CATALOG_URL',
    defaultValue: '',
  );
  static const int _maxDownloadBytes = 512 * 1024 * 1024;

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
    if (game.offlineFiles.isEmpty) {
      throw const CatalogApiException('Este jogo ainda não publicou offline_files no catalog.json.');
    }
    final base = game.basePath.trim();
    if (!base.startsWith('games/') || base.startsWith('/') || base.contains('..')) {
      throw const CatalogApiException('O jogo não tem um base_path estático válido.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final gamesRoot = Directory('${documents.path}${Platform.pathSeparator}browseit_games');
    await gamesRoot.create(recursive: true);
    final safeId = _safeId(game.id);
    final root = Directory('${gamesRoot.path}${Platform.pathSeparator}$safeId');
    final staging = Directory('${gamesRoot.path}${Platform.pathSeparator}.$safeId.installing');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);

    final client = http.Client();
    try {
      var completed = 0;
      var totalBytes = 0;
      for (final listedPath in game.offlineFiles) {
        final relativePath = _safeGamePath(listedPath);
        if (relativePath == null || relativePath.isEmpty) {
          throw CatalogApiException('Caminho offline inválido: $listedPath');
        }
        final remote = resolveRemote('$base$relativePath');
        if (remote == null || !remote.path.contains('/games/')) {
          throw CatalogApiException('Ficheiro fora da pasta pública do jogo: $listedPath');
        }
        final response = await client.get(remote, headers: const <String, String>{'Accept': '*/*'})
            .timeout(const Duration(seconds: 40));
        if (response.statusCode != 200) {
          throw CatalogApiException('Não foi possível descarregar $listedPath (HTTP ${response.statusCode}).');
        }
        totalBytes += response.bodyBytes.length;
        if (totalBytes > _maxDownloadBytes) {
          throw const CatalogApiException('Os ficheiros do jogo excedem o limite de 512 MB.');
        }
        final target = File('${staging.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(response.bodyBytes, flush: false);
        completed++;
        onProgress?.call(completed / game.offlineFiles.length);
      }

      final entry = _safeGamePath(game.offlineEntry) ?? 'index.html';
      final stagedEntry = File('${staging.path}${Platform.pathSeparator}${entry.replaceAll('/', Platform.pathSeparator)}');
      if (!await stagedEntry.exists()) {
        throw CatalogApiException('O catálogo não incluiu ${game.offlineEntry} em offline_files.');
      }
      if (await root.exists()) await root.delete(recursive: true);
      await staging.rename(root.path);
      final entryFile = File('${root.path}${Platform.pathSeparator}${entry.replaceAll('/', Platform.pathSeparator)}');
      final baseUri = Uri.directory('${root.path}${Platform.pathSeparator}').toString();
      onProgress?.call(1);
      return InstalledGame(directoryPath: root.path, entryPath: entryFile.path, baseUrl: baseUri);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<InstalledGame?> findInstalledGame(CatalogGame game) async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(
      '${documents.path}${Platform.pathSeparator}browseit_games${Platform.pathSeparator}${_safeId(game.id)}',
    );
    final entry = _safeGamePath(game.offlineEntry) ?? 'index.html';
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

  String? _safeGamePath(String value) {
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
    required this.basePath,
    required this.offlineFiles,
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
  final String downloadUrl; // legado, não usado pelo catálogo estático
  final String basePath;
  final List<String> offlineFiles;
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
      basePath: json['base_path']?.toString() ?? '',
      offlineFiles: (json['offline_files'] as List? ?? json['files'] as List? ?? const <dynamic>[])
          .whereType<String>().toList(growable: false),
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
