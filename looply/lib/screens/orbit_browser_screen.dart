import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect, Offset;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../browser_library.dart';
import '../localization.dart';
import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../shell/fade_page_route.dart';
import 'bookmarks_screen.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

const MethodChannel _nativeBrowserChannel = MethodChannel('looply/native_ui');

class OrbitBrowserScreen extends StatefulWidget {
  const OrbitBrowserScreen({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.isActive,
    required this.viewportKey,
    this.firstLoadCompleter,
    this.browserReadyCompleter,
    this.isIncognito = false,
    this.previewOnly = false,
    this.skipNativeEnterAnimation = false,
  });

  final String tabId;
  final String initialUrl;
  final bool isActive;
  final GlobalKey viewportKey;
  final Completer<void>? firstLoadCompleter;
  final Completer<void>? browserReadyCompleter;
  final bool isIncognito;
  final bool previewOnly;
  final bool skipNativeEnterAnimation;

  @override
  State<OrbitBrowserScreen> createState() => _OrbitBrowserScreenState();
}

class _OrbitBrowserScreenState extends State<OrbitBrowserScreen> {
  bool _opening = false;
  bool _disposed = false;
  String _lastUrl = '';

  @override
  void initState() {
    super.initState();

    _complete(widget.browserReadyCompleter);

    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openNativeBrowser());
      });
    }
  }

  @override
  void didUpdateWidget(covariant OrbitBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openNativeBrowser());
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _complete(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Rect? _nativeBrowserSourceRect() {
    try {
      final overlay = Overlay.of(context, rootOverlay: true);
      final overlayBox = overlay.context.findRenderObject() as RenderBox?;
      final viewportBox = widget.viewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (overlayBox == null || viewportBox == null || !viewportBox.attached) {
        return null;
      }
      final topLeft = viewportBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      return topLeft & viewportBox.size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNativeBrowser() async {
    if (_opening || _disposed || !mounted) return;

    _opening = true;

    final currentTab =
        widget.previewOnly ? null : tabsController.getTab(widget.tabId);

    final startUrl = (currentTab?.url ?? widget.initialUrl).trim();

    var safeStartUrl =
        startUrl.isEmpty ? 'https://www.google.com' : startUrl;

    // A antiga página interna de pesquisa IA não fazia parte
    // do motor Kotlin. Mantém-se a pesquisa através do Google.
    if (safeStartUrl.startsWith('looply://ai-search')) {
      final query =
          Uri.tryParse(safeStartUrl)?.queryParameters['q'] ?? '';

      safeStartUrl =
          'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';

      if (!widget.previewOnly) {
        tabsController.updateTab(widget.tabId, url: safeStartUrl);
      }
    }

    _lastUrl = safeStartUrl;

    try {
      final result =
          await _nativeBrowserChannel.invokeMapMethod<String, dynamic>(
        'openNativeBrowser',
        <String, Object?>{
          'url': safeStartUrl,
          'tabId': widget.tabId,
          'isIncognito': widget.isIncognito,
          'tabCount': tabsController.count,
          'previewOnly': widget.previewOnly,
          'skipNativeEnterAnimation': widget.skipNativeEnterAnimation,
          'menuLabels': <String, String>{
            'bookmark': appText('add_bookmark'),
            'bookmarks': appText('bookmarks'),
            'history': appText('history'),
            'downloads': appText('downloads'),
            'reload': appText('reload_page'),
            'find': appText('search_in_page'),
            'desktop': appText('desktop_site'),
            'desktopOff': appText('desktop_site_off'),
            'translate': appText('translate'),
            'fontSize': appText('font_size'),
            'pageZoom': appText('page_zoom'),
            'print': appText('print_page'),
            'copy': appText('copy_address'),
            'share': appText('share_page'),
            'siteInfo': appText('site_info'),
            'settings': appText('settings'),
            'home': appText('home'),
            'back': appText('go_back'),
            'forward': appText('go_forward'),
            'newTab': appText('new_tab'),
            'tabs': appText('tabs'),
            'options': appText('more_options'),
            'downloadReceived': appText('download_received'),
            'close': appText('close'),
            'closeSearch': appText('close_search'),
            'searchHint': appText('search_hint'),
            'validAddress': appText('valid_http_url'),
            'loadingError': appText('loading_error'),
            'copied': appText('copied'),
            'downloadImage': appText('download_image'),
            'newTabLabel': appText('new_tab'),
            'downloadFailed': appText('download_failed'),
            'remove': appText('remove'),
            'cancel': appText('cancel'),
            'targetLanguage': appLanguageController.value.code,
          },
        },
      );

      if (!mounted || _disposed) return;

      _complete(widget.firstLoadCompleter);

      if (widget.previewOnly) {
        Navigator.of(context).maybePop();
        return;
      }

      final data = result ?? const <String, dynamic>{};

      final url = (data['url'] as String?)?.trim();
      final title = (data['title'] as String?)?.trim();

      final thumbnailValue = data['thumbnail'];
      final transitionScreenshotValue = data['transitionScreenshot'];

      final Uint8List? thumbnail = thumbnailValue is Uint8List
          ? thumbnailValue
          : thumbnailValue is List<int>
              ? Uint8List.fromList(thumbnailValue)
              : null;
      final Uint8List? transitionScreenshot = transitionScreenshotValue is Uint8List
          ? transitionScreenshotValue
          : transitionScreenshotValue is List<int>
              ? Uint8List.fromList(transitionScreenshotValue)
              : null;

      final currentUrl =
          (url?.isNotEmpty == true) ? url! : _lastUrl;

      final currentTitle =
          (title?.isNotEmpty == true) ? title! : currentUrl;

      tabsController.updateTab(
        widget.tabId,
        url: currentUrl,
        title: currentTitle,
        thumbnail: widget.isIncognito ? null : thumbnail,
      );

      if (!widget.isIncognito &&
          currentUrl.startsWith(RegExp(r'https?://'))) {
        activityController.log(
          ActivityKind.site,
          currentTitle,
          currentUrl,
        );

        unawaited(browserFaviconCache.fetchForUrl(currentUrl));
        unawaited(AdBlockStats.instance.restore());
      }

      final action = (data['action'] as String?) ?? 'home';

      switch (action) {
        case 'tabs':
          ShellTabRequest.instance.requestCloseBrowser(
            tabId: widget.tabId,
            screenshot: transitionScreenshot ?? thumbnail,
            sourceRect: _nativeBrowserSourceRect(),
          );
          return;

        case 'newTab':
          final newUrl = (data['newUrl'] as String?)?.trim();

          final nextTab = tabsController.createBrowserTab(
            newUrl?.isNotEmpty == true
                ? newUrl!
                : 'https://www.google.com',
            isIncognito: widget.isIncognito,
          );

          tabsController.activate(nextTab.id);
          ShellTabRequest.instance.requestBrowser(nextTab.id);
          return;

        case 'bookmark':
          if (!widget.isIncognito) {
            bookmarksController.add(currentTitle, currentUrl);
          }

          await _reopen();
          return;

        case 'bookmarkUrl':
          if (!widget.isIncognito) {
            final link = (data['newUrl'] as String?)?.trim();

            if (link != null && link.isNotEmpty) {
              bookmarksController.add(link, link);
            }
          }

          await _reopen();
          return;

        case 'history':
          await _pushFlutterPage(const HistoryScreen());
          return;

        case 'downloads':
          await _pushFlutterPage(const DownloadsScreen());
          return;

        case 'bookmarks':
          await _pushFlutterPage(const BookmarksScreen());
          return;

        case 'settings':
          await _pushFlutterPage(const SettingsScreen());
          return;

        case 'search':
          await _pushFlutterPage(
            SearchScreen(isIncognito: widget.isIncognito),
          );
          return;

        case 'previewClosed':
          Navigator.of(context).maybePop();
          return;

        case 'home':
        default:
          ShellTabRequest.instance.request(0);
          return;
      }
    } on MissingPluginException {
      _complete(widget.firstLoadCompleter);

      if (!mounted || widget.previewOnly) return;

      _showUnavailable(
        'O browser Kotlin não está incluído nesta versão Android.',
      );

      ShellTabRequest.instance.request(0);
    } on PlatformException catch (error) {
      _complete(widget.firstLoadCompleter);

      if (!mounted || widget.previewOnly) return;

      _showUnavailable(
        error.message ?? 'Não foi possível abrir o browser nativo.',
      );

      ShellTabRequest.instance.request(0);
    } catch (error) {
      _complete(widget.firstLoadCompleter);

      if (!mounted || widget.previewOnly) return;

      _showUnavailable('Falha ao abrir o browser nativo: $error');

      ShellTabRequest.instance.request(0);
    } finally {
      _opening = false;
    }
  }

  Future<void> _pushFlutterPage(Widget page) async {
    if (!mounted) return;

    final routeTabId = widget.tabId;
    final route = page is SearchScreen
        ? FadePageRoute<void>(builder: (_) => page)
        : MaterialPageRoute<void>(builder: (_) => page);
    await Navigator.of(context).push<void>(route);

    // A SearchScreen pode ter ativado outra aba. Não reabra a antiga por cima
    // dela: isso provocava um segundo carregamento após escolher um resultado.
    if (mounted &&
        widget.isActive &&
        tabsController.activeTabId == routeTabId &&
        tabsController.getTab(routeTabId) != null) {
      await _reopen();
    }
  }

  Future<void> _reopen() async {
    _opening = false;

    if (!mounted || _disposed) return;

    await Future<void>.delayed(
      const Duration(milliseconds: 120),
    );

    if (mounted) {
      await _openNativeBrowser();
    }
  }

  void _showUnavailable(String message) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark ||
            widget.isIncognito;

    return ColoredBox(
      color: isDark
          ? const Color(0xFF191A1C)
          : Colors.white,
      child: const SizedBox.expand(),
    );
  }
}
