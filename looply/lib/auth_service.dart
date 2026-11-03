import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync.dart';

class LooplyUser {
  const LooplyUser({
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
  final String provider;
}

/// A seleção da conta é feita pelo Credential Manager nativo do Android.
/// Sem Worker configurado, o perfil fica disponível localmente; quando o
/// Worker existir, o ID token é validado remotamente e é criada uma sessão.
class AuthController extends ValueNotifier<LooplyUser?> {
  AuthController() : super(null);

  static const MethodChannel _googleAuth = MethodChannel('browseit/google_auth');
  static const _emailKey = 'looply_auth_email';
  static const _nameKey = 'looply_auth_name';
  static const _photoKey = 'looply_auth_photo';
  static const _providerKey = 'looply_auth_provider';

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_emailKey);
      if (email == null || email.trim().isEmpty) return;
      value = LooplyUser(
        email: email,
        displayName: prefs.getString(_nameKey),
        photoUrl: prefs.getString(_photoKey),
        provider: prefs.getString(_providerKey) ?? 'google',
      );
    } catch (_) {}
  }

  Future<void> signInWithGoogle() async {
    final nonce = await BrowseItCloudSync.createAuthChallenge();
    final result = await _googleAuth.invokeMapMethod<String, dynamic>(
      'signInGoogle',
      <String, dynamic>{if (nonce != null) 'nonce': nonce},
    );
    if (result == null) throw StateError('O Google não devolveu os dados da conta.');

    final idToken = result['idToken']?.toString() ?? '';
    final email = result['email']?.toString() ?? '';
    final returnedNonce = result['nonce']?.toString() ?? nonce ?? '';
    if (idToken.isEmpty || email.isEmpty || returnedNonce.isEmpty) {
      throw StateError('A credencial Google recebida está incompleta.');
    }

    // A autenticação Cloudflare só é declarada concluída depois de o Worker
    // validar o ID token. Sem Worker, guardamos apenas o perfil local recebido
    // pelo Credential Manager e não persistimos o ID token.
    if (BrowseItCloudSync.isConfigured) {
      await BrowseItCloudSync.authenticateGoogleIdToken(
        idToken: idToken,
        nonce: returnedNonce,
      );
    }

    await _save(LooplyUser(
      email: email,
      displayName: result['displayName']?.toString(),
      photoUrl: result['photoUrl']?.toString(),
      provider: BrowseItCloudSync.isConfigured ? 'google' : 'google-local',
    ));

    if (BrowseItCloudSync.isConfigured) {
      try {
        await BrowseItCloudSync.syncAppBackup();
      } catch (_) {
        // O login não perde a sessão por uma falha temporária na cópia inicial.
      }
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('Preenche o email e a palavra-passe.');
    }
    throw StateError('O login por email ainda precisa de um endpoint de autenticação próprio.');
  }

  Future<void> _save(LooplyUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, user.email);
    await prefs.setString(_providerKey, user.provider);
    if (user.displayName != null) {
      await prefs.setString(_nameKey, user.displayName!);
    } else {
      await prefs.remove(_nameKey);
    }
    if (user.photoUrl != null) {
      await prefs.setString(_photoKey, user.photoUrl!);
    } else {
      await prefs.remove(_photoKey);
    }
    value = user;
  }

  Future<void> signOut() async {
    await BrowseItCloudSync.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_photoKey);
    await prefs.remove(_providerKey);
    value = null;
  }
}

final AuthController authController = AuthController();
