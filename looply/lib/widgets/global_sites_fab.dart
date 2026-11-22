import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart' show assistiveTouchEnabled;
import '../screens/ai_search_screen.dart';
import '../theme.dart';

/// Navigator raiz utilizado pelo AssistiveTouch para abrir páginas acima das tabs.
final GlobalKey<NavigatorState> browseItNavigatorKey = GlobalKey<NavigatorState>();

/// AssistiveTouch persistente, arrastável e disponível em todas as telas.
/// A sheet replica a paper sheet flutuante do HTML de referência.
class GlobalSitesFloatingButton extends StatefulWidget {
  const GlobalSitesFloatingButton({super.key});

  @override
  State<GlobalSitesFloatingButton> createState() => _GlobalSitesFloatingButtonState();
}

class _GlobalSitesFloatingButtonState extends State<GlobalSitesFloatingButton> {
  static const double _size = 58;
  static const String _positionKey = 'browseit_assistive_touch_position_v2';
  static const Duration _idleDelay = Duration(seconds: 7);

  Offset? _position;
  Offset? _dragStart;
  bool _dragging = false;
  bool _modalOpen = false;
  bool _modalVisible = false;
  bool _dimmed = false;
  Timer? _closeTimer;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    assistiveTouchEnabled.addListener(_onEnabledChanged);
    _restorePosition();
    if (assistiveTouchEnabled.value) _armIdleTimer();
  }

  void _onEnabledChanged() {
    if (!mounted) return;
    if (!assistiveTouchEnabled.value) {
      _idleTimer?.cancel();
      _closeTimer?.cancel();
      setState(() {
        _dimmed = false;
        _modalOpen = false;
        _modalVisible = false;
        _dragging = false;
        _dragStart = null;
      });
      return;
    }
    _armIdleTimer();
    setState(() {});
  }

  @override
  void dispose() {
    assistiveTouchEnabled.removeListener(_onEnabledChanged);
    _closeTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  Offset _clamp(Offset value, Size size, EdgeInsets safe) {
    final minX = safe.left + 6.0;
    final minY = safe.top + 6.0;
    final maxX = math.max(minX, size.width - safe.right - _size - 6.0);
    final maxY = math.max(minY, size.height - safe.bottom - _size - 6.0);
    return Offset(
      value.dx.clamp(minX, maxX).toDouble(),
      value.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Offset _defaultPosition(Size size, EdgeInsets safe) => Offset(
        size.width - safe.right - 18 - _size,
        size.height - safe.bottom - 110 - _size,
      );

  void _armIdleTimer() {
    _idleTimer?.cancel();
    if (!assistiveTouchEnabled.value) return;
    if (_dimmed && mounted) setState(() => _dimmed = false);
    _idleTimer = Timer(_idleDelay, () {
      if (mounted && assistiveTouchEnabled.value && !_modalOpen && !_dragging) {
        setState(() => _dimmed = true);
      }
    });
  }

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble('${_positionKey}_x');
      final y = prefs.getDouble('${_positionKey}_y');
      if (!mounted || x == null || y == null) return;
      setState(() => _position = Offset(x, y));
    } catch (_) {
      // A posição é apenas uma preferência visual; falha de leitura não bloqueia o app.
    }
  }

  Future<void> _persistPosition() async {
    final current = _position;
    if (current == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_positionKey}_x', current.dx);
      await prefs.setDouble('${_positionKey}_y', current.dy);
    } catch (_) {}
  }

  void _openModal() {
    if (_modalOpen || _dragging || !assistiveTouchEnabled.value) return;
    _idleTimer?.cancel();
    _closeTimer?.cancel();
    setState(() {
      _dimmed = false;
      _modalOpen = true;
      _modalVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _modalOpen) setState(() => _modalVisible = true);
    });
  }

  void _closeModal() {
    if (!_modalOpen) return;
    setState(() => _modalVisible = false);
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 290), () {
      if (!mounted) return;
      setState(() => _modalOpen = false);
      _armIdleTimer();
    });
  }

  void _openAiSearch() {
    if (!_modalOpen) return;
    _closeModal();
    // Espera a sheet terminar a animação de saída antes de navegar.
    Future<void>.delayed(const Duration(milliseconds: 305), () {
      if (!mounted || !assistiveTouchEnabled.value) return;
      browseItNavigatorKey.currentState?.push<void>(
        CupertinoPageRoute<void>(builder: (_) => const AiSearchScreen()),
      );
    });
  }

  void _onDragStart(DragStartDetails details, Offset current) {
    if (_modalOpen) return;
    _idleTimer?.cancel();
    setState(() {
      _dimmed = false;
      _dragging = true;
      _dragStart = current;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, Size size, EdgeInsets safe) {
    final origin = _dragStart;
    if (origin == null) return;
    setState(() => _position = _clamp((_position ?? origin) + details.delta, size, safe));
  }

  void _onDragEnd(Size size, EdgeInsets safe) {
    final current = _position;
    if (current == null) {
      setState(() {
        _dragging = false;
        _dragStart = null;
      });
      _armIdleTimer();
      return;
    }
    final onLeft = current.dx + _size / 2 < size.width / 2;
    final left = onLeft ? 8.0 : size.width - _size - 8.0;
    setState(() {
      _dragging = false;
      _dragStart = null;
      _position = _clamp(Offset(left, current.dy), size, safe);
    });
    unawaited(_persistPosition());
    _armIdleTimer();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: assistiveTouchEnabled,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return _buildAssistiveStack(context);
      },
    );
  }

  Widget _buildAssistiveStack(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final position = _clamp(_position ?? _defaultPosition(size, media.viewPadding), size, media.viewPadding);
    if (_position == null || position != _position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_modalOpen) setState(() => _position = position);
      });
    }

    final availableHeight = size.height <= 480
        ? (size.height * .48).clamp(150.0, 260.0).toDouble()
        : (size.height * .44).clamp(230.0, 390.0).toDouble();
    // Margens compactas, mas sempre positivas mesmo em aparelhos com recortes.
    double edge(double safe) => safe > 0 ? safe + 7 : 12;
    final modalPadding = EdgeInsets.fromLTRB(
      edge(media.viewPadding.left),
      edge(media.viewPadding.top),
      edge(media.viewPadding.right),
      edge(media.viewPadding.bottom),
    );
    final modalSurface = popupSurfaceColor(context);
    final modalText = mainText(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPositioned(
          duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
          curve: const Cubic(.2, .8, .2, 1),
          left: position.dx,
          top: position.dy,
          width: _size,
          height: _size,
          child: IgnorePointer(
            ignoring: _modalOpen,
            child: AnimatedOpacity(
              opacity: _modalVisible ? 0 : (_dimmed ? .56 : 1),
              duration: const Duration(milliseconds: 680),
              curve: Curves.easeInOut,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _onDragStart(details, position),
                onPanUpdate: (details) => _onDragUpdate(details, size, media.viewPadding),
                onPanEnd: (_) => _onDragEnd(size, media.viewPadding),
                onPanCancel: () => _onDragEnd(size, media.viewPadding),
                onTap: () {
                  _armIdleTimer();
                  _openModal();
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _modalVisible ? .88 : (_dragging ? 1.04 : 1),
                  child: const _AssistiveTouchVisual(),
                ),
              ),
            ),
          ),
        ),
        if (_modalOpen) ...[
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_modalVisible,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeModal,
                child: AnimatedOpacity(
                  opacity: _modalVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: const ColoredBox(color: Color(0x2E000000)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_modalVisible,
              child: Padding(
                padding: modalPadding,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: AnimatedSlide(
                      offset: _modalVisible ? Offset.zero : const Offset(0, .075),
                      duration: const Duration(milliseconds: 280),
                      curve: const Cubic(.2, .8, .2, 1),
                      child: AnimatedScale(
                        scale: _modalVisible ? 1 : .985,
                        duration: const Duration(milliseconds: 280),
                        curve: const Cubic(.2, .8, .2, 1),
                        child: AnimatedOpacity(
                          opacity: _modalVisible ? 1 : .94,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: double.infinity,
                            height: availableHeight,
                            constraints: BoxConstraints(maxWidth: 560, maxHeight: availableHeight),
                            decoration: BoxDecoration(
                              color: modalSurface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: lineColor(context).withOpacity(.16)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x29000000), blurRadius: 38, offset: Offset(0, 12)),
                                BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _AssistiveAppTile(
                                  iconColor: modalText,
                                  onTap: _openAiSearch,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AssistiveAppTile extends StatelessWidget {
  const _AssistiveAppTile({required this.iconColor, required this.onTap});
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'AI Search',
      child: SizedBox(
        width: 76,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(19),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: pillColor(context),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/ai_search/ai.png',
                    width: 37,
                    height: 37,
                    fit: BoxFit.contain,
                    color: iconColor,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 7),
                Text('AI', style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistiveTouchVisual extends StatelessWidget {
  const _AssistiveTouchVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 9, offset: Offset(0, 2))],
      ),
      child: ClipOval(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest.shortestSide;
            Widget ring(double fraction, Color color) => Container(
                  width: size * fraction,
                  height: size * fraction,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                );
            return SizedBox(
              width: 58,
              height: 58,
              child: Stack(alignment: Alignment.center, children: [
                const Positioned.fill(child: ColoredBox(color: Color(0xFF202A34))),
                ring(.76, const Color(0xFF60676B)),
                ring(.64, const Color(0xFF969B9F)),
                ring(.46, Colors.white),
              ]),
            );
          },
        ),
      ),
    );
  }
}
