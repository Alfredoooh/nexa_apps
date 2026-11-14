// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/app_detail_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemUiOverlayStyle;
import '../../core/theme/colors.dart';
import '../../widgets/widgets.dart';
import '../../core/navigation/app_page_route.dart';
import 'app_types.dart';
import 'registry/app_registry.dart';


class AppDetailScreen extends StatelessWidget {
  final AppEntry app;
  const AppDetailScreen({super.key, required this.app});

  /// Navega para o ecrã real do app (chamado pelo botão "Abrir aplicativo").
  static void openApp(BuildContext context, AppEntry app) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppPageRoute(builder: app.builder),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final s = AppTheme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackSheet(s: s, app: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          _DetailBackButton(s: s, onTap: () => Navigator.pop(context)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                        children: [
                          _AppHeader(s: s, app: app),
                          const SizedBox(height: 28),
                          _SectionTitle(s: s, text: 'Para que serve'),
                          const SizedBox(height: 10),
                          Text(
                            app.manifest.longDescription,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              color: s.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _SectionTitle(s: s, text: 'Funcionalidades'),
                          const SizedBox(height: 10),
                          ...app.manifest.features.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FeatureRow(s: s, text: f),
                            ),
                          ),
                          const SizedBox(height: 26),
                          _SectionTitle(s: s, text: 'Classificações e críticas'),
                          const SizedBox(height: 10),
                          _RatingsCard(s: s),
                          const SizedBox(height: 26),
                          _SectionTitle(s: s, text: 'Assistente de IA'),
                          const SizedBox(height: 10),
                          _AiConnectSwitchRow(s: s, app: app),
                          const SizedBox(height: 20),
                          _FeedbackRow(s: s, onTap: () => _showFeedbackSheet(context)),
                        ],
                      ),
                    ),
                  ],
                ),
                // Botão fixo no fundo, mesmo padrão do _LogoutButton em
                // Settings: container com gradiente fade-to-transparent,
                // sem glow/sombra colorida no botão em si.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          s.pageBackground,
                          s.pageBackground.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: _OpenAppButton(
                        s: s,
                        onTap: () => AppDetailScreen.openApp(context, app),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  final AppColorScheme s;
  final AppEntry app;
  const _AppHeader({required this.s, required this.app});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(app.manifest.isCircularIcon ? 38 : 20),
          child: Container(
            width: 76,
            height: 76,
            color: app.manifest.isCircularIcon ? Colors.white : Colors.transparent,
            child: Image.asset(app.manifest.iconAsset, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.manifest.label,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: s.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                app.manifest.description,
                style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  const _SectionTitle({required this.s, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w800,
        color: s.onSurface,
      ),
    );
  }
}

// Funcionalidades como bullet points (•), sem ícones.
class _FeatureRow extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  const _FeatureRow({required this.s, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: s.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14.5, height: 1.4, color: s.onSurface),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CLASSIFICAÇÕES E CRÍTICAS — desativado por agora.
// Número grande "0.0", 5 estrelas outline (star.svg), e 5 progress
// bars (5→1) vazias. Tudo com opacidade reduzida para ler como
// funcionalidade ainda por chegar.
// ══════════════════════════════════════════════════════════════

class _RatingsCard extends StatelessWidget {
  final AppColorScheme s;
  const _RatingsCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: s.cardShadowSoft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Número + estrelas
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '0.0',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: s.onSurface,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (_) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: AppIcon('star', size: 14, color: s.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Barras 5 → 1
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    return Padding(
                      padding: EdgeInsets.only(bottom: star == 1 ? 0 : 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 12,
                            child: Text(
                              '$star',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: 0,
                                minHeight: 6,
                                backgroundColor: s.hover,
                                valueColor:
                                    AlwaysStoppedAnimation(s.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SWITCH "Ligar ao Nexa AI" — mesmo visual pill do
// _ThemeSegmentedControl em Settings (thumb animado dentro de trilho).
// ══════════════════════════════════════════════════════════════

class _AiConnectSwitchRow extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  const _AiConnectSwitchRow({required this.s, required this.app});

  @override
  State<_AiConnectSwitchRow> createState() => _AiConnectSwitchRowState();
}

class _AiConnectSwitchRowState extends State<_AiConnectSwitchRow> {
  @override
  void initState() {
    super.initState();
    enabledAppsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    enabledAppsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final slug = widget.app.manifest.slug;
    final value = enabledAppsController.isEnabled(slug);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: s.cardShadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ligar ao Nexa AI',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: s.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.app.manifest.aiToggleDescription,
                  style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PillSwitch(
            s: s,
            value: value,
            onChanged: (v) => enabledAppsController.setEnabled(slug, v),
          ),
        ],
      ),
    );
  }
}

class _PillSwitch extends StatelessWidget {
  final AppColorScheme s;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PillSwitch({
    required this.s,
    required this.value,
    required this.onChanged,
  });

  static const double _width = 48;
  static const double _height = 28;
  static const double _thumbSize = 22;
  static const double _padding = 3;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: _width,
        height: _height,
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: value ? s.primary : s.hover,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: _thumbSize,
            height: _thumbSize,
            decoration: BoxDecoration(
              color: value ? s.onPrimary : s.cardBackground,
              shape: BoxShape.circle,
              boxShadow: s.cardShadow,
            ),
          ),
        ),
      ),
    );
  }
}

// Row "Enviar feedback" — usa comment.svg, é a única entrada de
// feedback agora que o botão do topo foi removido.
class _FeedbackRow extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _FeedbackRow({required this.s, required this.onTap});

  @override
  State<_FeedbackRow> createState() => _FeedbackRowState();
}

class _FeedbackRowState extends State<_FeedbackRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pressed ? s.hover : s.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: s.cardShadowSoft,
        ),
        child: Row(
          children: [
            AppIcon('comment', size: 19, color: s.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enviar feedback',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: s.onSurface,
                ),
              ),
            ),
            Icon(RoundedSymbols.chevronRight, size: 17, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO "Abrir aplicativo" — sólido, sem glow/sombra colorida.
// Vive dentro do container com gradiente fixo no fundo do ecrã.
// ══════════════════════════════════════════════════════════════

class _OpenAppButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _OpenAppButton({required this.s, required this.onTap});

  @override
  State<_OpenAppButton> createState() => _OpenAppButtonState();
}

class _OpenAppButtonState extends State<_OpenAppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Abrir aplicativo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: s.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  const _FeedbackSheet({required this.s, required this.app});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    // TODO: enviar `text` + `widget.app.manifest.slug` para o backend (Cloudflare Worker)
    Navigator.of(context).pop();
    if (text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obrigado pelo teu feedback!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: s.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Enviar feedback',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sobre ${widget.app.manifest.label}',
              style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: s.hover,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 4,
                style: TextStyle(fontSize: 14.5, color: s.onSurface),
                decoration: InputDecoration(
                  hintText: 'Escreve aqui a tua sugestão ou problema...',
                  hintStyle: TextStyle(color: s.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Enviar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _DetailBackButton({required this.s, required this.onTap});
  @override
  State<_DetailBackButton> createState() => _DetailBackButtonState();
}

class _DetailBackButtonState extends State<_DetailBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: AppIcon('back', size: 18, color: widget.s.onSurface),
        ),
      ),
    );
  }
}