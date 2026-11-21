import 'dart:async';

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

class _GlobalSitesFloatingButtonState extends State<GlobalSitesFloatingButton> with WidgetsBindingObserver {
  static const double _size = 58;
  static const String _positionKey = 'browseit_assistive_touch_position_v2';
  static const Duration _idleDelay = Duration(seconds: 7);

  Offset? _position;
  Offset? _dragStart;
  bool _dragging = false;
  bool _modalOpen = false;
  bool _dimmed = false;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    assistiveTouchEnabled.addListener(_onEnabledChanged);
    _restorePosition();
    if (assistiveTouchEnabled.value) _armIdleTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_restorePosition());
  }

  void _onEnabledChanged() {
    if (!mounted) return;
    if (!assistiveTouchEnabled.value) {
      _idleTimer?.cancel();
      setState(() {
        _dimmed = false;
        _modalOpen = false;
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
    WidgetsBinding.instance.removeObserver(this);
    assistiveTouchEnabled.removeListener(_onEnabledChanged);
    _idleTimer?.cancel();
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

  Future<void> _openModal() async {
    if (_modalOpen || _dragging || !assistiveTouchEnabled.value) return;
    _idleTimer?.cancel();
    setState(() { _dimmed = false; _modalOpen = true; });
    final media = MediaQuery.of(context);
    final height = media.size.height < 520 ? 220.0 : 300.0;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(.24),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 560, maxHeight: height),
                child: Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    color: popupSurfaceColor(sheetContext),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: lineColor(sheetContext).withOpacity(.16)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x29000000), blurRadius: 38, offset: Offset(0, 12)),
                      BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _AssistiveAppTile(
                      iconColor: mainText(sheetContext),
                      onTap: () {
                        Navigator.of(sheetContext, rootNavigator: true).pop();
                        Future<void>.delayed(const Duration(milliseconds: 260), _openAiSearch);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _modalOpen = false);
        _armIdleTimer();
      }
    }
  }

  void _openAiSearch() {
    if (!assistiveTouchEnabled.value || !mounted) return;
    browseItNavigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(builder: (_) => const AiSearchScreen()),
    );
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

  void _onDragUpdate(DragUpdateDetails details, Size size) {
    final origin = _dragStart;
    if (origin == null) return;
    setState(() => _position = _clamp((_position ?? origin) + details.delta, size));
  }

  void _onDragEnd(Size size) {
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
      _position = _clamp(Offset(left, current.dy), size);
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
    final position = _clamp(_position ?? _defaultPosition(size, media.viewPadding), size);
    if (_position == null || position != _position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_modalOpen) setState(() => _position = position);
      });
    }

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
          child: AnimatedOpacity(
            opacity: _dimmed ? .56 : 1,
            duration: const Duration(milliseconds: 680),
            curve: Curves.easeInOut,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => _onDragStart(details, position),
              onPanUpdate: (details) => _onDragUpdate(details, size),
              onPanEnd: (_) => _onDragEnd(size),
              onPanCancel: () => _onDragEnd(size),
              onTap: () { _armIdleTimer(); unawaited(_openModal()); },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: _dragging ? 1.04 : 1,
                child: const _AssistiveTouchVisual(),
              ),
            ),
          ),
        ),
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
