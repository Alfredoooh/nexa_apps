import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import '../services/ai_search_service.dart';
import '../widgets/material_symbols.dart';
import '../widgets/rich_ai_text.dart';
import '../widgets/drawer_menu_button.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;

enum _AiChatRole { user, assistant }

enum _AiMenuAction { clearConversation }

class _AiChatMessage {
  _AiChatMessage({required this.role, required this.text, this.isStreaming = false});
  final _AiChatRole role;
  String text;
  bool isStreaming;
}

/// Interface de AI Search inspirada no layout compacto do ecrã de conversa:
/// barra superior, marca central, sugestões horizontais e compositor fixo.
class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  late final TextEditingController _controller;
  final List<_AiChatMessage> _messages = <_AiChatMessage>[];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  int _requestId = 0;
  final StringBuffer _streamBuffer = StringBuffer();
  Timer? _streamUpdateTimer;

  static const List<String> _suggestions = <String>[
    'Create an image for my presentation',
    'Design a programming tutor that teaches basics in a fun way',
    'Explain a difficult topic with simple examples',
  ];

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
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty || _isLoading) return;
    FocusScope.of(context).unfocus();
    _controller.clear();
    setState(() {});
    unawaited(_runSearch(query));
  }

  void _startNewConversation() {
    _requestId++;
    _streamUpdateTimer?.cancel();
    _streamUpdateTimer = null;
    _streamBuffer.clear();
    FocusScope.of(context).unfocus();
    _controller.clear();
    setState(() {
      _messages.clear();
      _isLoading = false;
    });
  }

  void _showAttachmentNotice() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Os anexos ainda não estão configurados nesta versão.'),
          duration: Duration(seconds: 2),
        ),
      );
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
      if (chunk.isNotEmpty && _messages.isNotEmpty) {
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
    if (chunk.isNotEmpty && _messages.isNotEmpty) {
      setState(() => _messages.last.text += chunk);
    }
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
    final muted = mutedText(context);
    return Center(
      key: const ValueKey<String>('ai-search-empty'),
      child: Image.asset(
        'assets/ai_search/ai_mark.png',
        width: 72,
        height: 72,
        fit: BoxFit.contain,
        color: muted.withOpacity(.38),
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.high,
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
          color: pillColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(7),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: mainText(context), fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w500),
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
                  Image.asset(
                    'assets/ai_search/ai_mark.png',
                    width: 20,
                    height: 20,
                    color: muted,
                    colorBlendMode: BlendMode.srcIn,
                  ),
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

  Widget _topAction({required IconData icon, required String tooltip, required VoidCallback onPressed}) {
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
            width: 42,
            height: 42,
            child: Center(child: AppMaterialIcon(icon, color: mainText(context), size: 23)),
          ),
        ),
      ),
    );
  }

  Widget _composerAction({required IconData icon, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _showAttachmentNotice,
          child: SizedBox(
            width: 34,
            height: 48,
            child: Center(child: AppMaterialIcon(icon, color: mainText(context), size: 25)),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final muted = mutedText(context);
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: LooplyDrawerMenuButton(
              onPressed: () => drawer_menu.showLooplyDrawer(context),
            ),
          ),
          Center(
            child: Material(
              color: pillColor(context),
              borderRadius: BorderRadius.circular(15),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('BrowseIt Plus ainda não está disponível.')));
                },
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Get Plus', style: TextStyle(color: mainText(context), fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      AppMaterialIcon(AppIcons.sparkles, size: 19, color: mainText(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _topAction(
                  icon: AppIcons.pencilSimple,
                  tooltip: 'New chat',
                  onPressed: _startNewConversation,
                ),
                PopupMenuButton<_AiMenuAction>(
                  tooltip: 'More options',
                  icon: AppMaterialIcon(AppIcons.dotsThreeVertical, color: mainText(context), size: 23),
                  color: panelColor(context),
                  onSelected: (action) {
                    switch (action) {
                      case _AiMenuAction.clearConversation:
                        _startNewConversation();
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<_AiMenuAction>>[
                    PopupMenuItem<_AiMenuAction>(
                      value: _AiMenuAction.clearConversation,
                      child: Row(
                        children: [
                          AppMaterialIcon(AppIcons.trash, size: 19, color: muted),
                          const SizedBox(width: 10),
                          Text(appText('clear'), style: TextStyle(color: mainText(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final text = mainText(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final prompt = _suggestions[index];
          final words = switch (index) {
            0 => const ['Create an image', 'for my presentation'],
            1 => const ['Design a programming tutor', 'that teaches basics in a fun way'],
            _ => const ['Explain a difficult topic', 'with simple examples'],
          };
          return Material(
            color: isDark ? pillColor(context) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _submit(prompt),
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: index == 1 ? 258 : 218,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(words[0], maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 15.5, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(words[1], maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: mutedText(context), fontSize: 14.5)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final hasText = _controller.text.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          _composerAction(icon: Symbols.photo_camera_rounded, tooltip: 'Camera'),
          const SizedBox(width: 3),
          _composerAction(icon: AppIcons.image, tooltip: 'Photos'),
          const SizedBox(width: 3),
          _composerAction(icon: Symbols.folder_open_rounded, tooltip: 'Files'),
          const SizedBox(width: 7),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.fromLTRB(17, 4, 5, 4),
              decoration: BoxDecoration(
                color: isDark ? panelColor(context) : const Color(0xFFE9E9E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _submit,
                      style: TextStyle(color: text, fontSize: 15.5, height: 1.35),
                      cursorColor: accentColor(context),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(color: muted.withOpacity(.95), fontSize: 15.5),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: hasText ? () => _submit(_controller.text) : _showAttachmentNotice,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Center(
                          child: AppMaterialIcon(
                            hasText ? AppIcons.arrowUp : AppIcons.microphone,
                            size: 22,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Material(
            color: Colors.black,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showAttachmentNotice,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(Symbols.graphic_eq_rounded, color: Colors.white, size: 26, weight: 500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final empty = _messages.isEmpty;

    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: empty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 22),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return message.role == _AiChatRole.user
                            ? _buildUserBubble(context, message)
                            : _buildAssistantMessage(context, message);
                      },
                    ),
            ),
            if (empty && !keyboardVisible) _buildSuggestions(context),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }
}
