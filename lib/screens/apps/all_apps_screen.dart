// ══════════════════════════════════════════════════════════════
// FILE: lib/features/all_apps/all_apps_screen.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, SystemUiOverlayStyle;
import 'package:animated_check/animated_check.dart';
import '../../core/theme/colors.dart';
import '../../widgets/widgets.dart';
import './registry/app_registry.dart';
import './app_detail_screen.dart';
import './app_shortcuts.dart';
import '../../core/navigation/app_page_route.dart';


class AllAppsScreen extends StatefulWidget {
  /// Se true, o ecrã abre já em modo de seleção (usado pelo botão "+"
  /// da secção de atalhos do drawer). Quando false, o ecrã comporta-se
  /// como antes (navegação normal para o detalhe do app).
  final bool startInSelectionMode;

  const AllAppsScreen({super.key, this.startInSelectionMode = false});

  @override
  State<AllAppsScreen> createState() => _AllAppsScreenState();
}

class _AllAppsScreenState extends State<AllAppsScreen> {
  late bool _selectionMode;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _selectionMode = widget.startInSelectionMode;
    if (_selectionMode) {
      // Apps já presentes nos atalhos entram pré-selecionados, para
      // que o utilizador consiga remover ou adicionar mais na mesma
      // operação, em vez de perder a seleção anterior.
      _selected.addAll(appShortcutsController.slugs);
    }
  }

  void _openAppDetail(BuildContext context, AppEntry app) {
    if (_selectionMode) {
      _toggleSelected(app.manifest.slug);
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => AppDetailScreen(app: app)),
    );
  }

  void _toggleSelected(String slug) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(slug)) {
        _selected.remove(slug);
      } else {
        _selected.add(slug);
      }
    });
  }

  void _enterSelectionMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selected
        ..clear()
        ..addAll(appShortcutsController.slugs);
    });
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  Future<void> _confirmSelection() async {
    if (_selected.isEmpty) return;
    HapticFeedback.mediumImpact();
    final count = _selected.length;
    // A seleção final passa a ser o estado completo dos atalhos,
    // o que permite tanto adicionar como remover na mesma operação.
    await appShortcutsController.replaceAll(_selected);
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
    final s = AppTheme.of(context);
    final message = count == 1
        ? 'Atalho adicionado com sucesso.'
        : '$count atalhos adicionados com sucesso.';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.cardBackground,
        content: Row(
          children: [
            AppIcon('check', size: 18, color: s.onSurface),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: s.onSurface,
                ),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _handleBackTap() {
    if (_selectionMode) {
      _exitSelectionMode();
    } else {
      Navigator.pop(context);
    }
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(children: [
                      _MorphingBackButton(
                        s: s,
                        selectionMode: _selectionMode,
                        onTap: _handleBackTap,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Apps',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: s.onSurface,
                          ),
                        ),
                      ),
                      _ConcludeButton(
                        s: s,
                        visible: _selectionMode,
                        enabled: _selected.isNotEmpty,
                        onTap: _confirmSelection,
                      ),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: _AppsGroup(
                      s: s,
                      apps: AppRegistry.all,
                      selectionMode: _selectionMode,
                      selected: _selected,
                      onTapApp: (app) => _openAppDetail(context, app),
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

// ══════════════════════════════════════════════════════════════
// GRUPO DE APPS — mesmo padrão visual de _SettingsGroup/_SettingsCard
// (cantos grandes só nas pontas do grupo, 2px entre linhas, cantos
// pequenos onde as linhas se tocam), mas com linhas mais altas para
// caber o ícone grande de cada app.
// ══════════════════════════════════════════════════════════════

class _AppsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<AppEntry> apps;
  final bool selectionMode;
  final Set<String> selected;
  final ValueChanged<AppEntry> onTapApp;
  const _AppsGroup({
    required this.s,
    required this.apps,
    required this.selectionMode,
    required this.selected,
    required this.onTapApp,
  });

  static const double _outerRadius = 20;
  static const double _innerRadius = 6;

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight: Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft: Radius.circular(isLast ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast ? _outerRadius : _innerRadius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < apps.length; i++) {
      final slug = apps[i].manifest.slug;
      children.add(_AppCard(
        s: s,
        radius: _radiusFor(i, apps.length),
        app: apps[i],
        index: i,
        selectionMode: selectionMode,
        isSelected: selected.contains(slug),
        onTap: () => onTapApp(apps[i]),
      ));
      if (i != apps.length - 1) children.add(const SizedBox(height: 2));
    }
    return Column(children: children);
  }
}

class _AppCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final AppEntry app;
  final int index;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  const _AppCard({
    required this.s,
    required this.radius,
    required this.app,
    required this.index,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: radius,
          boxShadow: s.cardShadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: _AppRow(
          s: s,
          app: app,
          index: index,
          selectionMode: selectionMode,
          isSelected: isSelected,
          onTap: onTap,
        ),
      );
}

class _AppRow extends StatefulWidget {
  final AppColorScheme s;
  final AppEntry app;
  final int index;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  const _AppRow({
    required this.s,
    required this.app,
    required this.index,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<_AppRow>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _enterController;
  late final Animation<double> _enterAnim;

  static const double _iconSize = 60;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _enterAnim = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) _enterController.forward();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return FadeTransition(
      opacity: _enterAnim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(_enterAnim),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: _pressed ? s.hover : Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    widget.app.manifest.isCircularIcon ? _iconSize / 2 : 16,
                  ),
                  child: Container(
                    width: _iconSize,
                    height: _iconSize,
                    color: widget.app.manifest.isCircularIcon
                        ? Colors.white
                        : Colors.transparent,
                    child: Image.asset(
                      widget.app.manifest.iconAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.app.manifest.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: s.onSurface,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.app.manifest.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: s.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: widget.selectionMode
                        ? _SelectionRadio(
                            key: const ValueKey('radio'),
                            s: s,
                            selected: widget.isSelected,
                          )
                        : Icon(
                            key: const ValueKey('chevron'),
                            RoundedSymbols.chevronRight,
                            size: 16,
                            color: s.onSurfaceVariant,
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

// ══════════════════════════════════════════════════════════════
// RADIO BUTTON DE SELEÇÃO — círculo com contorno; quando selecionado,
// preenche com a cor primária e desenha o checkmark com animação
// própria (AnimationController local, forward/reverse conforme o
// valor de `selected` muda), usando o widget real do pacote
// animated_check (AnimatedCheck(progress: Animation<double>, size: double, color)).
// ══════════════════════════════════════════════════════════════

class _SelectionRadio extends StatefulWidget {
  final AppColorScheme s;
  final bool selected;
  const _SelectionRadio({super.key, required this.s, required this.selected});

  @override
  State<_SelectionRadio> createState() => _SelectionRadioState();
}

class _SelectionRadioState extends State<_SelectionRadio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  static const double _size = 24;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.selected ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCirc);
  }

  @override
  void didUpdateWidget(covariant _SelectionRadio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        return Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(Colors.transparent, s.primary, t),
            border: Border.all(
              color: Color.lerp(
                s.onSurfaceVariant.withOpacity(0.45),
                s.primary,
                t,
              )!,
              width: 1.6,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedCheck(
            progress: _progress,
            size: 13.0,
            color: s.onPrimary,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO "Concluir" — surge no topo direito ao mesmo tempo que o
// botão de voltar troca para "close". Fica esmaecido/inativo
// enquanto nada estiver selecionado.
// ══════════════════════════════════════════════════════════════

class _ConcludeButton extends StatelessWidget {
  final AppColorScheme s;
  final bool visible;
  final bool enabled;
  final VoidCallback onTap;
  const _ConcludeButton({
    required this.s,
    required this.visible,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: visible
          ? _ConcludeButtonInner(
              key: const ValueKey('conclude-visible'),
              s: s,
              enabled: enabled,
              onTap: onTap,
            )
          : const SizedBox(key: ValueKey('conclude-hidden'), width: 0, height: 40),
    );
  }
}

class _ConcludeButtonInner extends StatefulWidget {
  final AppColorScheme s;
  final bool enabled;
  final VoidCallback onTap;
  const _ConcludeButtonInner({
    super.key,
    required this.s,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ConcludeButtonInner> createState() => _ConcludeButtonInnerState();
}

class _ConcludeButtonInnerState extends State<_ConcludeButtonInner> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final baseColor = s.primary;
    final color = widget.enabled ? baseColor : baseColor.withOpacity(0.35);
    final textColor = widget.enabled ? s.onPrimary : s.onPrimary.withOpacity(0.7);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Concluir',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO DE VOLTAR "MORFANTE" — troca entre "back" e "close.svg"
// com um efeito de encolher e nascer (scale down → scale up),
// igual ao pedido: suave e rápido.
// ══════════════════════════════════════════════════════════════

class _MorphingBackButton extends StatefulWidget {
  final AppColorScheme s;
  final bool selectionMode;
  final VoidCallback onTap;
  const _MorphingBackButton({
    required this.s,
    required this.selectionMode,
    required this.onTap,
  });

  @override
  State<_MorphingBackButton> createState() => _MorphingBackButtonState();
}

class _MorphingBackButtonState extends State<_MorphingBackButton> {
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
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: s.cardShadow,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: AppIcon(
              widget.selectionMode ? 'close' : 'back',
              key: ValueKey(widget.selectionMode ? 'close' : 'back'),
              size: 18,
              color: s.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}