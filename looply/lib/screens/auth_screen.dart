import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_service.dart';
import '../localization.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';

enum _AuthBusy { none, email, google }

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
  _AuthBusy _busy = _AuthBusy.none;
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
    setState(() => _busy = _AuthBusy.google);
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
      if (mounted) setState(() => _busy = _AuthBusy.none);
    }
  }

  String _googleErrorMessage(PlatformException error) {
    if (error.code == 'google_web_client_id_missing') {
      return 'Falta criar um OAuth Client ID do tipo Web no Google Cloud e colocá-lo em BROWSEIT_GOOGLE_WEB_CLIENT_ID. O Client ID Android sozinho não emite o ID token destinado ao Worker.';
    }
    if (error.code == 'google_cancelled') {
      return 'O início de sessão Google foi cancelado.';
    }
    final message = error.message?.toLowerCase() ?? '';
    if (message.contains('developer_error') || message.contains('10')) {
      return 'Configuração OAuth Android incompleta: confirma o package com.looply.browser.app e a SHA-1 do certificado usado para assinar esta build.';
    }
    return error.message ?? 'O início de sessão Google falhou.';
  }

  Future<void> _emailSignIn() async {
    setState(() => _busy = _AuthBusy.email);
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
            ? 'O login por email ainda não está ativado no backend Cloudflare do BrowseIt.'
            : error.toString().replaceFirst('Invalid argument(s): ', ''),
      );
    } finally {
      if (mounted) setState(() => _busy = _AuthBusy.none);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Campo de texto com cápsula preenchida + borda tracejada desenhada
  /// por CustomPainter (o Flutter só suporta `solid`/`none` nativamente).
  Widget _dashedField({
    required FocusNode focusNode,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    final accent = accentColor(context);
    final base = lineColor(context);
    final textColor = mainText(context);
    final muted = mutedText(context);
    final enabled = _busy == _AuthBusy.none;

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        final focused = focusNode.hasFocus && enabled;
        final borderColor = !enabled
            ? base.withOpacity(.35)
            : focused
                ? accent
                : base.withOpacity(.75);
        return Container(
          decoration: BoxDecoration(
            color: pillColor(context),
            borderRadius: BorderRadius.circular(999),
          ),
          child: CustomPaint(
            foregroundPainter: _DashedRoundedBorderPainter(
              color: borderColor,
              strokeWidth: focused ? 1.5 : 1.1,
            ),
            child: child,
          ),
        );
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: muted.withOpacity(.85), fontSize: 14),
          prefixIcon: AppMaterialIcon(icon, size: 20, color: muted),
          suffixIcon: suffixIcon,
          filled: false,
          isCollapsed: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final anyBusy = _busy != _AuthBusy.none;
    final emailBusy = _busy == _AuthBusy.email;
    final googleBusy = _busy == _AuthBusy.google;

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 62,
        automaticallyImplyLeading: false,
        backgroundColor: pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Título verdadeiramente centrado, independente do botão fechar.
              Text(
                appText('auth_title'),
                style: TextStyle(
                  color: text,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.2,
                  height: 1.15,
                ),
              ),
              // Botão fechar dentro de um círculo, alinhado à esquerda.
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: appText('close'),
                  child: Material(
                    color: pillColor(context),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: AppMaterialIcon(
                            AppIcons.x,
                            color: text,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                      appText('welcome'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: text,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appText('sign_in_intro'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 30),
                    _dashedField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      hint: appText('email'),
                      icon: AppIcons.envelopeSimple,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 13),
                    _dashedField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      hint: appText('password'),
                      icon: AppIcons.lockSimple,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!anyBusy) _emailSignIn();
                      },
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? appText('show_password')
                            : appText('hide_password'),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: AppMaterialIcon(
                          _obscurePassword
                              ? AppIcons.eye
                              : AppIcons.eyeSlash,
                          size: 20,
                          color: muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: anyBusy ? null : _emailSignIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: accent.withOpacity(.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: emailBusy
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
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
                      child: OutlinedButton(
                        onPressed: anyBusy ? null : _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: text,
                          side: BorderSide(color: lineColor(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: googleBusy
                            // Estado a carregar: logo mantém-se, texto
                            // desaparece, loader aparece no centro.
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.google.com/s2/favicons?domain=google.com&sz=64',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              )
                            // Estado normal: logo + texto.
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.google.com/s2/favicons?domain=google.com&sz=64',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(appText('continue_google')),
                                ],
                              ),
                      ),
                    ),
                    // auth_info removido a pedido.
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

/// Desenha uma borda tracejada com cantos arredondados (pill-shape por
/// omissão, porque o raio é clampado automaticamente pelo RRect).
class _DashedRoundedBorderPainter extends CustomPainter {
  _DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      const Radius.circular(999),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}