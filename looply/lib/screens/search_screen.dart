import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../shell/browser_navigation.dart';
import '../shell/shell_tab_request.dart';
import '../widgets/looply_popup.dart';
import '../widgets/search_engine_picker.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
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

  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');
  bool _aiSearchEnabled = false;

  static const Map<String, String> _menuLabels = <String, String>{
    'voice': 'Pesquisa por voz',
    'image': 'Pesquisa por imagem',
    'private': 'Novo separador anónimo',
    'history': 'Histórico de pesquisas',
    'engine': 'Máquina de pesquisa',
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _nativeUi.setMethodCallHandler(_handleNativeUiCall);
    unawaited(_loadAiSearchState());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    _nativeUi.setMethodCallHandler(null);
    super.dispose();
  }

  // Lê o estado persistido do interruptor "Pesquisa com IA". O valor fica
  // disponível para uso futuro; por agora não altera nenhum comportamento.
  Future<void> _loadAiSearchState() async {
    try {
      final enabled = await _nativeUi.invokeMethod<bool>('getAiSearchEnabled');
      if (mounted && enabled != null) setState(() => _aiSearchEnabled = enabled);
    } on MissingPluginException {
      // Fora do Android o interruptor nativo não existe; mantém o valor local.
    } on PlatformException {
      // Mantém o valor atual se a leitura falhar por qualquer razão.
    }
  }

  Future<dynamic> _handleNativeUiCall(MethodCall call) async {
    if (call.method == 'aiSearchEnabledChanged') {
      final enabled = call.arguments as bool? ?? false;
      if (mounted) setState(() => _aiSearchEnabled = enabled);
    }
    return null;
  }

  void _onQueryChanged() {
    if (mounted) setState(() {});
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = <String>[]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
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
    if (!isUrl) searchHistoryController.add(value);
    final url = isUrl ? _normalizeUrl(value) : activeSearchEngine.value.buildUrl(value);
    unawaited(BrowserPreconnectHints.preconnect(url));
    openOrbitTab(context, url, title: value);
  }

  void _handleMenuSelection(String action) {
    switch (action) {
      case 'engine':
        showSearchEnginePicker(context);
        break;
      case 'history':
        _showSearchHistory();
        break;
      case 'private':
        final tab = tabsController.createBrowserTab('https://www.google.com', isIncognito: true);
        Navigator.of(context).popUntil((route) => route.isFirst);
        ShellTabRequest.instance.requestBrowser(tab.id);
        break;
      case 'voice':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesquisa por voz ainda não está disponível.')));
        break;
      case 'image':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesquisa por imagem ainda não está disponível.')));
        break;
    }
  }

  void _showSearchHistory() {
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
                  child: Align(alignment: Alignment.centerLeft, child: Text('Pesquisas recentes', style: TextStyle(color: mainText(context), fontSize: 17, fontWeight: FontWeight.w800))),
                ),
                if (searchHistoryController.queries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                    child: Text('Ainda não existem pesquisas guardadas.', style: TextStyle(color: mutedText(context))),
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
                          leading: Icon(Symbols.history_rounded, color: mutedText(context)),
                          title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainText(context))),
                          trailing: Icon(Symbols.north_west_rounded, size: 18, color: mutedText(context)),
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

  // Tenta obter uma imagem para qualquer sugestão que não seja uma URL —
  // pessoa, fruta, clube, ou qualquer outra entidade que o Wikidata/Wikimedia
  // tenha associada a uma imagem (P18), exatamente como a Wikipedia mostra.
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

  // Procura a imagem (P18) de qualquer entidade Wikidata que corresponda ao
  // termo — pessoa, fruta, clube, cidade, o que for — sem restringir a
  // seres humanos. É o mesmo tipo de imagem que a Wikipedia já mostra ao
  // lado dos artigos.
  Future<String?> _lookupWikidataEntityPhoto(String name) async {
    try {
      final searchUri = Uri.https('www.wikidata.org', '/w/api.php', <String, String>{
        'action': 'wbsearchentities',
        'search': name,
        'language': 'pt',
        'uselang': 'pt',
        'format': 'json',
        'limit': '4',
      });
      final searchResponse = await http.get(searchUri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (searchResponse.statusCode != 200) return null;
      final searchJson = jsonDecode(utf8.decode(searchResponse.bodyBytes));
      final results = (searchJson is Map ? searchJson['search'] : null);
      if (results is! List || results.isEmpty) return null;

      final normalizedName = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final matchingResults = results.whereType<Map>().where((item) {
        final label = item['label']?.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        return label == normalizedName;
      });
      // Se nada bater exatamente com o texto digitado, aceita os melhores
      // resultados da pesquisa mesmo assim — cobre nomes incompletos ainda
      // a ser digitados, tal como a pessoa está a escrever.
      final ids = (matchingResults.isNotEmpty ? matchingResults : results.whereType<Map>())
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => RegExp(r'^Q\d+$').hasMatch(id))
          .take(3)
          .toList(growable: false);
      if (ids.isEmpty) return null;

      final entityUri = Uri.https('www.wikidata.org', '/w/api.php', <String, String>{
        'action': 'wbgetentities',
        'ids': ids.join('|'),
        'props': 'claims',
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
        // Sem filtro de "é humano": qualquer entidade com imagem (P18)
        // serve — pessoa, fruta, clube, cidade, o que o Wikidata tiver.
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
        return _SuggestionImage(url: favicon, fallback: Symbols.public_rounded, muted: muted);
      }
    }
    final photo = _entityPhotoCache[suggestion];
    if (photo != null) return _SuggestionImage(url: photo, fallback: Symbols.search_rounded, muted: muted);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
      child: Icon(Symbols.search_rounded, color: muted, size: 17),
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
                      tooltip: 'Voltar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                      icon: Icon(Symbols.arrow_back_rounded, color: muted, size: 19),
                      onPressed: () => Navigator.of(context).pop(),
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
                          hintText: 'Pesquisar ou escrever um URL',
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
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 32, height: 38),
                        icon: Icon(Symbols.close_rounded, color: muted, size: 17),
                        onPressed: () {
                          _controller.clear();
                          _focusNode.requestFocus();
                        },
                      ),
                    LooplyPopupMenuButton<String>(
                      tooltip: 'Mais opções de pesquisa',
                      iconColor: muted,
                      includeAiToggle: true,
                      onAiToggleChanged: (value) {
                        setState(() => _aiSearchEnabled = value);
                        // Sem efeito por agora — apenas guarda a preferência
                        // (via canal nativo no Android) para uso futuro.
                      },
                      actions: const <LooplyPopupAction<String>>[
                        LooplyPopupAction(value: 'voice', label: 'Pesquisa por voz', icon: Icons.mic_none_rounded),
                        LooplyPopupAction(value: 'image', label: 'Pesquisa por imagem', icon: Icons.image_search_rounded),
                        LooplyPopupAction(value: 'private', label: 'Novo separador anónimo', icon: Icons.visibility_off_rounded),
                        LooplyPopupAction(value: 'history', label: 'Histórico de pesquisas', icon: Symbols.history_rounded),
                        LooplyPopupAction(value: 'engine', label: 'Máquina de pesquisa', icon: Symbols.travel_explore_rounded),
                      ],
                      onSelected: _handleMenuSelection,
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: lineColor(context)),
            Expanded(
              child: _controller.text.trim().isEmpty
                  ? AnimatedBuilder(
                      animation: searchHistoryController,
                      builder: (context, _) {
                        final queries = searchHistoryController.queries;
                        if (queries.isEmpty) return const SizedBox.shrink();
                        return ListView(
                          padding: const EdgeInsets.only(top: 12, bottom: 20),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                              child: Text('Pesquisas recentes', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                            for (final query in queries)
                              ListTile(
                                leading: Icon(Symbols.history_rounded, color: muted, size: 20),
                                title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 15)),
                                trailing: IconButton(
                                  tooltip: 'Preencher pesquisa',
                                  icon: Icon(Icons.north_west_rounded, color: muted, size: 19),
                                  onPressed: () => _fillSuggestion(query),
                                ),
                                onTap: () => _submitSearch(query),
                              ),
                          ],
                        );
                      },
                    )
                  : _suggestions.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: _suggestionLeading(suggestion, muted),
                              title: Text(suggestion, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 15)),
                              trailing: IconButton(
                                tooltip: 'Preencher pesquisa',
                                icon: Icon(Icons.north_west_rounded, color: muted, size: 19),
                                onPressed: () => _fillSuggestion(suggestion),
                              ),
                              onTap: () => _submitSearch(suggestion),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }


}

class _SuggestionImage extends StatelessWidget {
  const _SuggestionImage({required this.url, required this.fallback, required this.muted});
  final String url;
  final IconData fallback;
  final Color muted;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Container(
          width: 34,
          height: 34,
          color: pillColor(context),
          child: Image.network(
            url,
            width: 34,
            height: 34,
            fit: BoxFit.cover,
            cacheWidth: 96,
            cacheHeight: 96,
            errorBuilder: (_, __, ___) => Icon(fallback, color: muted, size: 17),
          ),
        ),
      );
}