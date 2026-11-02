import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../auth_service.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _emailMode = false;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _busy = true);
    try {
      await authController.signInWithGoogle();
      if (!mounted) return;
      if (authController.value != null) Navigator.of(context).pop();
    } on PlatformException catch (error) {
      if (mounted) _showMessage(_googleErrorMessage(error));
    } catch (_) {
      if (mounted) _showMessage('Não foi possível iniciar o Google Sign-In. Confirma a configuração OAuth do Android.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _googleErrorMessage(PlatformException error) {
    final message = error.message?.toLowerCase() ?? '';
    if (message.contains('developer_error') || message.contains('10')) {
      return 'Configuração OAuth incompleta: falta associar o applicationId e a SHA-1 ao cliente Google do projeto.';
    }
    return error.message ?? 'O início de sessão Google foi cancelado ou falhou.';
  }

  Future<void> _emailSignIn() async {
    setState(() => _busy = true);
    try {
      await authController.signInWithEmail(_emailController.text, _passwordController.text);
      if (mounted && authController.value != null) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage(error is StateError
          ? 'Login por email indisponível: é necessário configurar um backend de autenticação (por exemplo, Firebase Auth).'
          : error.toString().replaceFirst('Invalid argument(s): ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('Log in / Sign in'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(color: accent.withOpacity(.13), shape: BoxShape.circle),
                    child: Icon(Symbols.person_rounded, size: 38, color: accent),
                  ),
                  const SizedBox(height: 20),
                  Text('Bem-vindo ao Looply', style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Inicia sessão para manter os teus dados associados à tua conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _googleSignIn,
                      icon: const Icon(Icons.account_circle_outlined, size: 22),
                      label: const Text('Continuar com Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: text,
                        side: BorderSide(color: lineColor(context)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => setState(() => _emailMode = !_emailMode),
                      icon: const Icon(Symbols.mail_rounded, size: 20),
                      label: Text(_emailMode ? 'Ocultar login por email' : 'Continuar com email'),
                      style: FilledButton.styleFrom(
                        foregroundColor: text,
                        backgroundColor: pillColor(context),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  if (_emailMode) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: TextStyle(color: text),
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Symbols.mail_outline_rounded)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                        labelText: 'Palavra-passe',
                        prefixIcon: const Icon(Symbols.lock_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _busy ? null : _emailSignIn,
                        child: const Text('Entrar'),
                      ),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 18),
                    const CircularProgressIndicator(),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'A autenticação por email depende da ligação a um serviço de contas. O Google usa o seletor nativo do dispositivo quando a configuração OAuth estiver concluída.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted.withOpacity(.9), fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
