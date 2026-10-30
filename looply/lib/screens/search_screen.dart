import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import 'browser_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  List<String> _suggestions = [];
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _focusNode.requestFocus(); });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final sequence = ++_requestSequence;
    try {
      final uri = Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&q=${Uri.encodeQueryComponent(query)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 || !mounted || sequence != _requestSequence) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final list = (decoded.length > 1 ? decoded[1] as List<dynamic> : <dynamic>[]).map((item) => item.toString()).toList();
      if (mounted && sequence == _requestSequence) setState(() => _suggestions = list);
    } catch (_) {}
  }

  void _submitSearch(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    final url = _looksLikeUrl(value) ? _normalizeUrl(value) : activeSearchEngine.value.buildUrl(value);
    NavAccelerator.instance.preconnect(url);
    final tab = tabsController.createBrowserTab(url);
    tabsController.activate(tab.id);
    activityController.log(ActivityKind.site, value, url);
    // Substitui a pesquisa pelo ecrã normal do navegador.
    Navigator.of(context).pushReplacement(openBrowserRoute(tabId: tab.id, initialUrl: url));
  }

  bool _looksLikeUrl(String text) => !text.contains(' ') && (text.contains('.') || text.startsWith('localhost'));
  String _normalizeUrl(String text) => (text.startsWith('http://') || text.startsWith('https://')) ? text : 'https://$text';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.light) : SystemUiOverlayStyle.dark.copyWith(statusBarColor: bg, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 3, 14, 8),
              child: Row(children: [
                IconButton(tooltip: 'Voltar', icon: Icon(Symbols.arrow_back_rounded, color: text), onPressed: () => Navigator.of(context).pop()),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: text, fontSize: 17),
                      cursorColor: accentColor(context),
                      onSubmitted: _submitSearch,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: bg,
                        hintText: 'Pesquisar ou escrever um URL',
                        hintStyle: TextStyle(color: muted, fontSize: 15),
                        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(tooltip: 'Limpar', icon: Icon(Symbols.close_rounded, color: muted), onPressed: () { _controller.clear(); _focusNode.requestFocus(); }),
              ]),
            ),
            Divider(height: 1, color: lineColor(context)),
            Expanded(
              child: _suggestions.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          leading: Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: Icon(Symbols.search_rounded, color: muted, size: 18)),
                          title: Text(suggestion, style: TextStyle(color: text, fontSize: 15)),
                          onTap: () { _controller.text = suggestion; _submitSearch(suggestion); },
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