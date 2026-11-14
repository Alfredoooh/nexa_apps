import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import '../theme.dart';
import '../shell/browser_navigation.dart';
import '../shell/shell_tab_request.dart';
import '../widgets/search_engine_picker.dart';
import '../localization.dart';
import '../widgets/material_symbols.dart';

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
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onQueryChanged);
    _focusNode.addListener(_onFocusChanged);
    aiSearchModeEnabled.addListener(_onAiModeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _focusNode.removeListener(_onFocusChanged);
    aiSearchModeEnabled.removeListener(_onAiModeChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
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

  void _fillSuggestion(String suggestion) {
    _controller.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
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
      final tab = tabsController.createBrowserTab(aiUrl, isIncognito: widget.isIncognito);
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

  void _showSearchHistory() {
    if (widget.isIncognito) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      useSafeArea: true,
      builder: (sheetContext) => Material(
        color: panelColor(sheetContext),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: searchHistoryController,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 32, height: 4, decoration: BoxDecoration(color: mutedText(context).withOpacity(.45), borderRadius: BorderRadius.circular(99))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Align(alignment: Alignment.centerLeft, child: Text(appText('recent_searches'), style: TextStyle(color: mainText(context), fontSize: 17, fontWeight: FontWeight.w800))),
                ),
                if (searchHistoryController.queries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Text(appText('no_saved_searches'), style: TextStyle(color: mutedText(context))),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .55),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchHistoryController.queries.length,
                      itemBuilder: (context, index) {
                        final query = searchHistoryController.queries[index];
                        return ListTile(
                          leading: AppMaterialIcon(AppIcons.clockCounterClockwise, color: mutedText(context)),
                          title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainText(context))),
                          trailing: AppMaterialIcon(AppIcons.arrowUpLeft, size: 18, color: mutedText(context)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _submitSearch(query);
                          },
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

  // Só aceita a imagem se a entidade for "ser humano" (P31=Q5) E o label
  // devolvido pelo Wikidata for IGUAL (normalizado) ao texto da sugestão.
  // Sem correspondência exata + humano confirmado, não mostra imagem.
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

  String _normalizeLabel(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').replaceAll(RegExp(r'\s+'), ' ');

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
      final results = (searchJson is Map ? searchJson['search'] : null);
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
        final isHuman = instanceClaims is List &&
            instanceClaims.any((claim) {
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
    return AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 18);
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

  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final muted = mutedText(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: active
              ? LinearGradient(colors: [accentColor(context), accentColor(context).withOpacity(.65)])
              : null,
          color: active ? null : pillColor(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMaterialIcon(icon, size: 17, color: active ? Colors.white : muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botão circular preenchido para limpar o campo — bola cinza sólida com
  // "x" branco/contrastante dentro, como no padrão de apps como o Chrome.
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
        child: Icon(Icons.close, size: 14, color: Theme.of(context).scaffoldBackgroundColor),
      ),
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
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: pillColor(context),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: _isFocused ? appText('search') : appText('back'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                        icon: AppMaterialIcon(
                          _isFocused ? AppIcons.magnifyingGlass : AppIcons.arrowLeft,
                          color: muted,
                          size: 19,
                        ),
                        onPressed: () {
                          if (_isFocused) {
                            _submitSearch(_controller.text);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
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
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: aiSearchModeEnabled,
                        builder: (context, aiEnabled, _) => _actionPill(
                          icon: AppIcons.sparkles,
                          label: appText('ai_mode'),
                          active: aiEnabled,
                          onTap: () => aiSearchModeEnabled.value = !aiEnabled,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _actionPill(
                        icon: AppIcons.microphone,
                        label: appText('voice_search'),
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('voice_unavailable')))),
                      ),
                      if (!widget.isIncognito) ...[
                        const SizedBox(width: 8),
                        _actionPill(
                          icon: AppIcons.clockCounterClockwise,
                          label: appText('search_history'),
                          onTap: _showSearchHistory,
                        ),
                      ],
                      const SizedBox(width: 8),
                      _actionPill(
                        icon: AppIcons.compass,
                        label: appText('search_engine'),
                        onTap: () => showSearchEnginePicker(context),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _controller.text.trim().isEmpty
                    ? (widget.isIncognito ? const SizedBox.shrink() : AnimatedBuilder(
                        animation: searchHistoryController,
                        builder: (context, _) {
                          final queries = searchHistoryController.queries;
                          if (queries.isEmpty) return const SizedBox.shrink();
                          return ListView(
                            padding: const EdgeInsets.only(top: 4, bottom: 20),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                                child: Text(appText('recent_searches'), style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              for (final query in queries)
                                ListTile(
                                  leading: AppMaterialIcon(AppIcons.clockCounterClockwise, color: muted, size: 20),
                                  title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 15)),
                                  trailing: IconButton(
                                    tooltip: appText('fill_search'),
                                    icon: AppMaterialIcon(AppIcons.arrowUpLeft, color: muted, size: 19),
                                    onPressed: () => _fillSuggestion(query),
                                  ),
                                  onTap: () => _submitSearch(query),
                                ),
                            ],
                          );
                        },
                      ))
                    // Lista de sugestões com animação suave e rápida: cada
                    // item entra com fade + leve deslocamento vertical.
                    : _suggestions.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              final photo = _suggestionTrailingPhoto(suggestion);
                              return TweenAnimationBuilder<double>(
                                key: ValueKey(suggestion),
                                tween: Tween(begin: 0, end: 1),
                                duration: Duration(milliseconds: 180 + (index * 25).clamp(0, 150)),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) => Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - value) * 8),
                                    child: child,
                                  ),
                                ),
                                child: ListTile(
                                  leading: _suggestionLeading(suggestion, muted),
                                  title: Text(suggestion, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 15)),
                                  trailing: photo ??
                                      IconButton(
                                        tooltip: appText('fill_search'),
                                        icon: AppMaterialIcon(AppIcons.arrowUpLeft, color: muted, size: 19),
                                        onPressed: () => _fillSuggestion(suggestion),
                                      ),
                                  onTap: () => _submitSearch(suggestion),
                                ),
                              );
                            },
                          ),
              ),
            ]),
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