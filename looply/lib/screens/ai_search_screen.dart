import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import '../services/ai_search_service.dart';
import '../widgets/material_symbols.dart';
import '../widgets/rich_ai_text.dart';
import '../widgets/drawer_menu_button.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;

enum _AiChatRole { user, assistant }

class _AiChatMessage {
  _AiChatMessage({required this.role, required this.text, this.isStreaming = false});
  final _AiChatRole role;
  String text;
  bool isStreaming;
}

/// Pesquisa com IA, em formato de conversa. Interface inteiramente Flutter.
class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  late final TextEditingController _controller;
  final List<_AiChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  int _requestId = 0;
  final StringBuffer _streamBuffer = StringBuffer();
  Timer? _streamUpdateTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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
      final query = widget.initialQuery.trim();
      if (query.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_runSearch(query));
        });
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty || _isLoading) return;
    FocusScope.of(context).unfocus();
    _controller.clear();
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
      if (chunk.isNotEmpty) {
        setState(() => _messages.last.text += chunk);
        _scrollToBottom();
      }
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
    if (chunk.isNotEmpty) setState(() => _messages.last.text += chunk);
  }

  Future<void> _runSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty || !mounted) return;
    final request = ++_requestId;
    _streamUpdateTimer?.cancel();
    _streamUpdateTimer = null;
    _streamBuffer.clear();

    setState(() {
      _messages.add(_AiChatMessage(role: _AiChatRole.user, text: clean));
      _messages.add(_AiChatMessage(role: _AiChatRole.assistant, text: '', isStreaming: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final answer = await BrowseItAiSearchService.search(
        clean,
        onToken: (token) => _queueStreamToken(token, request),
      );
      if (!mounted || request != _requestId) return;
      _flushStreamTokens(request);
      setState(() {
        _messages.last.text = answer;
        _messages.last.isStreaming = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      _flushStreamTokens(request);
      final message = error.toString().replaceFirst(RegExp(r'^(Bad state|Exception):\s*'), '');
      setState(() {
        _messages.last.text = message.isEmpty ? appText('answer_failed') : message;
        _messages.last.isStreaming = false;
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      key: const ValueKey<String>('ai-search-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          appText('ai_thinking'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: mutedText(context),
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, _AiChatMessage message) {
  final scheme = Theme.of(context).colorScheme;
  return Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        message.text,
        style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

  Widget _buildAssistantMessage(BuildContext context, _AiChatMessage message) {
    final muted = mutedText(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: message.text.isEmpty && message.isStreaming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor(context))),
                  const SizedBox(width: 10),
                  Text(appText('searching_answer'), style: TextStyle(color: muted, fontSize: 13)),
                ],
              )
            : RichAiText(
                text: message.text,
                bodyTextStyle: TextStyle(color: mainText(context), fontSize: 15.5, height: 1.5),
              ),
      ),
    );
  }

  Widget _composerIcon({required IconData icon, required String tooltip, required VoidCallback? onPressed}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(child: AppMaterialIcon(icon, color: mutedText(context), size: 22)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final hasText = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 62,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: LooplyDrawerMenuButton(
                    onPressed: () => drawer_menu.showLooplyDrawer(context),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return message.role == _AiChatRole.user
                            ? _buildUserBubble(context, message)
                            : _buildAssistantMessage(context, message);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: panelColor(context),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  _composerIcon(
                    icon: AppIcons.plus,
                    tooltip: appText('add'),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submit,
                      style: TextStyle(color: text, fontSize: 16, height: 1.4),
                      cursorColor: accent,
                      decoration: InputDecoration(
                        hintText: appText('ask_anything'),
                        hintStyle: TextStyle(color: muted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Material(
                    color: hasText ? accent : mutedText(context).withOpacity(.16),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: (hasText && !_isLoading) ? () => _submit(_controller.text) : null,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: AppMaterialIcon(
                            AppIcons.arrowUp,
                            size: 20,
                            color: hasText ? Theme.of(context).colorScheme.onPrimary : mutedText(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}