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
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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
      if (mounted) {
        _showMessage(
          'Não foi possível iniciar o Google Sign-In. Confirma a configuração OAuth do Android.',
        );
      }
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
      await authController.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (mounted && authController.value != null) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error is StateError
            ? 'Login por email indisponível: é necessário configurar um backend de autenticação (por exemplo, Firebase Auth).'
            : error.toString().replaceFirst('Invalid argument(s): ', ''),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final muted = mutedText(context);
    final accent = accentColor(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: lineColor(context).withOpacity(.9)),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: muted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: pillColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      labelStyle: TextStyle(color: muted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 62,
        automaticallyImplyLeading: false,
        backgroundColor: pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        leading: IconButton(
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Symbols.close_rounded, color: text, size: 23),
        ),
        title: Text(
          'Log in / Sign in',
          style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: pillColor(context),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(7),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/looply_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Bem-vindo ao Looply',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: text,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicia sessão para manter os teus dados associados à tua conta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: _inputDecoration(
                        context,
                        label: 'Email',
                        icon: Symbols.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 13),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      enabled: !_busy,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!_busy) _emailSignIn();
                      },
                      style: TextStyle(color: text, fontSize: 14),
                      decoration: _inputDecoration(
                        context,
                        label: 'Palavra-passe',
                        icon: Symbols.lock_rounded,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Mostrar palavra-passe' : 'Ocultar palavra-passe',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Symbols.visibility_rounded
                                : Symbols.visibility_off_rounded,
                            size: 20,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _emailSignIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: accent.withOpacity(.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Entrar',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: Divider(color: lineColor(context))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          child: Text(
                            'ou',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider(color: lineColor(context))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _googleSignIn,
                        icon: Image.asset(
                          'assets/images/quick_sites/google.webp',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                        label: const Text('Continuar com Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: text,
                          side: BorderSide(color: lineColor(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'A autenticação por email depende de um serviço de contas configurado. O Google abre o seletor nativo quando a configuração OAuth estiver concluída.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted.withOpacity(.9), fontSize: 11, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
