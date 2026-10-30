import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'models.dart';
import 'screens/activity_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/games_screen.dart';
import 'screens/home_screen.dart';
import 'session_store.dart';
import 'shell/shell_tab_request.dart';
import 'shell/tabs_grid_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const LooplyApp());
}

class LooplyApp extends StatelessWidget {
  const LooplyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => MaterialApp(
        title: 'Looply',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        themeAnimationDuration: Duration.zero,
        theme: buildLooplyTheme(Brightness.light),
        darkTheme: buildLooplyTheme(Brightness.dark),
        home: const LooplyShell(),
      ),
    );
  }
}

class LooplyShell extends StatefulWidget {
  const LooplyShell({super.key});

  @override
  State<LooplyShell> createState() => _LooplyShellState();
}

class _LooplyShellState extends State<LooplyShell> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _tabsGridMounted = false;
  final List<String> _screenKeys = const ['home_screen', 'games_screen', 'activity_screen'];
  final List<String> _screenLabels = const ['Início', 'Jogos', 'Atividade'];
  final List<IconData> _screenIcons = const [Symbols.home_rounded, Symbols.sports_esports_rounded, Symbols.history_rounded];
  late final AnimationController _gridController;
  late final CurvedAnimation _gridFade;
  String? _preferredReturnTabId;
  bool _restoreChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tabsController.addListener(_onTabsChanged);
    ShellTabRequest.instance.addListener(_handleShellTabRequest);
    _gridController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _gridFade = CurvedAnimation(parent: _gridController, curve: Curves.easeInOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRestoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabsController.removeListener(_onTabsChanged);
    ShellTabRequest.instance.removeListener(_handleShellTabRequest);
    _gridFade.dispose();
    _gridController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(SessionStore.instance.markBackgrounded());
    }
  }

  Future<void> _maybeRestoreSession() async {
    if (_restoreChecked || !mounted) return;
    _restoreChecked = true;
    final restored = await SessionStore.instance.getRestorablePage();
    if (restored == null || !mounted) return;

    final tab = tabsController.createBrowserTab(restored.url);
    tabsController.activate(tab.id);
    Navigator.of(context).push(openBrowserRoute(tabId: tab.id, initialUrl: restored.url));
  }

  void _onTabsChanged() {
    if (mounted) setState(() {});
  }

  void _handleShellTabRequest() {
    if (!mounted) return;
    final request = ShellTabRequest.instance;
    if (request.tabsRequested) {
      request.tabsRequested = false;
      request.requestedIndex = null;
      _preferredReturnTabId = tabsController.activeTabId;
      Navigator.of(context).popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTabsGrid();
      });
      return;
    }

    final requested = request.requestedIndex;
    request.requestedIndex = null;
    if (requested == null) return;
    setState(() => _selectedTab = requested.clamp(0, 2).toInt());
  }

  Future<void> _openTabsGrid() async {
    if (_tabsGridMounted) return;

    _preferredReturnTabId = tabsController.activeTabId;
    tabsController.upsertAppScreenTab(
      _screenKeys[_selectedTab],
      _screenLabels[_selectedTab],
      _screenIcons[_selectedTab],
      null,
    );
    setState(() => _tabsGridMounted = true);
    await _gridController.forward(from: 0);
  }

  Future<void> _closeTabsGrid({BrowserTab? openTab}) async {
    if (!_tabsGridMounted) return;

    final preferredReturnTab = tabsController.getTab(_preferredReturnTabId ?? '');
    final targetTab = openTab ?? preferredReturnTab ?? tabsController.getAppScreen(_screenKeys[_selectedTab]);
    _preferredReturnTabId = null;

    if (targetTab != null && targetTab.kind == TabKind.browser) {
      tabsController.activate(targetTab.id);
      setState(() => _tabsGridMounted = false);
      _gridController.value = 0;
      Navigator.of(context).push(_instantBrowserRoute(targetTab));
      return;
    }

    if (targetTab != null && targetTab.kind == TabKind.appScreen) {
      final index = _screenKeys.indexOf(targetTab.url);
      if (index >= 0) _selectedTab = index;
    }

    await _gridController.reverse();
    if (mounted) setState(() => _tabsGridMounted = false);
  }

  PageRoute<void> _instantBrowserRoute(BrowserTab tab) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => BrowserScreen(
        tabId: tab.id,
        initialUrl: tab.url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? looplyBgDark : looplyBgLight;
    final text = mainText(context);
    final pages = const <Widget>[HomeScreen(), GamesScreen(), ActivityScreen()];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _gridController,
              builder: (context, child) {
                final progress = Curves.easeInOutCubic.transform(_gridController.value);
                return Transform.scale(
                  scale: 1 - (0.055 * progress),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26 * progress),
                    child: child,
                  ),
                );
              },
              child: IgnorePointer(
                ignoring: _tabsGridMounted,
                child: SafeArea(
                  bottom: false,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    reverseDuration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final scale = Tween<double>(begin: 0.985, end: 1).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: scale, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedTab),
                      child: pages[_selectedTab],
                    ),
                  ),
                ),
              ),
            ),
            if (_tabsGridMounted)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _gridController,
                  builder: (context, child) => IgnorePointer(
                    ignoring: _gridController.value < 0.96,
                    child: FadeTransition(opacity: _gridFade, child: child),
                  ),
                  child: PopScope<void>(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, result) {
                      if (!didPop) _closeTabsGrid();
                    },
                    child: TabsGridScreen(
                      onSelectTab: (tab) => _closeTabsGrid(openTab: tab),
                      onClose: () => _closeTabsGrid(),
                      onNewTab: () {
                        final tab = tabsController.createBrowserTab('https://www.google.com');
                        _closeTabsGrid(openTab: tab);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Offstage(
          offstage: _tabsGridMounted,
          child: NavigationBar(
            selectedIndex: _selectedTab < 2 ? _selectedTab : _selectedTab + 1,
            onDestinationSelected: (index) {
              if (index == 2) {
                _openTabsGrid();
                return;
              }
              setState(() => _selectedTab = index < 2 ? index : index - 1);
            },
            destinations: [
              const NavigationDestination(icon: Icon(Symbols.home_rounded), selectedIcon: Icon(Symbols.home_rounded, fill: 1), label: 'Início'),
              const NavigationDestination(icon: Icon(Symbols.sports_esports_rounded), selectedIcon: Icon(Symbols.sports_esports_rounded, fill: 1), label: 'Jogos'),
              NavigationDestination(icon: _TabsCountIcon(count: tabsController.count, color: text), selectedIcon: _TabsCountIcon(count: tabsController.count, color: text), label: 'Abas'),
              const NavigationDestination(icon: Icon(Symbols.history_rounded), selectedIcon: Icon(Symbols.history_rounded, fill: 1), label: 'Atividade'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabsCountIcon extends StatelessWidget {
  const _TabsCountIcon({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 23,
        height: 23,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(.85), width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, height: 1)),
      );
}
