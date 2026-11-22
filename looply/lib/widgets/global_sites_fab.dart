import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../browser_library.dart';
import '../localization.dart';
import '../models.dart';
import '../screens/ai_search_screen.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';
import 'looply_dialog.dart';
import 'material_symbols.dart';

/// Navigator raiz usado pelo AssistiveTouch para abrir páginas e separadores.
final GlobalKey<NavigatorState> browseItNavigatorKey = GlobalKey<NavigatorState>();

/// AssistiveTouch global: botão flutuante arrastável e uma paper sheet real,
/// apresentada por showModalBottomSheet (com dismiss, drag e insets nativos).
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
  bool _sheetOpen = false;
  bool _dimmed = false;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    assistiveTouchEnabled.addListener(_onEnabledChanged);
    unawaited(_restorePosition());
    if (assistiveTouchEnabled.value) _armIdleTimer();
  }

  void _onEnabledChanged() {
    if (!mounted) return;
    if (!assistiveTouchEnabled.value) {
      _idleTimer?.cancel();
      setState(() {
        _dimmed = false;
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
    if (!assistiveTouchEnabled.value || _sheetOpen || _dragging) return;
    if (_dimmed && mounted) setState(() => _dimmed = false);
    _idleTimer = Timer(_idleDelay, () {
      if (mounted && assistiveTouchEnabled.value && !_sheetOpen && !_dragging) {
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
      final media = MediaQuery.of(context);
      setState(() => _position = _clamp(Offset(x, y), media.size, media.viewPadding));
    } catch (_) {
      // Uma preferência visual inválida não deve interferir com o arranque.
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

  Future<void> _openPaperSheet() async {
    if (_sheetOpen || _dragging || !assistiveTouchEnabled.value) return;
    final navigatorContext = browseItNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    _idleTimer?.cancel();
    setState(() {
      _dimmed = false;
      _sheetOpen = true;
    });

    try {
      await showModalBottomSheet<void>(
        context: navigatorContext,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: true,
        isDismissible: true,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(.30),
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 360),
          reverseDuration: Duration(milliseconds: 270),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        builder: (sheetContext) => LooplyModalSystemBar(
          child: SafeArea(
            top: false,
            bottom: true,
            child: LooplyFloatingModalFrame(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _AssistiveSitesPaperSheet(
                onOpenAiSearch: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    browseItNavigatorKey.currentState?.push<void>(
                      CupertinoPageRoute<void>(builder: (_) => const AiSearchScreen()),
                    );
                  });
                },
                onOpenSite: (site) {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final navigator = browseItNavigatorKey.currentState;
                    if (navigator == null) return;
                    final tab = tabsController.createBrowserTab(site.url, title: site.title);
                    // Fecha qualquer rota secundária (AI Search, histórico etc.)
                    // para que o separador escolhido fique realmente visível.
                    navigator.popUntil((route) => route.isFirst);
                    ShellTabRequest.instance.requestBrowser(tab.id);
                  });
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sheetOpen = false);
        _armIdleTimer();
      }
    }
  }

  void _onDragStart(DragStartDetails details, Offset current) {
    if (_sheetOpen) return;
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
        return _buildFloatingControl(context);
      },
    );
  }

  Widget _buildFloatingControl(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final position = _clamp(_position ?? _defaultPosition(size, media.viewPadding), size, media.viewPadding);
    if (_position == null || position != _position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_sheetOpen) setState(() => _position = position);
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
          child: IgnorePointer(
            ignoring: _sheetOpen,
            child: AnimatedOpacity(
              opacity: _sheetOpen ? 0 : (_dimmed ? .56 : 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeInOut,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _onDragStart(details, position),
                onPanUpdate: (details) => _onDragUpdate(details, size, media.viewPadding),
                onPanEnd: (_) => _onDragEnd(size, media.viewPadding),
                onPanCancel: () => _onDragEnd(size, media.viewPadding),
                onTap: () {
                  _armIdleTimer();
                  unawaited(_openPaperSheet());
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: _dragging ? 1.035 : 1,
                  child: const _AssistiveTouchVisual(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistiveSite {
  const _AssistiveSite({
    required this.title,
    required this.url,
    this.assetPath,
    this.iconBase64,
    this.faviconUrl,
    this.isAiSearch = false,
  });

  final String title;
  final String url;
  final String? assetPath;
  final String? iconBase64;
  final String? faviconUrl;
  final bool isAiSearch;
}

class _AssistiveSitesPaperSheet extends StatefulWidget {
  const _AssistiveSitesPaperSheet({
    required this.onOpenAiSearch,
    required this.onOpenSite,
  });

  final VoidCallback onOpenAiSearch;
  final ValueChanged<_AssistiveSite> onOpenSite;

  @override
  State<_AssistiveSitesPaperSheet> createState() => _AssistiveSitesPaperSheetState();
}

class _AssistiveSitesPaperSheetState extends State<_AssistiveSitesPaperSheet> {
  static const int _sitesPerPage = 6;
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmFavicons());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _validWebUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;
    return uri.toString();
  }

  List<_AssistiveSite> _collectSites() {
    final result = <_AssistiveSite>[
      const _AssistiveSite(title: 'AI Search', url: '', isAiSearch: true),
    ];
    final seenHosts = <String>{};

    void add({
      required String title,
      required String url,
      String? assetPath,
      String? iconBase64,
      String? faviconUrl,
    }) {
      final validUrl = _validWebUrl(url);
      if (validUrl == null) return;
      final host = Uri.parse(validUrl).host.toLowerCase();
      if (!seenHosts.add(host)) return;
      final cleanTitle = title.trim().isEmpty ? host : title.trim();
      result.add(_AssistiveSite(
        title: cleanTitle,
        url: validUrl,
        assetPath: assetPath,
        iconBase64: iconBase64,
        faviconUrl: faviconUrl,
      ));
    }

    // Sites guardados pelo utilizador têm prioridade na lista.
    for (final site in customSitesController.sites) {
      add(
        title: site.name,
        url: site.url,
        assetPath: site.assetPath,
        iconBase64: site.iconBase64,
        faviconUrl: site.faviconUrl,
      );
    }

    // Favoritos e sites guardados pelo utilizador.
    for (final bookmark in bookmarksController.entries) {
      add(title: bookmark.title, url: bookmark.url);
    }

    // Separadores abertos, ordenados pelo último acesso.
    final openTabs = tabsController.tabs
        .where((tab) => !tab.isIncognito && tab.kind != TabKind.appScreen)
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    for (final tab in openTabs) {
      add(title: tab.title ?? '', url: tab.url);
    }

    // Histórico de sites recentes; jogos e URLs internas são excluídos.
    for (final entry in activityController.entries) {
      if (entry.kind != ActivityKind.site) continue;
      add(title: entry.title, url: entry.url);
      if (result.length >= 25) break;
    }
    return result;
  }

  void _warmFavicons() {
    for (final site in _collectSites().where((site) => !site.isAiSearch)) {
      unawaited(browserFaviconCache.fetchForUrl(site.url));
    }
  }

  Widget _circleButton({required IconData icon, required String label, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: enabled ? pillColor(context) : pillColor(context).withOpacity(.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AppMaterialIcon(
                icon,
                color: enabled ? mainText(context) : mutedText(context).withOpacity(.45),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _siteArtwork(_AssistiveSite site) {
    Widget fallback() => AppMaterialIcon(
          AppIcons.globe,
          color: mutedText(context),
          size: 27,
        );

    if (site.assetPath != null && site.assetPath!.isNotEmpty) {
      return Image.asset(
        site.assetPath!,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    String? encoded = site.iconBase64;
    if (encoded == null || encoded.isEmpty) encoded = browserFaviconCache.forUrl(site.url);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final bytes = base64Decode(encoded);
        return Image.memory(
          bytes,
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        // Um favicon inválido usa o globo neutro.
      }
    }

    if (site.faviconUrl != null && site.faviconUrl!.isNotEmpty) {
      return Image.network(
        site.faviconUrl!,
        width: 34,
        height: 34,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    return fallback();
  }

  Widget _buildSiteTile(_AssistiveSite site) {
    final isAi = site.isAiSearch;
    return Semantics(
      button: true,
      label: site.title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isAi ? widget.onOpenAiSearch : () => widget.onOpenSite(site),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: pillColor(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: lineColor(context).withOpacity(.55), width: .8),
                  ),
                  alignment: Alignment.center,
                  child: ClipOval(
                    child: isAi
                        ? Image.asset(
                            'assets/ai_search/ai.png',
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.sparkles, size: 28, color: accentColor(context)),
                          )
                        : _siteArtwork(site),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  site.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mainText(context), fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(List<_AssistiveSite> sites) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 105,
        crossAxisSpacing: 5,
        mainAxisSpacing: 1,
      ),
      itemCount: sites.length,
      itemBuilder: (context, index) => _buildSiteTile(sites[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * .48).clamp(300.0, 430.0).toDouble();
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        customSitesController,
        bookmarksController,
        tabsController,
        activityController,
        browserFaviconCache,
      ]),
      builder: (context, _) {
        final items = _collectSites();
        final pageCount = math.max(1, (items.length / _sitesPerPage).ceil()).toInt();
        final safePage = _pageIndex.clamp(0, pageCount - 1).toInt();
        if (safePage != _pageIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _pageIndex = safePage);
            if (_pageController.hasClients) _pageController.jumpToPage(safePage);
          });
        }

        return Material(
          color: popupSurfaceColor(context),
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: double.infinity,
            height: sheetHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 12, 17, 12),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: mutedText(context).withOpacity(.40),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appText('all_sites'),
                          style: TextStyle(color: mainText(context), fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${safePage + 1} / $pageCount',
                        style: TextStyle(color: mutedText(context), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pageCount,
                      onPageChanged: (value) => setState(() => _pageIndex = value),
                      itemBuilder: (context, page) {
                        final start = page * _sitesPerPage;
                        final end = math.min(start + _sitesPerPage, items.length).toInt();
                        return _buildPage(items.sublist(start, end));
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        icon: AppIcons.arrowLeft,
                        label: 'Previous sites',
                        onTap: safePage > 0
                            ? () => _pageController.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic)
                            : null,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(pageCount, (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == safePage ? 15 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: index == safePage ? accentColor(context) : mutedText(context).withOpacity(.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        )),
                      ),
                      _circleButton(
                        icon: AppIcons.arrowRight,
                        label: 'Next sites',
                        onTap: safePage < pageCount - 1
                            ? () => _pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
        child: SizedBox(
          width: 58,
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFF202A34))),
              _ring(.76, const Color(0xFF60676B)),
              _ring(.64, const Color(0xFF969B9F)),
              _ring(.46, Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(double fraction, Color color) => FractionallySizedBox(
        widthFactor: fraction,
        heightFactor: fraction,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      );
}
