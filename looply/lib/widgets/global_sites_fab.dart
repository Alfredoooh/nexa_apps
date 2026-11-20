import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navegador raiz partilhado pelos controlos globais do BrowseIt.
final GlobalKey<NavigatorState> browseItNavigatorKey = GlobalKey<NavigatorState>();

/// AssistiveTouch BrowseIt: controlo circular arrastável, com encaixe lateral,
/// que abre uma paper sheet vazia. A geometria e as transições seguem o HTML
/// de referência enviado: 58 px, sombra subtil, backdrop a 18% e sheet afastada
/// de todas as margens.
class GlobalSitesFloatingButton extends StatefulWidget {
  const GlobalSitesFloatingButton({super.key});

  @override
  State<GlobalSitesFloatingButton> createState() => _GlobalSitesFloatingButtonState();
}

class _GlobalSitesFloatingButtonState extends State<GlobalSitesFloatingButton> {
  static const double _size = 58;
  static const String _positionKey = 'browseit_assistive_touch_position_v2';

  Offset? _position;
  Offset? _dragStart;
  bool _dragging = false;
  bool _modalOpen = false;
  bool _modalVisible = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Offset _clamp(Offset value, Size size) => Offset(
        value.dx.clamp(6.0, (size.width - _size - 6).clamp(6.0, double.infinity)).toDouble(),
        value.dy.clamp(6.0, (size.height - _size - 6).clamp(6.0, double.infinity)).toDouble(),
      );

  Offset _defaultPosition(Size size, EdgeInsets safe) => Offset(
        size.width - safe.right - 18 - _size,
        size.height - safe.bottom - 110 - _size,
      );

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble('${_positionKey}_x');
      final y = prefs.getDouble('${_positionKey}_y');
      if (!mounted || x == null || y == null) return;
      setState(() => _position = Offset(x, y));
    } catch (_) {}
  }

  Future<void> _persistPosition() async {
    final value = _position;
    if (value == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_positionKey}_x', value.dx);
      await prefs.setDouble('${_positionKey}_y', value.dy);
    } catch (_) {}
  }

  void _openModal() {
    if (_modalOpen || _dragging) return;
    _closeTimer?.cancel();
    setState(() {
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
      if (mounted) setState(() => _modalOpen = false);
    });
  }

  void _onDragStart(DragStartDetails details, Offset current) {
    if (_modalOpen) return;
    setState(() {
      _dragging = true;
      _dragStart = current;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, Size size) {
    final origin = _dragStart;
    if (origin == null) return;
    setState(() => _position = _clamp((_position ?? origin) + details.delta, size));
  }

  void _onDragEnd(Size size) {
    final current = _position;
    if (current == null) {
      setState(() { _dragging = false; _dragStart = null; });
      return;
    }
    final left = current.dx + _size / 2 < size.width / 2 ? 8.0 : size.width - _size - 8.0;
    setState(() {
      _dragging = false;
      _dragStart = null;
      _position = _clamp(Offset(left, current.dy), size);
    });
    unawaited(_persistPosition());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final position = _clamp(_position ?? _defaultPosition(size, media.viewPadding), size);
    if (_position == null || position != _position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_modalOpen) setState(() => _position = position);
      });
    }

    final availableHeight = size.height <= 480
        ? (size.height * .48).clamp(150.0, 260.0).toDouble()
        : (size.height * .44).clamp(230.0, 390.0).toDouble();
    final modalPadding = EdgeInsets.fromLTRB(
      media.viewPadding.left > 16 ? media.viewPadding.left : 16,
      media.viewPadding.top > 16 ? media.viewPadding.top : 16,
      media.viewPadding.right > 16 ? media.viewPadding.right : 16,
      (media.viewPadding.bottom + 16) > 16 ? media.viewPadding.bottom + 16 : 16,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // O botão mantém-se na árvore durante a abertura/fecho, tal como no
        // HTML: desaparece com scale + opacity e fica atrás do backdrop.
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
              opacity: _modalVisible ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _onDragStart(details, position),
                onPanUpdate: (details) => _onDragUpdate(details, size),
                onPanEnd: (_) => _onDragEnd(size),
                onPanCancel: () => _onDragEnd(size),
                onTap: _openModal,
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
                            constraints: BoxConstraints(
                              maxWidth: 560,
                              maxHeight: availableHeight,
                              minHeight: size.height <= 480 ? 150 : 230,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0x0B000000)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x29000000), blurRadius: 38, offset: Offset(0, 12)),
                                BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
                              ],
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
