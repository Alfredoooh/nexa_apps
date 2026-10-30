import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import 'browser_screen.dart';

/// Ecrã de pesquisa e introdução de endereços do navegador Looply.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _resolveAddress(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';

    final parsed = Uri.tryParse(value);
    if (parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https') &&
        parsed.host.isNotEmpty) {
      return parsed.toString();
    }

    final looksLikeDomain = !value.contains(' ') &&
        value.contains('.') &&
        !value.startsWith('.') &&
        !value.endsWith('.');
    if (looksLikeDomain) return 'https://$value';

    return activeSearchEngine.value.buildUrl(value);
  }

  void _submit() {
    final url = _resolveAddress(_inputController.text);
    if (url.isEmpty) return;

    final navigator = Navigator.of(context);
    final tab = tabsController.createBrowserTab(url);
    tabsController.activate(tab.id);
    activityController.log(ActivityKind.site, _inputController.text.trim(), url);

    navigator.pop();
    navigator.push(openBrowserRoute(tabId: tab.id, initialUrl: url));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = mainText(context);
    final muted = mutedText(context);
    final background = pageBg(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: background,
              statusBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: background,
              statusBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          toolbarHeight: 64,
          leading: IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Symbols.arrow_back_rounded),
          ),
          title: Text('Pesquisar', style: TextStyle(color: text)),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: pillColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: lineColor(context)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 15),
                      Icon(Symbols.search_rounded, color: muted, size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          autofocus: false,
                          textInputAction: TextInputAction.go,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          enableSuggestions: true,
                          style: TextStyle(color: text, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar ou escrever um URL',
                            hintStyle: TextStyle(color: muted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 17),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Abrir',
                        onPressed: _submit,
                        icon: const Icon(Symbols.arrow_forward_rounded),
                        color: looplyPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Motor de pesquisa',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<SearchEngine>(
                  valueListenable: activeSearchEngine,
                  builder: (context, active, _) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: searchEngines.map((engine) {
                      final selected = engine.name == active.name;
                      return ChoiceChip(
                        label: Text(engine.name),
                        selected: selected,
                        onSelected: (_) => activeSearchEngine.value = engine,
                        labelStyle: TextStyle(
                          color: selected ? looplyPrimary : text,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        selectedColor: looplyPrimary.withOpacity(.14),
                        backgroundColor: pillColor(context),
                        side: BorderSide(
                          color: selected ? looplyPrimary.withOpacity(.5) : lineColor(context),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
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
