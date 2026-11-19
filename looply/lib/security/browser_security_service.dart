import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud_sync.dart';

/// Stores site-blocking rules and delegates access checks to Android device authentication.
class BrowserSecurityService {
  BrowserSecurityService._();

  static const MethodChannel _channel = MethodChannel('looply/native_ui');
  static const String _blockedSitesKey = 'looply_blocked_sites_v1';
  static const String _passwordSavingKey = 'looply_save_passwords_enabled';

  static final ValueNotifier<bool> passwordSavingEnabled = ValueNotifier<bool>(false);

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      passwordSavingEnabled.value = prefs.getBool(_passwordSavingKey) ?? false;
    } catch (_) {
      passwordSavingEnabled.value = false;
    }
  }


  /// Uses the device's existing screen lock / fingerprint / face authentication.
  /// Looply never creates or stores a second PIN or password for this feature.
  static Future<bool> canAuthenticateDevice() async {
    try {
      return await _channel.invokeMethod<bool>('canAuthenticateDevice') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> authenticateDevice({String reason = 'Confirmar identidade'}) async {
    try {
      return await _channel.invokeMethod<bool>('authenticateDevice', <String, Object>{
        'reason': reason,
      }) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<List<String>> blockedSites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_blockedSitesKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];
      return decoded.whereType<String>().map(_normalizeHost).whereType<String>().toSet().toList()..sort();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> addBlockedSite(String host) async {
    final normalized = _normalizeHost(host);
    if (normalized == null) throw FormatException('Endereço de site inválido.');
    final sites = await blockedSites();
    if (!sites.contains(normalized)) sites.add(normalized);
    await _saveBlockedSites(sites);
  }

  static Future<void> removeBlockedSite(String host) async {
    final sites = await blockedSites();
    sites.removeWhere((item) => item == host);
    await _saveBlockedSites(sites);
  }

  static Future<void> _saveBlockedSites(List<String> sites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blockedSitesKey, jsonEncode(sites.toSet().toList()..sort()));
    BrowseItCloudSync.scheduleAppBackup();
  }

  static Future<void> setPasswordSavingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passwordSavingKey, enabled);
    passwordSavingEnabled.value = enabled;
  }

  static String? _normalizeHost(String value) {
    var input = value.trim().toLowerCase();
    if (input.isEmpty) return null;
    if (!input.contains('://')) input = 'https://$input';
    final uri = Uri.tryParse(input);
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (host == null || host.isEmpty || !host.contains('.') || host.contains(' ') || host.contains('/')) {
      return null;
    }
    if (uri!.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;
    return host;
  }
}
