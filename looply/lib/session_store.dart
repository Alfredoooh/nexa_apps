import 'package:shared_preferences/shared_preferences.dart';

// Persiste a última aba de navegação (URL + título) e o instante em que
// o app foi para segundo plano / fechado, para decidir no próximo
// arranque se deve restaurar direto no browser (se passou menos de 1h)
// ou abrir normalmente na Home.
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _keyUrl = 'looply_last_url';
  static const _keyTitle = 'looply_last_title';
  static const _keyTimestamp = 'looply_last_timestamp_ms';

  static const Duration restoreWindow = Duration(hours: 1);

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // Chamado sempre que a aba de browser ativa muda de URL/título —
  // guarda o estado mais recente de navegação.
  Future<void> saveLastPage({required String url, required String title}) async {
    if (url.isEmpty) return;
    final prefs = await _ensurePrefs();
    await prefs.setString(_keyUrl, url);
    await prefs.setString(_keyTitle, title);
    await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  // Chamado quando o app vai para segundo plano ou é fechado — marca o
  // instante exato para a janela de restauração de 1h.
  Future<void> markBackgrounded() async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
  }

  // Retorna a última página se ainda estiver dentro da janela de 1h,
  // caso contrário null (app deve abrir na Home normalmente).
  Future<RestoredPage?> getRestorablePage() async {
    final prefs = await _ensurePrefs();
    final url = prefs.getString(_keyUrl);
    final title = prefs.getString(_keyTitle);
    final timestampMs = prefs.getInt(_keyTimestamp);
    if (url == null || url.isEmpty || timestampMs == null) return null;

    final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestampMs));
    if (elapsed > restoreWindow) return null;

    return RestoredPage(url: url, title: title ?? url);
  }

  Future<void> clear() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_keyUrl);
    await prefs.remove(_keyTitle);
    await prefs.remove(_keyTimestamp);
  }
}

class RestoredPage {
  const RestoredPage({required this.url, required this.title});
  final String url;
  final String title;
}