// ══════════════════════════════════════════════════════════════
// FILE: lib/main.dart
// ══════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/colors.dart';
import 'widgets/widgets.dart';
import 'core/navigation/app_page_route.dart';
import 'screens/drawer/drawer_menu.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/auth_service.dart';
import 'screens/auth/authscreens.dart';
import 'screens/library/library_screen.dart';
import 'screens/apps/app_types.dart';
import 'screens/apps/registry/app_registry.dart';
import 'screens/apps/docs/docs_screen.dart';
import 'screens/apps/sheets/sheets_app.dart';
import 'screens/apps/slides/slides_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await appTheme.load();
  await appPreferences.load();

  SystemChrome.setSystemUIOverlayStyle(
    AppColorScheme(appTheme.isDark, appTheme.primaryPairIndex).statusBarStyle,
  );

  try {
    await AppRegistry.loadManifests();
  } catch (e) {
    debugPrint('Erro ao carregar manifests: $e');
  }

  runApp(const CraftLabApp());
}

class CraftLabApp extends StatefulWidget {
  const CraftLabApp({super.key});

  @override
  State<CraftLabApp> createState() => _CraftLabAppState();
}

class _CraftLabAppState extends State<CraftLabApp> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(_syncSystemUi);
    appPreferences.addListener(_onPrefsChanged);
    _syncSystemUi();
  }

  @override
  void dispose() {
    appTheme.removeListener(_syncSystemUi);
    appPreferences.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  void _syncSystemUi() {
    final s = AppColorScheme(appTheme.isDark, appTheme.primaryPairIndex);
    SystemChrome.setSystemUIOverlayStyle(s.statusBarStyle);
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme(
      child: Builder(builder: (ctx) {
        final s = AppTheme.of(ctx);
        _syncSystemUi();

        return MaterialApp(
          title: 'CraftLab',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          theme: buildBrowseItTheme(AppColorScheme(false, appTheme.primaryPairIndex)),
          darkTheme: buildBrowseItTheme(AppColorScheme(true, appTheme.primaryPairIndex)),
          themeMode: s.isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(appPreferences.textScaleFactor),
            ),
            child: ColoredBox(color: s.sheetBackdrop, child: child!),
          ),
          home: const AuthGate(),
        );
      }),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with ThemeReactive<RootShell>, SingleTickerProviderStateMixin {
  late final AnimationController _drawerCtrl = AnimationController(
    vsync: this,
    duration: _drawerAnim,
    value: 0.0,
  );

  bool get _drawerOpen => _drawerCtrl.value > 0.5;

  bool _hasMessages = false;

  final GlobalKey<AiTabState> _aiTabKey = GlobalKey<AiTabState>();

  void _openDrawer() {
    FocusScope.of(context).unfocus();
    _drawerCtrl.animateTo(1.0, curve: _drawerCurve);
  }

  Future<void> _closeDrawer() =>
      _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);

  void _toggleDrawer() => _drawerOpen ? _closeDrawer() : _openDrawer();

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context)
        .push(AppPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openLibrary() {
    _closeDrawer();
    Navigator.of(context)
        .push(AppPageRoute(builder: (_) => const LibraryScreen()));
  }

  void _onMessageSent() {
    if (!_hasMessages) setState(() => _hasMessages = true);
  }

  ConversationAction? _pendingConversationAction;
  int _aiTabInstance = 0;
  String? _pendingConversationLoad;

  void _onConversationAction(ConversationAction action) {
    setState(() {
      _pendingConversationAction = action;
      if (action == ConversationAction.newChat || action == ConversationAction.incognito) {
        _hasMessages = action == ConversationAction.newChat ? false : _hasMessages;
      }
    });
  }

  void _onOpenConversation(String id) {
    setState(() {
      _pendingConversationLoad = id;
      _hasMessages = true;
    });
  }

  void _onConversationLoadConsumed() {
    setState(() => _pendingConversationLoad = null);
  }

  void _onCanvasCreated(LocalCanvasItem item) {
    editTabController.requestLoadLocal(item);
  }

  Widget _buildTab() {
    return AiTabHost(
      key: ValueKey('ai_$_aiTabInstance'),
      aiTabKey: _aiTabKey,
      onFirstMessage: _onMessageSent,
      externalAction: _pendingConversationAction,
      onExternalActionConsumed: () => setState(() => _pendingConversationAction = null),
      initialConversationId: _pendingConversationLoad,
      onConversationLoadConsumed: _onConversationLoadConsumed,
      onHasMessagesChanged: (v) => setState(() => _hasMessages = v),
      onCanvasCreated: _onCanvasCreated,
    );
  }

  static const Duration _drawerAnim = Duration(milliseconds: 320);
  static const Curve _drawerCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final _screenWidth = MediaQuery.of(context).size.width;
    final _drawerWidth = _screenWidth;

    final bodyContent = Stack(children: [
      Positioned.fill(
        top: 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(key: const ValueKey('ai'), child: _buildTab()),
        ),
      ),
      Positioned(
        top: 0, left: 0, right: 0,
        child: AnimatedBuilder(
          animation: _AiTabHeaderRefresh.of(context),
          builder: (_, __) {
            final st = _aiTabKey.currentState;
            return _AppHeader(
              s: s,
              title: '',
              onMenu: _toggleDrawer,
              transparent: true,
              headerBackground: s.pageBackground,
              trailing: AiConversationMenuButton(
                s: s,
                hasMessages: _hasMessages,
                isIncognito: _aiTabKey.currentState?.isIncognito ?? false,
                onSelect: _onConversationAction,
              ),
            );
          },
        ),
      ),
    ]);

    return RootShellNavigation(
      switchToEditTab: (type) {
        final screen = switch (type) {
          EditorType.docs   => DocsScreen(),
          EditorType.sheets => SheetsScreen(),
          EditorType.slides => SlidesScreen(),
        };
        Navigator.of(context).push(AppPageRoute(builder: (_) => screen));
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_drawerOpen) {
            _closeDrawer();
          } else {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: s.surface,
          body: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onHorizontalDragStart: (_) {
                  _drawerCtrl.stop();
                },
                onHorizontalDragUpdate: (d) {
                  final delta = d.delta.dx / _drawerWidth;
                  _drawerCtrl.value = (_drawerCtrl.value + delta).clamp(0.0, 1.0);
                },
                onHorizontalDragEnd: (d) {
                  final velocity = d.velocity.pixelsPerSecond.dx;
                  if (velocity.abs() > 300) {
                    if (velocity > 0) {
                      _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                    } else {
                      _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                    }
                  } else if (_drawerCtrl.value > 0.5) {
                    _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                  } else {
                    _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                  }
                },
                child: AnimatedBuilder(
                  animation: _drawerCtrl,
                  builder: (_, child) {
                    final t = _drawerCtrl.value;
                    return Transform.translate(
                      offset: Offset(_drawerWidth * 0.25 * t, 0),
                      child: child,
                    );
                  },
                  child: bodyContent,
                ),
              ),

              AnimatedBuilder(
                animation: _drawerCtrl,
                builder: (_, __) {
                  final t = _drawerCtrl.value;
                  return Positioned.fill(
                    child: IgnorePointer(
                      ignoring: t < 0.01,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeDrawer,
                        onHorizontalDragStart: (_) {
                          _drawerCtrl.stop();
                        },
                        onHorizontalDragUpdate: (d) {
                          final delta = d.delta.dx / _drawerWidth;
                          _drawerCtrl.value = (_drawerCtrl.value + delta).clamp(0.0, 1.0);
                        },
                        onHorizontalDragEnd: (d) {
                          final velocity = d.velocity.pixelsPerSecond.dx;
                          if (velocity.abs() > 300) {
                            if (velocity > 0) {
                              _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                            } else {
                              _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                            }
                          } else if (_drawerCtrl.value > 0.5) {
                            _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                          } else {
                            _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                          }
                        },
                        child: Container(
                          color: Colors.black.withOpacity(0.3 * t),
                        ),
                      ),
                    ),
                  );
                },
              ),

              Positioned(
                top: 0, bottom: 0, left: 0,
                width: _drawerWidth,
                child: AnimatedBuilder(
                  animation: _drawerCtrl,
                  builder: (_, child) {
                    final t = _drawerCtrl.value;
                    return Transform.translate(
                      offset: Offset(-_drawerWidth * (1.0 - t), 0),
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      final delta = d.delta.dx / _drawerWidth;
                      _drawerCtrl.value = (_drawerCtrl.value + delta).clamp(0.0, 1.0);
                    },
                    onHorizontalDragEnd: (d) {
                      final velocity = d.velocity.pixelsPerSecond.dx;
                      if (velocity.abs() > 300) {
                        if (velocity > 0) {
                          _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                        } else {
                          _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                        }
                      } else if (_drawerCtrl.value > 0.5) {
                        _drawerCtrl.animateTo(1.0, curve: _drawerCurve, duration: _drawerAnim);
                      } else {
                        _drawerCtrl.animateTo(0.0, curve: _drawerCurve, duration: _drawerAnim);
                      }
                    },
                    child: Material(
                      color: s.surface,
                      child: AnimatedBuilder(
                        animation: _AiTabHeaderRefresh.of(context),
                        builder: (_, __) => AppDrawer(
                          s: s,
                          onCloseAnimated: _closeDrawer,
                          onSettings: _openSettings,
                          onOpenConversation: _onOpenConversation,
                          onNewChat: () =>
                              _onConversationAction(ConversationAction.newChat),
                          activeConversationId: _aiTabKey.currentState?.conversationId,
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
    );
  }
}

class _LibraryButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _LibraryButton({required this.s, required this.onTap});
  @override
  State<_LibraryButton> createState() => _LibraryButtonState();
}

class _LibraryButtonState extends State<_LibraryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: widget.s.cardShadow,
        ),
        child: AppIcon('library', size: 18, color: widget.s.onSurface),
      ),
    );
  }
}

class _AiTabHeaderRefresh extends ChangeNotifier {
  static final _AiTabHeaderRefresh _instance = _AiTabHeaderRefresh._();
  _AiTabHeaderRefresh._();
  static _AiTabHeaderRefresh of(BuildContext context) => _instance;
  void ping() => notifyListeners();
}

class AiTabHost extends StatefulWidget {
  final GlobalKey<AiTabState> aiTabKey;
  final VoidCallback onFirstMessage;
  final ConversationAction? externalAction;
  final VoidCallback onExternalActionConsumed;
  final String? initialConversationId;
  final VoidCallback? onConversationLoadConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  final ValueChanged<LocalCanvasItem>? onCanvasCreated;
  const AiTabHost({
    super.key,
    required this.aiTabKey,
    required this.onFirstMessage,
    required this.externalAction,
    required this.onExternalActionConsumed,
    this.initialConversationId,
    this.onConversationLoadConsumed,
    this.onHasMessagesChanged,
    this.onCanvasCreated,
  });
  @override State<AiTabHost> createState() => _AiTabHostState();
}

class _AiTabHostState extends State<AiTabHost> {
  @override
  void didUpdateWidget(covariant AiTabHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialConversationId != null &&
        widget.initialConversationId != oldWidget.initialConversationId) {
      widget.onConversationLoadConsumed?.call();
    }
  }

  void _goToEditTab(EditorType type) {
    RootShellNavigation.of(context)?.switchToEditTab(type);
  }

  @override
  Widget build(BuildContext context) {
    return AiTabHostNavigation(
      goToEditTab: _goToEditTab,
      child: AiTab(
        key: widget.aiTabKey,
        onFirstMessage: widget.onFirstMessage,
        externalAction: widget.externalAction,
        onExternalActionConsumed: widget.onExternalActionConsumed,
        initialConversationId: widget.initialConversationId,
        onHasMessagesChanged: widget.onHasMessagesChanged,
        onHeaderStateChanged: () => _AiTabHeaderRefresh.of(context).ping(),
        onCanvasCreated: widget.onCanvasCreated,
      ),
    );
  }
}

class RootShellNavigation extends InheritedWidget {
  final ValueChanged<EditorType> switchToEditTab;
  const RootShellNavigation({
    super.key,
    required this.switchToEditTab,
    required super.child,
  });

  static RootShellNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootShellNavigation>();

  @override
  bool updateShouldNotify(RootShellNavigation oldWidget) => true;
}

class _AppHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onMenu;
  final Widget? trailing;
  final Widget? leadingExtra;
  final bool transparent;
  final Color headerBackground;

  const _AppHeader({
    required this.s,
    required this.title,
    required this.onMenu,
    required this.headerBackground,
    this.trailing,
    this.leadingExtra,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 10, left: 16, right: 16,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onMenu,
          child: Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.cardBackground,
              shape: BoxShape.circle,
              boxShadow: s.cardShadow,
            ),
            child: AppIcon('menu', color: s.onSurface, size: 20),
          ),
        ),
        if (leadingExtra != null) ...[
          const SizedBox(width: 8),
          leadingExtra!,
        ],
        const SizedBox(width: 8),
        if (title.isNotEmpty)
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: s.onSurface,
            ),
          ),
        const Spacer(),
        if (trailing != null)
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.cardBackground,
              shape: BoxShape.circle,
              boxShadow: s.cardShadow,
            ),
            child: trailing,
          ),
      ]),
    );

    return Container(color: headerBackground, child: content);
  }
}