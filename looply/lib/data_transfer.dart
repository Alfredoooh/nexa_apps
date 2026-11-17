import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import 'browser_library.dart';
import 'models.dart';
import 'theme.dart';

class LooplyDataTransfer {
  LooplyDataTransfer._();

  static const int schemaVersion = 4;
  static const String _authPrefix = 'looply_auth_';
  static const int _maxEmbeddedDownloadBytes = 128 * 1024 * 1024;
  static const MethodChannel _nativeUiChannel = MethodChannel('looply/native_ui');

  static Future<Uint8List> buildExportBytes() async {
    await Future.wait<void>([
      tabsController.flushPersistence(),
      activityController.flushPersistence(),
      searchHistoryController.flushPersistence(),
      customSitesController.flushPersistence(),
      bookmarksController.flushPersistence(),
      downloadsController.flushPersistence(),
      AdBlockStats.instance.flushPersistence(),
    ]);

    final prefs = await SharedPreferences.getInstance();
    final appPreferences = <String, Object?>{};
    final saveHistory = prefs.getBool('looply_profile_save_history') ?? false;
    final syncBookmarks = prefs.getBool('looply_profile_sync_bookmarks') ?? true;
    final saveAddresses = prefs.getBool('looply_profile_save_addresses') ?? false;
    final syncAppSettings = prefs.getBool('looply_profile_sync_settings') ?? false;

    const accountDataKeys = <String>{
      'looply_browsing_history_v1',
      'looply_search_history_v1',
      'looply_bookmarks_v1',
      'looply_custom_sites_v1',
      'looply_saved_addresses_v1',
    };
    const profileOptionKeys = <String>{
      'looply_profile_save_history',
      'looply_profile_sync_bookmarks',
      'looply_profile_save_addresses',
      'looply_profile_sync_settings',
    };

    for (final key in prefs.getKeys()) {
      if (!key.startsWith('looply_') || key.startsWith(_authPrefix) || accountDataKeys.contains(key)) {
        continue;
      }
      // The category switches are always backed up; all other preferences
      // are uploaded only when the account-settings switch is enabled.
      if (!syncAppSettings && !profileOptionKeys.contains(key)) continue;
      if (key == 'looply_save_passwords_enabled') continue;

      final value = prefs.get(key);
      if (value is String || value is bool || value is int || value is double || value is List<String>) {
        appPreferences[key] = value;
      }
    }

    Object? decodeStoredJson(String key) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }

    final accountData = <String, Object?>{};
    if (saveHistory) {
      accountData['history'] = <String, Object?>{
        'visitedPages': decodeStoredJson('looply_browsing_history_v1') ?? <Object?>[],
        'searches': decodeStoredJson('looply_search_history_v1') ?? <Object?>[],
      };
    }
    if (syncBookmarks) {
      accountData['bookmarks'] = decodeStoredJson('looply_bookmarks_v1') ?? <Object?>[];
    }
    if (saveAddresses) {
      // Os endereços têm uma chave própria. Não reutilizar a lista de sites
      // personalizados, que é uma categoria de configuração diferente.
      accountData['addresses'] = decodeStoredJson('looply_saved_addresses_v1') ?? <Object?>[];
    }
    if (syncAppSettings) {
      accountData['customSites'] = decodeStoredJson('looply_custom_sites_v1') ?? <Object?>[];
    }

    final snapshots = <String, String>{};

    for (final tab in tabsController.tabs) {
      if (tab.kind == TabKind.appScreen ||
          tab.isIncognito ||
          tab.thumbnail == null) {
        continue;
      }

      snapshots[tab.id] = base64Encode(tab.thumbnail!);
    }

    // Um backup completo inclui também os ficheiros transferidos, não apenas
    // a lista de nomes. O limite evita esgotar a memória ao criar um JSON
    // gigante em telemóveis com armazenamento limitado.
    final downloadFiles = <String, Object?>{};
    var embeddedBytes = 0;
    for (final entry in downloadsController.entries) {
      final path = entry.localPath;
      if (entry.status != DownloadStatus.completed || path == null || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final size = await file.length();
      if (size <= 0) continue;
      if (embeddedBytes + size > _maxEmbeddedDownloadBytes) {
        throw StateError(
          'Os ficheiros transferidos excedem 128 MB. Remova temporariamente alguns downloads grandes e volte a exportar.',
        );
      }
      final bytes = await file.readAsBytes();
      embeddedBytes += bytes.length;
      downloadFiles[entry.id] = <String, Object?>{
        'filename': entry.filename,
        'mimeType': entry.mimeType,
        'bytes': base64Encode(bytes),
        'size': bytes.length,
      };
    }

    Map<String, String> nativeSessions = <String, String>{};
    try {
      nativeSessions = await _nativeUiChannel.invokeMapMethod<String, String>(
            'exportOrbitSessions',
          ) ??
          <String, String>{};
    } on MissingPluginException {
      // Backups exportados fora do Android preservam todos os dados Flutter.
    } on PlatformException {
      // O motor nativo pode ainda não estar disponível.
    }

    final payload = <String, Object?>{
      'format': 'looply-backup',
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'sync': <String, Object?>{
        'mode': 'local',
        'userId': null,
        'revision': schemaVersion,
        'lastSyncedAt': null,
      },
      'preferences': appPreferences,
      'accountData': accountData,
      'tabSnapshots': snapshots,
      'favicons': browserFaviconCache.exportCache(),
      'downloadFiles': downloadFiles,
      'nativeBrowserSessions': nativeSessions,
    };

    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(payload),
      ),
    );
  }

  static Future<Uri?> exportToFile() async {
    final bytes = await buildExportBytes();

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;

    return FilePicker.saveFile(
      dialogTitle: 'Exportar dados do BrowseIt',
      fileName: 'browseit-backup-$stamp.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
  }

  static Future<bool> importFromFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Importar dados do BrowseIt',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (picked == null) {
      return false;
    }

    final bytes = await picked.readAsBytes();

    if (bytes.isEmpty) {
      throw const FormatException(
        'O ficheiro JSON está vazio ou não pode ser lido.',
      );
    }

    final decoded = jsonDecode(utf8.decode(bytes));

    if (decoded is! Map || decoded['format'] != 'looply-backup') {
      throw const FormatException(
        'Este ficheiro não é um backup válido do BrowseIt.',
      );
    }

    final version = decoded['schemaVersion'];

    if (version is! num ||
        version > schemaVersion ||
        version < 1) {
      throw const FormatException(
        'A versão deste backup não é compatível com esta versão do BrowseIt.',
      );
    }

    final data = decoded['preferences'];

    if (data is! Map) {
      throw const FormatException(
        'O backup não contém dados de preferências válidos.',
      );
    }

    final prefs = await SharedPreferences.getInstance();

    await tabsController.clearStoredSnapshots();

    // Remove dados anteriores da aplicação, mantendo a sessão atual.
    for (final key in prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('looply_') &&
              !key.startsWith(_authPrefix),
        )
        .toList()) {
      await prefs.remove(key);
    }

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key is! String ||
          !key.startsWith('looply_') ||
          key.startsWith(_authPrefix)) {
        continue;
      }

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List &&
          value.every((item) => item is String)) {
        await prefs.setStringList(
          key,
          value.cast<String>(),
        );
      }
    }

    // Selected account categories are kept in a separate object so disabled
    // categories never leave the device. Restore only the categories present.
    final accountData = decoded['accountData'];
    if (accountData is Map) {
      final history = accountData['history'];
      if (history is Map) {
        final visitedPages = history['visitedPages'];
        final searches = history['searches'];
        if (visitedPages is List) {
          await prefs.setString('looply_browsing_history_v1', jsonEncode(visitedPages));
        }
        if (searches is List) {
          await prefs.setString('looply_search_history_v1', jsonEncode(searches));
        }
      }
      final bookmarks = accountData['bookmarks'];
      if (bookmarks is List) {
        await prefs.setString('looply_bookmarks_v1', jsonEncode(bookmarks));
      }
      final addresses = accountData['addresses'];
      if (addresses is List) {
        await prefs.setString('looply_saved_addresses_v1', jsonEncode(addresses));
      }
      final customSites = accountData['customSites'];
      if (customSites is List) {
        await prefs.setString('looply_custom_sites_v1', jsonEncode(customSites));
      }
    }

    // Restaura os bytes dos downloads primeiro, para que o controlador
    // valide os caminhos quando carregar a lista persistida.
    final downloadFiles = decoded['downloadFiles'];
    if (downloadFiles is Map && downloadFiles.isNotEmpty) {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}${Platform.pathSeparator}downloads');
      await directory.create(recursive: true);
      final restoredPaths = <String, String>{};
      for (final item in downloadFiles.entries) {
        if (item.key is! String || item.value is! Map) continue;
        final id = item.key as String;
        final data = item.value as Map;
        final encoded = data['bytes'];
        final filename = data['filename']?.toString() ?? 'download.bin';
        if (encoded is! String || encoded.isEmpty || encoded.length > 180000000) continue;
        try {
          final bytes = base64Decode(encoded);
          if (bytes.isEmpty || bytes.length > _maxEmbeddedDownloadBytes) continue;
          final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final file = File('${directory.path}${Platform.pathSeparator}${safeId}_$safeName');
          await file.writeAsBytes(bytes, flush: true);
          restoredPaths[id] = file.path;
        } catch (_) {}
      }
      if (restoredPaths.isNotEmpty) {
        final rawDownloads = prefs.getString('looply_downloads_v1');
        if (rawDownloads != null) {
          try {
            final entries = jsonDecode(rawDownloads);
            if (entries is List) {
              for (final item in entries) {
                if (item is Map && item['id'] is String) {
                  final path = restoredPaths[item['id'] as String];
                  if (path != null) item['localPath'] = path;
                }
              }
              await prefs.setString('looply_downloads_v1', jsonEncode(entries));
            }
          } catch (_) {}
        }
      }
    }

    final nativeSessions = decoded['nativeBrowserSessions'];
    if (nativeSessions is Map) {
      try {
        await _nativeUiChannel.invokeMethod<int>(
          'importOrbitSessions',
          <String, Object?>{
            'sessions': nativeSessions.map((key, value) => MapEntry(key.toString(), value.toString())),
          },
        );
      } on MissingPluginException {
        // A importação Flutter continua possível fora do Android.
      } on PlatformException {
        // Os dados Flutter são restaurados mesmo sem o motor WebView.
      }
    }

    await Future.wait<void>([
      themeController.restore(),
      tabsController.restore(),
      activityController.restore(),
      searchHistoryController.restore(),
      customSitesController.restore(),
      activeSearchEngine.restore(),
      restoreRuntimeSettings(),
      AdBlockStats.instance.restore(),
      browserFaviconCache.restore(),
      bookmarksController.restore(),
      downloadsController.restore(),
    ]);

    final faviconData = decoded['favicons'];

    if (faviconData is Map) {
      await browserFaviconCache.importCache(faviconData);
    }

    final snapshotData = decoded['tabSnapshots'];

    if (snapshotData is Map) {
      for (final entry in snapshotData.entries) {
        final id = entry.key;
        final encoded = entry.value;

        if (id is! String || encoded is! String) {
          continue;
        }

        try {
          final snapshotBytes = base64Decode(encoded);
          tabsController.updateTab(
            id,
            thumbnail: snapshotBytes,
          );
        } catch (_) {}
      }

      await tabsController.flushPersistence();
    }

    return true;
  }
}
