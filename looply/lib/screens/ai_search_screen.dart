import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import '../services/ai_search_service.dart';
import '../widgets/material_symbols.dart';
import '../widgets/rich_ai_text.dart';
import '../widgets/search_engine_pngs.dart';
import '../widgets/drawer_menu_button.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;

/// Pesquisa com IA. A interface e os blocos de resposta são inteiramente
/// Flutter; a renderização de páginas do browser continua na Activity Kotlin.
class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  late final TextEditingController _controller;
  String _submittedQuery = '';
  String _answer = '';
  String? _error;
  bool _isLoading = false;
  int _requestId = 0;
  final StringBuffer _streamBuffer = StringBuffer();
  Timer? _streamUpdateTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _submittedQuery = widget.initialQuery;
    drawer_menu.LooplyDrawerBridge.showHomeAction.value = true;

    final initial = widget.initialQuery.trim();
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runSearch(initial));
      });
    }
  }

  @override
  void didUpdateWidget(covariant AiSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      if (widget.initialQuery != _controller.text) {
        _controller.value = TextEditingValue(
          text: widget.initialQuery,
          selection: TextSelection.collapsed(offset: widget.initialQuery.length),
        );
      }
      _submittedQuery = widget.initialQuery;
      final query = widget.initialQuery.trim();
      if (query.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_runSearch(query));
        });
      } else {
        _requestId++;
        _streamUpdateTimer?.cancel();
        _streamUpdateTimer = null;
        _streamBuffer.clear();
        _answer = '';
        _error = null;
        _isLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _requestId++;
    _streamUpdateTimer?.cancel();
    _streamBuffer.clear();
    drawer_menu.LooplyDrawerBridge.showHomeAction.value = false;
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty || _isLoading) return;
    FocusScope.of(context).unfocus();

    final activeTab = tabsController.activeTab;
    if (activeTab != null && activeTab.url.startsWith('looply://ai-search')) {
      final oldQuery = Uri.tryParse(activeTab.url)?.queryParameters['q'] ?? '';
      if (oldQuery != query) {
        // A atualização da URL é refletida em didUpdateWidget, que inicia
        // uma única consulta e mantém a mesma instância do ecrã.
        tabsController.updateTab(
          activeTab.id,
          url: 'looply://ai-search?q=${Uri.encodeComponent(query)}',
          title: 'AI Search',
        );
        return;
      }
    }
    unawaited(_runSearch(query));
  }

  void _queueStreamToken(String token, int request) {
    if (!mounted || request != _requestId || token.isEmpty) return;
    _streamBuffer.write(token);
    _streamUpdateTimer ??= Timer(const Duration(milliseconds: 70), () {
      _streamUpdateTimer = null;
      if (!mounted || request != _requestId) {
        _streamBuffer.clear();
        return;
      }
      final chunk = _streamBuffer.toString();
      _streamBuffer.clear();
      if (chunk.isNotEmpty) setState(() => _answer += chunk);
    });
  }

  void _flushStreamTokens(int request) {
    _streamUpdateTimer?.cancel();
    _streamUpdateTimer = null;
    if (!mounted || request != _requestId) {
      _streamBuffer.clear();
      return;
    }
    final chunk = _streamBuffer.toString();
    _streamBuffer.clear();
    if (chunk.isNotEmpty) setState(() => _answer += chunk);
  }

  Future<void> _runSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty || !mounted) return;
    final request = ++_requestId;
    _streamUpdateTimer?.cancel();
    _streamUpdateTimer = null;
    _streamBuffer.clear();
    setState(() {
      _submittedQuery = clean;
      _answer = '';
      _error = null;
      _isLoading = true;
    });

    try {
      final answer = await BrowseItAiSearchService.search(
        clean,
        onToken: (token) => _queueStreamToken(token, request),
      );
      if (!mounted || request != _requestId) return;
      _flushStreamTokens(request);
      setState(() {
        _answer = answer;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      _flushStreamTokens(request);
      final message = error.toString().replaceFirst(RegExp(r'^(Bad state|Exception):\s*'), '');
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  Future<void> _copyAnswer() async {
    if (_answer.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _answer));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Resposta copiada.')),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pageBg(context),
      showDragHandle: true,
      builder: (context) => LooplyModalSystemBar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const AppMaterialIcon(AppIcons.image),
                  title: Text(appText('images')),
                  onTap: () => Navigator.of(context).pop(),
                ),
                ListTile(
                  leading: const AppMaterialIcon(AppIcons.uploadSimple),
                  title: Text(appText('files')),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Center(
      key: const ValueKey<String>('ai-search-welcome'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: accentColor(context).withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(searchEngineAsset('AI Search'), width: 42, height: 42, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'AI Search',
              textAlign: TextAlign.center,
              style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              appText('ai_search_description'),
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswer(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return SingleChildScrollView(
      key: ValueKey<String>('ai-search-result-$_submittedQuery'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: pillColor(context),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: lineColor(context).withOpacity(.55), width: .7),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.search_rounded, color: accentColor(context), size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _submittedQuery,
                    style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: accentColor(context).withOpacity(.12), shape: BoxShape.circle),
                child: Center(child: Image.asset(searchEngineAsset('AI Search'), width: 20, height: 20)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text('Resposta', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (_answer.isNotEmpty)
                IconButton(
                  tooltip: appText('copy_address'),
                  visualDensity: VisualDensity.compact,
                  onPressed: _copyAnswer,
                  icon: Icon(Icons.copy_rounded, size: 19, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 7),
          if (_answer.isNotEmpty)
            RichAiText(
              text: _answer,
              bodyTextStyle: TextStyle(color: text, fontSize: 15, height: 1.48),
            ),
          if (_isLoading && _answer.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Row(
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: accentColor(context))),
                  const SizedBox(width: 11),
                  Text('A pesquisar e a organizar a resposta…', style: TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
          if (_isLoading && _answer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(children: [
                SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8, color: accentColor(context))),
                const SizedBox(width: 8),
                Text('A concluir resposta…', style: TextStyle(color: muted, fontSize: 11.5)),
              ]),
            ),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor(context).withOpacity(.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor(context).withOpacity(.22)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, color: accentColor(context), size: 19),
                  const SizedBox(width: 8),
                  Text('Não foi possível obter a resposta', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 7),
                Text(_error!, style: TextStyle(color: muted, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => unawaited(_runSearch(_submittedQuery)),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Tentar novamente'),
                    style: TextButton.styleFrom(foregroundColor: accentColor(context)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    LooplyDrawerMenuButton(
                      onPressed: () => drawer_menu.showLooplyDrawer(context),
                    ),
                    const SizedBox(width: 4),
                    Image.asset(searchEngineAsset('AI Search'), width: 24, height: 24, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    Text('AI Search', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                reverseDuration: const Duration(milliseconds: 140),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: _submittedQuery.trim().isEmpty ? _buildWelcome(context) : _buildAnswer(context),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                      decoration: BoxDecoration(
                        color: pillColor(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: lineColor(context), width: .7),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: appText('add'),
                            onPressed: _showAttachmentOptions,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(width: 40, height: 44),
                            icon: AppMaterialIcon(AppIcons.plus, color: muted, size: 22),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.search,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(color: text, fontSize: 15),
                              cursorColor: accentColor(context),
                              onSubmitted: _submit,
                              decoration: InputDecoration(
                                hintText: appText('search_hint'),
                                hintStyle: TextStyle(color: muted, fontSize: 14),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Material(
                            color: accentColor(context),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _isLoading ? null : () => _submit(_controller.text),
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: Center(child: AppMaterialIcon(AppIcons.arrowUp, color: Colors.white, size: 22)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
