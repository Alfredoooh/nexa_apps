// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/widgets/auth_widgets.dart
// Componentes visuais partilhados pelas telas de autenticação.
// Botões sólidos, sem boxShadow / sem gradiente de elevação.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:animated_check/animated_check.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_check/animated_check.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';

// ── SNACKBAR DE ERRO PARTILHADO ──

void showAuthSnackBar(BuildContext context, String message) {
  final s = AppTheme.of(context);
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.cardBackground,
      content: Row(
        children: [
          AppIcon('error.svg', size: 16, color: s.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13.5, color: s.onSurface),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

// ── LOGO ANIMADO — mesma animação de sempre, sem alterações de fundo ──

class AnimatedAuthLogo extends StatefulWidget {
  final double size;
  const AnimatedAuthLogo({super.key, required this.size});

  @override
  State<AnimatedAuthLogo> createState() => _AnimatedAuthLogoState();
}

class _AnimatedAuthLogoState extends State<AnimatedAuthLogo>
    with TickerProviderStateMixin {
  late final AnimationController _gradientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _shimmerCtrl.repeat();
    });
  }

  @override
  void dispose() {
    _gradientCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final isDark = s.isDark;

    final List<Color> gradientColors = isDark
        ? const [
            Color(0xFFB8BEC7),
            Color(0xFFE8ECF0),
            Color(0xFFFFFFFF),
            Color(0xFFCDD2D8),
            Color(0xFFB8BEC7),
          ]
        : [
            s.primary.withOpacity(0.7),
            s.primary,
            s.primary.withOpacity(0.85),
            s.primary,
          ];

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _gradientCtrl,
            builder: (context, _) {
              final t = _gradientCtrl.value;
              final pingPong = t < 0.5 ? t * 2 : (1 - t) * 2;
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-1 + pingPong * 0.4, -1),
                  end: Alignment(1 - pingPong * 0.4, 1),
                  colors: gradientColors,
                ).createShader(rect),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (context, _) {
              final raw = _shimmerCtrl.value;
              final progress = raw < 0.55 ? (raw / 0.55) : 1.0;
              final pos = -1.2 + progress * 2.4;
              return Opacity(
                opacity: isDark ? 0.95 : 0.55,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment(pos - 0.35, pos - 0.35),
                    end: Alignment(pos + 0.35, pos + 0.35),
                    colors: const [
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: const [0.35, 0.50, 0.65],
                  ).createShader(rect),
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── LOGO FALLBACK (usado no AuthGate enquanto status é "unknown") ──

class AuthLogoFallback extends StatelessWidget {
  final AppColorScheme s;
  final bool pulsing;
  const AuthLogoFallback({super.key, required this.s, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/images/logo.png',
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('N',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: s.onPrimary)),
        ),
      ),
    );
    if (!pulsing) return logo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.ease,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: value, child: child),
      ),
      child: logo,
    );
  }
}

// ── FRASES EM STREAMING ──
// Mantido no ficheiro para não partir imports antigos, mas deixou
// de ser usado em LoginScreen a pedido (textos que aparecem e
// desaparecem foram removidos dessa tela).

class StreamingPhrases extends StatefulWidget {
  const StreamingPhrases({super.key});

  @override
  State<StreamingPhrases> createState() => _StreamingPhrasesState();
}

class _StreamingPhrasesState extends State<StreamingPhrases>
    with TickerProviderStateMixin {
  static const _phrases = [
    'Descubra mais sobre o universo com a nexa ai',
    'Explore ideias sem limites, uma pergunta de cada vez',
    'Inteligência que aprende com você, todos os dias',
    'Bem-vindo ao nexa ai',
  ];

  static const _holdTime = Duration(milliseconds: 2200);
  static const _fadeTime = Duration(milliseconds: 700);
  static const _gapTime = Duration(milliseconds: 300);

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: _fadeTime,
  );
  late final AnimationController _cursorCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _runCycle();
  }

  Future<void> _runCycle() async {
    while (mounted) {
      await _fadeCtrl.forward();
      final isLast = _index == _phrases.length - 1;
      if (isLast) return;
      await Future.delayed(_holdTime);
      if (!mounted) return;
      await _fadeCtrl.reverse();
      if (!mounted) return;
      await Future.delayed(_gapTime);
      if (!mounted) return;
      setState(() => _index++);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final textStyle = GoogleFonts.spaceGrotesk(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: s.onSurface,
      shadows: [
        Shadow(
            color: s.isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 1)),
      ],
    );

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: _phrases[_index]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: AnimatedBuilder(
              animation: _cursorCtrl,
              builder: (context, _) => Opacity(
                opacity: 0.15 + (_cursorCtrl.value * 0.85),
                child: Text('_', style: textStyle),
              ),
            ),
          ),
        ]),
        textAlign: TextAlign.center,
        style: textStyle,
      ),
    );
  }
}

// ── CAMPO DE TEXTO — borda 100% curva (pílula) ──

class AuthField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final String? errorText;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const AuthField({
    super.key,
    required this.ctrl,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hasError
                  ? s.error
                  : _focused
                      ? s.primary.withOpacity(0.6)
                      : s.outline.withOpacity(0.45),
              width: _focused || hasError ? 1.5 : 1.0,
            ),
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextField(
              controller: widget.ctrl,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              focusNode: widget.focusNode,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(fontSize: 15, color: s.onSurface),
              cursorColor: s.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                hintText: widget.hint,
                hintStyle: TextStyle(
                    fontSize: 15,
                    color: s.onSurfaceVariant.withOpacity(0.6)),
                suffixIcon: widget.suffix,
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 44, minHeight: 24),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(widget.errorText!,
                style: TextStyle(fontSize: 12, color: s.error)),
          ),
      ],
    );
  }
}

// ── BOTÃO PRIMÁRIO — pill sólida, sem sombra ──

class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final disabled = widget.onTap == null || widget.loading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!disabled) setState(() => _p = true);
      },
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: disabled ? null : widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? s.primary.withOpacity(0.5) : s.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(s.onPrimary),
                  ),
                )
              : Text(widget.label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: s.onPrimary)),
        ),
      ),
    );
  }
}

// ── BOTÃO SECUNDÁRIO — contorno sólido, sem sombra ──

class AuthSecondaryButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool disabledLook;
  const AuthSecondaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.disabledLook = false,
  });

  @override
  State<AuthSecondaryButton> createState() => _AuthSecondaryButtonState();
}

class _AuthSecondaryButtonState extends State<AuthSecondaryButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 54,
          decoration: BoxDecoration(
            color: _p ? s.hover : s.cardBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.outline.withOpacity(0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(s.onSurface),
                  ),
                )
              else ...[
                Opacity(
                  opacity: widget.disabledLook ? 0.45 : 1.0,
                  child: widget.icon,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.disabledLook
                              ? s.onSurface.withOpacity(0.45)
                              : s.onSurface)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── BOTÃO VOLTAR CIRCULAR — sólido, sem sombra ──

class AuthBackButton extends StatefulWidget {
  final AppColorScheme s;
  const AuthBackButton({super.key, required this.s});

  @override
  State<AuthBackButton> createState() => _AuthBackButtonState();
}

class _AuthBackButtonState extends State<AuthBackButton> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: s.outline.withOpacity(0.35)),
        ),
        child: AppIcon('back', color: s.onSurface, size: 18),
      ),
    );
  }
}

// ── BANNER DE ERRO ──

class AuthErrorBanner extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  const AuthErrorBanner({super.key, required this.s, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: s.error.withOpacity(s.isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: s.error.withOpacity(0.35)),
        ),
        child: Row(children: [
          AppIcon('error.svg', color: s.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: s.error,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

// ── ÍCONE GOOGLE ──

class GoogleIcon extends StatelessWidget {
  final double size;
  const GoogleIcon({super.key, required this.size});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>
<path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>
<path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238C29.211 35.091 26.715 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>
<path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 0 1-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: size, height: size);
}

// ── ÍCONE CADEADO (para "Continuar com a Password") ──

class LockIcon extends StatelessWidget {
  final double size;
  final Color color;
  const LockIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      Icon(RoundedSymbols.lock, size: size, color: color);
}

// ── RADIO DE TERMOS — "Li e aceito Termos de Utilização e Política
// de Privacidade", com os dois links sublinhados e clicáveis ──

class AuthTermsRadio extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  const AuthTermsRadio({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  @override
  State<AuthTermsRadio> createState() => _AuthTermsRadioState();
}

class _AuthTermsRadioState extends State<AuthTermsRadio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    if (widget.value) _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant AuthTermsRadio old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onChanged(!widget.value),
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: SizedBox(
              width: 22,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.value
                        ? s.primary
                        : s.outline.withOpacity(0.6),
                    width: 1.6,
                  ),
                  color: widget.value ? s.primary : Colors.transparent,
                ),
                child: AnimatedCheck(
                  progress: _ctrl,
                  color: s.onPrimary,
                  size: 12,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(!widget.value),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: s.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'Li e aceito '),
                  TextSpan(
                    text: 'Termos de Utilização',
                    style: TextStyle(
                      color: s.onSurface,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: s.onSurface,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = widget.onTapTerms,
                  ),
                  const TextSpan(text: ' e '),
                  TextSpan(
                    text: 'Política de Privacidade',
                    style: TextStyle(
                      color: s.onSurface,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: s.onSurface,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = widget.onTapPrivacy,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}