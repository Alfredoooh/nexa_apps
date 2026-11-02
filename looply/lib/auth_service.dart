import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LooplyUser {
  const LooplyUser({required this.email, this.displayName, this.photoUrl, required this.provider});

  final String email;
  final String? displayName;
  final String? photoUrl;
  final String provider;
}

/// Estado de utilizador persistente. A identidade Google usa o seletor nativo;
/// a autenticação por email precisa de um fornecedor/backend real configurado.
class AuthController extends ValueNotifier<LooplyUser?> {
  AuthController() : super(null);

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
    final google = GoogleSignIn(scopes: const <String>['email']);
    final account = await google.signIn();
    if (account == null) return;
    await _save(LooplyUser(
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
      provider: 'google',
    ));
  }

  Future<void> signInWithEmail(String email, String password) async {
    // Não fingir autenticação local: sem Firebase/OAuth server ou API de
    // autenticação, não existe forma segura de validar a palavra-passe.
    if (email.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('Preenche o email e a palavra-passe.');
    }
    throw StateError('O login por email ainda precisa de um serviço de autenticação e credenciais de servidor.');
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
    try {
      if (value?.provider == 'google') await GoogleSignIn().signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_photoKey);
    await prefs.remove(_providerKey);
    value = null;
  }
}

final AuthController authController = AuthController();
