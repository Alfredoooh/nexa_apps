import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../theme.dart';
import '../shell/browser_navigation.dart';
import '../shell/shell_tab_request.dart';
import '../widgets/search_engine_picker.dart';
import '../localization.dart';
import '../widgets/material_symbols.dart';
import '../widgets/search_engine_pngs.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.isIncognito = false});
  final bool isIncognito;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  List<String> _suggestions = <String>[];
  final Map<String, String?> _entityPhotoCache = <String, String?>{};
  final Map<String, Future<String?>> _entityPhotoRequests = <String, Future<String?>>{};
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onQueryChanged);
    aiSearchModeEnabled.addListener(_onAiModeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    aiSearchModeEnabled.removeListener(_onAiModeChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAiModeChanged() {
    _debounce?.cancel();
    _requestSequence++;
    if (!mounted) return;
    setState(() => _suggestions = <String>[]);
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (widget.isIncognito || aiSearchModeEnabled.value || query.isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = <String>[]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    if (aiSearchModeEnabled.value) return;
    final sequence = ++_requestSequence;
    try {
      final uri = Uri.https('suggestqueries.google.com', '/complete/search', <String, String>{
        'client': 'firefox',
        'q': query,
      });
      final response = await http.get(uri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 || !mounted || sequence != _requestSequence) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.length < 2 || decoded[1] is! List) return;
      final list = (decoded[1] as List)
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .take(8)
          .toList(growable: false);
      if (!mounted || sequence != _requestSequence) return;
      setState(() => _suggestions = list);
      _resolveSuggestionPhotos(list);
    } catch (_) {
      if (mounted && sequence == _requestSequence) setState(() => _suggestions = <String>[]);
    }
  }

  static const Map<String, String> _apiHeaders = <String, String>{
    'User-Agent': 'BrowseIt/1.0 (Android mobile browser; search suggestions)',
    'Accept': 'application/json',
  };

  bool _looksLikeUrl(String text) {
    final value = text.trim();
    if (value.contains(RegExp(r'\s'))) return false;
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    return uri != null && uri.host.contains('.') && !uri.host.startsWith('.');
  }

  String _normalizeUrl(String text) {
    final value = text.trim();
    return (value.startsWith('http://') || value.startsWith('https://')) ? value : 'https://$value';
  }

  void _fillText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _focusNode.requestFocus();
  }

  void _submitSearch(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    final isUrl = _looksLikeUrl(value);
    if (!widget.isIncognito && !isUrl) searchHistoryController.add(value);

    if (!isUrl && aiSearchModeEnabled.value) {
      final aiUrl = 'looply://ai-search?q=${Uri.encodeComponent(value)}';
      final tab = tabsController.createBrowserTab(
        aiUrl,
        title: 'AI Search',
        isIncognito: widget.isIncognito,
      );
      tabsController.activate(tab.id);
      Navigator.of(context).popUntil((route) => route.isFirst);
      ShellTabRequest.instance.requestBrowser(tab.id);
      return;
    }

    final url = isUrl ? _normalizeUrl(value) : activeSearchEngine.value.buildUrl(value);
    if (widget.isIncognito) {
      final tab = tabsController.createBrowserTab(url, title: value, isIncognito: true);
      tabsController.activate(tab.id);
      Navigator.of(context).popUntil((route) => route.isFirst);
      ShellTabRequest.instance.requestBrowser(tab.id);
      return;
    }
    unawaited(BrowserPreconnectHints.preconnect(url));
    openOrbitTab(context, url, title: value);
  }

  Future<void> _copyCurrentPage(BrowserTab tab) async {
    await Clipboard.setData(ClipboardData(text: tab.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appText('copied'))),
    );
  }

  void _editCurrentPage(BrowserTab tab) {
    _fillText(tab.url);
  }

  bool _isWebTab(BrowserTab? tab) {
    if (tab == null || tab.kind == TabKind.appScreen) return false;
    return tab.url.startsWith('https://') || tab.url.startsWith('http://');
  }

  Widget _currentPageCard(BrowserTab tab, Color text, Color muted) {
    final host = Uri.tryParse(tab.url)?.host.replaceFirst(RegExp(r'^www\.'), '') ?? tab.url;
    final title = (tab.title?.trim().isNotEmpty ?? false) ? tab.title!.trim() : host;
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      decoration: BoxDecoration(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppMaterialIcon(AppIcons.globe, color: muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 3),
            child: Text(
              tab.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: accentColor(context), fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _copyCurrentPage(tab),
                  icon: AppMaterialIcon(AppIcons.copy, size: 20, color: muted),
                  label: Text(
                    appText('copy_address'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _editCurrentPage(tab),
                  icon: AppMaterialIcon(AppIcons.pencilSimple, size: 20, color: muted),
                  label: Text(
                    appText('edit_link'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchEngineButton(Color muted) {
    return ValueListenableBuilder<bool>(
      valueListenable: aiSearchModeEnabled,
      builder: (context, aiEnabled, _) => IconButton(
        tooltip: appText('search_engine'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        onPressed: () => showSearchEnginePicker(context),
        icon: aiEnabled
            ? AppMaterialIcon(AppIcons.sparkles, size: 20, color: accentColor(context))
            : ValueListenableBuilder<SearchEngine>(
                valueListenable: activeSearchEngine,
                builder: (context, engine, _) {
                  final png = searchEnginePng(engine.name);
                  return png == null
                      ? const SizedBox(width: 20, height: 20)
                      : Image.memory(
                          png,
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                          cacheWidth: 80,
                          cacheHeight: 80,
                        );
                },
              ),
      ),
    );
  }

  // Só aceita a imagem se a entidade for "ser humano" (P31=Q5) e o label
  // devolvido pelo Wikidata corresponder exactamente ao texto da sugestão.
  void _resolveSuggestionPhotos(List<String> suggestions) {
    final candidates = suggestions.where((value) {
      final trimmed = value.trim();
      return !_looksLikeUrl(trimmed) && trimmed.length >= 3;
    }).take(6).toList(growable: false);
    for (final candidate in candidates) {
      if (_entityPhotoCache.containsKey(candidate) || _entityPhotoRequests.containsKey(candidate)) continue;
      final request = _lookupWikidataEntityPhoto(candidate);
      _entityPhotoRequests[candidate] = request;
      request.then((photoUrl) {
        _entityPhotoRequests.remove(candidate);
        _entityPhotoCache[candidate] = photoUrl;
        if (mounted && _suggestions.contains(candidate)) setState(() {});
      });
    }
  }

  static const Set<String> _humanInstanceIds = <String>{'Q5'};

  String _normalizeLabel(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  Future<String?> _lookupWikidataEntityPhoto(String name) async {
    try {
      final searchUri = Uri.https('www.wikidata.org', '/w/api.php', <String, String>{
        'action': 'wbsearchentities',
        'search': name,
        'language': 'pt',
        'uselang': 'pt',
        'format': 'json',
        'limit': '8',
      });
      final searchResponse = await http.get(searchUri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (searchResponse.statusCode != 200) return null;
      final searchJson = jsonDecode(utf8.decode(searchResponse.bodyBytes));
      final results = searchJson is Map ? searchJson['search'] : null;
      if (results is! List || results.isEmpty) return null;

      final normalizedQuery = _normalizeLabel(name);
      final exactMatches = results.whereType<Map>().where((item) {
        final label = item['label']?.toString();
        if (label != null && _normalizeLabel(label) == normalizedQuery) return true;
        final aliases = item['aliases'];
        if (aliases is List) {
          for (final alias in aliases) {
            if (_normalizeLabel(alias.toString()) == normalizedQuery) return true;
          }
        }
        return false;
      }).toList(growable: false);
      if (exactMatches.isEmpty) return null;

      final ids = exactMatches
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => RegExp(r'^Q\d+$').hasMatch(id))
          .take(5)
          .toList(growable: false);
      if (ids.isEmpty) return null;

      final entityUri = Uri.https('www.wikidata.org', '/w/api.php', <String, String>{
        'action': 'wbgetentities',
        'ids': ids.join('|'),
        'props': 'claims|labels',
        'format': 'json',
      });
      final entityResponse = await http.get(entityUri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (entityResponse.statusCode != 200) return null;
      final entityJson = jsonDecode(utf8.decode(entityResponse.bodyBytes));
      final entities = entityJson is Map ? entityJson['entities'] : null;
      if (entities is! Map) return null;

      String? imageTitle;
      for (final id in ids) {
        final entity = entities[id];
        if (entity is! Map) continue;
        final claims = entity['claims'];
        if (claims is! Map) continue;
        final instanceClaims = claims['P31'];
        final isHuman = instanceClaims is List && instanceClaims.any((claim) {
          final mainsnak = claim is Map ? claim['mainsnak'] : null;
          final data = mainsnak is Map ? mainsnak['datavalue'] : null;
          final value = data is Map ? data['value'] : null;
          final entityId = value is Map ? value['id']?.toString() : null;
          return entityId != null && _humanInstanceIds.contains(entityId);
        });
        if (!isHuman) continue;
        final imageClaims = claims['P18'];
        if (imageClaims is List && imageClaims.isNotEmpty) {
          final first = imageClaims.first;
          final mainsnak = first is Map ? first['mainsnak'] : null;
          final data = mainsnak is Map ? mainsnak['datavalue'] : null;
          final value = data is Map ? data['value'] : null;
          if (value is String && value.trim().isNotEmpty) {
            imageTitle = value;
            break;
          }
        }
      }
      if (imageTitle == null) return null;

      final commonsUri = Uri.https('commons.wikimedia.org', '/w/api.php', <String, String>{
        'action': 'query',
        'format': 'json',
        'prop': 'imageinfo',
        'iiprop': 'url',
        'iiurlwidth': '96',
        'titles': 'File:$imageTitle',
      });
      final imageResponse = await http.get(commonsUri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (imageResponse.statusCode != 200) return null;
      final imageJson = jsonDecode(utf8.decode(imageResponse.bodyBytes));
      final pages = ((imageJson is Map ? imageJson['query'] : null) as Map?)?['pages'];
      if (pages is! Map || pages.isEmpty) return null;
      final page = pages.values.first;
      if (page is! Map) return null;
      final imageInfo = page['imageinfo'];
      if (imageInfo is! List || imageInfo.isEmpty || imageInfo.first is! Map) return null;
      final firstInfo = imageInfo.first as Map;
      final thumb = firstInfo['thumburl']?.toString();
      final original = firstInfo['url']?.toString();
      return (thumb != null && thumb.startsWith('https://'))
          ? thumb
          : ((original != null && original.startsWith('https://')) ? original : null);
    } catch (_) {
      return null;
    }
  }

  Widget _suggestionLeading(String suggestion, Color muted) {
    if (_looksLikeUrl(suggestion)) {
      final uri = Uri.tryParse(_normalizeUrl(suggestion));
      if (uri != null && uri.host.isNotEmpty) {
        final favicon = 'https://www.google.com/s2/favicons?domain=${Uri.encodeComponent(uri.host)}&sz=64';
        return _FaviconIcon(url: favicon, fallback: AppIcons.globe, muted: muted);
      }
    }
    return AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 20);
  }

  Widget? _suggestionTrailingPhoto(String suggestion) {
    final photo = _entityPhotoCache[suggestion];
    if (photo == null) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        photo,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        cacheWidth: 120,
        cacheHeight: 120,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _clearButton(Color muted) {
    return GestureDetector(
      onTap: () {
        _controller.clear();
        _focusNode.requestFocus();
      },
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: muted.withOpacity(.35),
        ),
        child: AppMaterialIcon(AppIcons.x, size: 20, color: Theme.of(context).scaffoldBackgroundColor),
      ),
    );
  }

  Widget _recentSearches(List<String> queries, Color text, Color muted) {
    if (queries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
          child: Text(
            appText('recent_searches'),
            style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        M3ESegmentedColumn(
          color: settingsCardColor(context),
          outerRadius: 20,
          innerRadius: 16,
          gap: 4,
          padding: EdgeInsets.zero,
          onTap: (index) => _submitSearch(queries[index]),
          children: [
            for (final query in queries)
              M3EListItem(
                leading: AppMaterialIcon(AppIcons.clockCounterClockwise, color: muted, size: 20),
                headline: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14)),
                trailing: IconButton(
                  tooltip: appText('fill_search'),
                  icon: AppMaterialIcon(AppIcons.arrowUpLeft, color: muted, size: 20),
                  onPressed: () => _fillText(query),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _suggestionList(Color text, Color muted) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return M3ESegmentedColumn(
      color: settingsCardColor(context),
      outerRadius: 20,
      innerRadius: 16,
      gap: 4,
      padding: EdgeInsets.zero,
      onTap: (index) => _submitSearch(_suggestions[index]),
      children: [
        for (final suggestion in _suggestions)
          M3EListItem(
            leading: _suggestionLeading(suggestion, muted),
            headline: Text(suggestion, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14)),
            trailing: _suggestionTrailingPhoto(suggestion) ?? IconButton(
              tooltip: appText('fill_search'),
              icon: AppMaterialIcon(AppIcons.arrowUpLeft, color: muted, size: 20),
              onPressed: () => _fillText(suggestion),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: pillColor(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 2),
                        _searchEngineButton(muted),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.search,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(color: text, fontSize: 15),
                            cursorColor: accentColor(context),
                            onSubmitted: _submitSearch,
                            decoration: InputDecoration(
                              hintText: appText('search_hint'),
                              hintStyle: TextStyle(color: muted, fontSize: 14),
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        if (_controller.text.isNotEmpty) _clearButton(muted),
                        const SizedBox(width: 5),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([tabsController, searchHistoryController]),
                    builder: (context, _) {
                      final activeTab = tabsController.activeTab;
                      final showPageCard = _isWebTab(activeTab);
                      final isEmpty = _controller.text.trim().isEmpty;
                      final queries = widget.isIncognito ? const <String>[] : searchHistoryController.queries;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          if (showPageCard) _currentPageCard(activeTab!, text, muted),
                          if (isEmpty) _recentSearches(queries, text, muted),
                          if (!isEmpty && aiSearchModeEnabled.value)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: settingsCardColor(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  AppMaterialIcon(AppIcons.sparkles, color: accentColor(context), size: 21),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'A pesquisa será aberta na tela AI Search.',
                                      style: TextStyle(color: muted, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isEmpty && !aiSearchModeEnabled.value) _suggestionList(text, muted),
                        ],
                      );
                    },
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

class _FaviconIcon extends StatelessWidget {
  const _FaviconIcon({required this.url, required this.fallback, required this.muted});
  final String url;
  final IconData fallback;
  final Color muted;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => AppMaterialIcon(fallback, color: muted, size: 18),
        ),
      );
}
