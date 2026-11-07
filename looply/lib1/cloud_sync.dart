import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'data_transfer.dart';

/// Sincronização remota opcional do BrowseIt com o Cloudflare Worker próprio.
/// Até BROWSEIT_WORKER_URL estar definido, o login Google continua local e
/// nenhuma credencial é guardada como sessão de servidor.
class BrowseItCloudSync {
  BrowseItCloudSync._();

  static const String _workerUrl = String.fromEnvironment(
    'BROWSEIT_WORKER_URL',
    defaultValue: '',
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _sessionKey = 'browseit_cloud_session_v1';
  static Timer? _syncDebounce;
  static Future<void>? _syncInFlight;
  static bool _syncQueued = false;

  static bool get isConfigured =>
      _workerUrl.startsWith('https://') && !_workerUrl.contains('YOUR_SUBDOMAIN');

  static Uri _uri(String path) => Uri.parse('${_workerUrl.replaceFirst(RegExp(r'/+$'), '')}$path');

  static Future<String?> createAuthChallenge() async {
    if (!isConfigured) return null;
    final response = await http
        .post(_uri('/api/v1/auth/challenge'), headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    final nonce = body['nonce'];
    if (response.statusCode != 200 || nonce is! String || nonce.isEmpty) {
      throw StateError(body['error']?.toString() ?? 'Não foi possível iniciar a autenticação segura.');
    }
    return nonce;
  }

  static Future<void> authenticateGoogleIdToken({
    required String idToken,
    required String nonce,
  }) async {
    if (!isConfigured) return;
    final response = await http
        .post(
          _uri('/api/v1/auth/google'),
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'idToken': idToken, 'nonce': nonce}),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(body['error']?.toString() ?? 'O servidor não aceitou a conta Google.');
    }
    final token = body['sessionToken'];
    if (token is! String || token.length < 32) {
      throw StateError('O servidor não devolveu uma sessão válida.');
    }
    await _secureStorage.write(key: _sessionKey, value: token);
  }

  /// Agenda a cópia completa do JSON depois de alterações locais, agrupando
  /// mudanças rápidas para não enviar um pedido por cada atualização da UI.
  static void scheduleAppBackup({Duration debounce = const Duration(seconds: 2)}) {
    if (!isConfigured) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(debounce, () {
      _syncDebounce = null;
      unawaited(syncAppBackup().catchError((_) {}));
    });
  }

  static Future<void> syncAppBackup() {
    if (!isConfigured) return Future<void>.value();
    final active = _syncInFlight;
    if (active != null) {
      _syncQueued = true;
      return active;
    }
    final operation = _syncLoop();
    _syncInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_syncInFlight, operation)) _syncInFlight = null;
    });
  }

  static Future<void> _syncLoop() async {
    do {
      _syncQueued = false;
      await _uploadAppBackup();
    } while (_syncQueued);
  }

  static Future<void> _uploadAppBackup() async {
    final token = await _secureStorage.read(key: _sessionKey);
    if (token == null || token.isEmpty) return;

    final exportBytes = await LooplyDataTransfer.buildExportBytes();
    final decoded = jsonDecode(utf8.decode(exportBytes));
    final response = await http
        .put(
          _uri('/api/v1/me/data/app-backup'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'data': decoded}),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 401) {
      await _secureStorage.delete(key: _sessionKey);
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_decode(response)['error']?.toString() ?? 'Não foi possível sincronizar o backup.');
    }
  }

  static Future<void> signOut() async {
    _syncDebounce?.cancel();
    _syncDebounce = null;
    _syncQueued = false;
    final token = await _secureStorage.read(key: _sessionKey);
    if (token != null && token.isNotEmpty && isConfigured) {
      try {
        await http
            .post(
              _uri('/api/v1/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // A sessão local deve ser removida mesmo sem rede.
      }
    }
    await _secureStorage.delete(key: _sessionKey);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
