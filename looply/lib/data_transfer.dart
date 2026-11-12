import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_library.dart';
import 'models.dart';
import 'theme.dart';

class LooplyDataTransfer {
  LooplyDataTransfer._();

  static const int schemaVersion = 1;
  static const String _authPrefix = 'looply_auth_';

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

    for (final key in prefs.getKeys()) {
      if (!key.startsWith('looply_') || key.startsWith(_authPrefix)) {
        continue;
      }

      final value = prefs.get(key);

      if (value is String ||
          value is bool ||
          value is int ||
          value is double ||
          value is List<String>) {
        appPreferences[key] = value;
      }
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
      'tabSnapshots': snapshots,
      'favicons': browserFaviconCache.exportCache(),
    };

    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(payload),
      ),
    );
  }

  static Future<String?> exportToFile() async {
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
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Importar dados do BrowseIt',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    // O utilizador pode cancelar a seleção.
    if (picked == null || picked.files.isEmpty) {
      return false;
    }

    // FilePickerResult contém os ficheiros na propriedade files.
    final bytes = await picked.files.first.readAsBytes();

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

    // Atualiza imediatamente os controladores em memória.
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