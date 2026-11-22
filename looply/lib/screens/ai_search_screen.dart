import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;

import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'search_screen.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import '../services/ai_search_service.dart';
import '../widgets/material_symbols.dart';
import '../widgets/rich_ai_text.dart';
import '../widgets/drawer_menu_button.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;

enum _AiChatRole { user, assistant }
enum _AiAttachmentAction { image, camera }

class _PickedAiImage {
  const _PickedAiImage({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

class _AiChatMessage {
  _AiChatMessage({
    required this.role,
    required this.text,
    this.image,
    this.isStreaming = false,
  });

  final _AiChatRole role;
  final _PickedAiImage? image;
  String text;
  bool isStreaming;
}

/// Ecrã AI Search em estilo de conversa: apenas drawer no topo,
/// identidade BrowseIt AI no estado vazio e composer flutuante inferior.
class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  late final TextEditingController _controller;
  final ImagePicker _imagePicker = ImagePicker();
  final List<_AiChatMessage> _messages = <_AiChatMessage>[];
  final ScrollController _scrollController = ScrollController();
  _PickedAiImage? _pendingImage;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_recoverLostPickerData());
    });
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

  Future<void> _recoverLostPickerData() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty || !mounted) return;
      final files = response.files;
      final file = response.file ?? (files != null && files.isNotEmpty ? files.first : null);
      if (file != null) await _attachPickedFile(file);
    } catch (_) {
      // A recuperação só é necessária quando o Android recria a Activity
      // durante a utilização da câmara ou do seletor de imagens.
    }
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
    if (_isLoading) return;
    final image = _pendingImage;
    final enteredText = raw.trim();
    if (enteredText.isEmpty && image == null) return;

    final query = enteredText.isEmpty ? 'Analisa a imagem anexada.' : enteredText;
    FocusScope.of(context).unfocus();
    _controller.clear();
    setState(() => _pendingImage = null);
    unawaited(_runSearch(query, image: image));
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
      _pendingImage = null;
      _isLoading = false;
    });
  }

  Future<void> _handleAttachmentAction(_AiAttachmentAction action) async {
    switch (action) {
      case _AiAttachmentAction.image:
        await _pickImage(ImageSource.gallery);
        break;
      case _AiAttachmentAction.camera:
        await _pickImage(ImageSource.camera);
        break;
    }
  }

  Future<void> _showAttachmentModal() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar anexos',
      barrierColor: Colors.black.withOpacity(.18),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final safe = MediaQuery.viewPaddingOf(dialogContext);
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                safe.left > 0 ? safe.left + 7 : 12,
                12,
                safe.right > 0 ? safe.right + 7 : 12,
                safe.bottom + 12,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Material(
                  color: popupSurfaceColor(dialogContext),
                  surfaceTintColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        leading: AppMaterialIcon(AppIcons.image, size: 23, color: mainText(dialogContext)),
                        title: Text('Imagem', style: TextStyle(color: mainText(dialogContext), fontSize: 15, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          unawaited(_handleAttachmentAction(_AiAttachmentAction.image));
                        },
                      ),
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        leading: AppMaterialIcon(Symbols.photo_camera_rounded, size: 23, color: mainText(dialogContext)),
                        title: Text('Câmara', style: TextStyle(color: mainText(dialogContext), fontSize: 15, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          unawaited(_handleAttachmentAction(_AiAttachmentAction.camera));
                        },
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .075), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween<double>(begin: .985, end: 1).animate(curved), child: child),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      await _attachPickedFile(file);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera
                ? 'Não foi possível abrir a câmara.'
                : 'Não foi possível abrir as imagens.'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _attachPickedFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    final name = file.name.trim().isEmpty ? 'browseit-image.jpg' : file.name;
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };

    FocusScope.of(context).unfocus();
    setState(() {
      _pendingImage = _PickedAiImage(name: name, mimeType: mimeType, bytes: bytes);
    });
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

  Future<void> _runSearch(String query, {_PickedAiImage? image}) async {
    final clean = query.trim();
    if (clean.isEmpty || !mounted) return;
    final request = ++_requestId;
    _streamUpdateTimer?.cancel();
    _streamUpdateTimer = null;
    _streamBuffer.clear();

    setState(() {
      _messages.add(_AiChatMessage(role: _AiChatRole.user, text: clean, image: image));
      _messages.add(_AiChatMessage(role: _AiChatRole.assistant, text: '', isStreaming: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final imagePayload = image == null
          ? const <BrowseItAiImage>[]
          : <BrowseItAiImage>[
              BrowseItAiImage(name: image.name, mimeType: image.mimeType, bytes: image.bytes),
            ];
      final answer = await BrowseItAiSearchService.search(
        clean,
        images: imagePayload,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isDark ? const Color(0xFFA8A8A8) : const Color(0xFFD4D7DB);
    return Center(
      key: const ValueKey<String>('ai-search-empty'),
      child: SizedBox(
        width: 212,
        height: 212,
        child: CustomPaint(
          painter: _LooplySplashRingPainter(ringColor),
          isComplex: false,
          willChange: false,
        ),
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, _AiChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: pillColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  message.image!.bytes,
                  width: 216,
                  height: 164,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: 9),
            ],
            Text(
              message.text,
              style: TextStyle(color: mainText(context), fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ],
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
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Lottie.asset(
                      'assets/animations/cobalt_sprite_ai.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
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

  Widget _buildTopBar(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final iconColor = mainText(context);
    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(color: pageBg(context)),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LooplyDrawerMenuButton(
                onPressed: () => drawer_menu.showLooplyDrawerFromRoute(context),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Pesquisar',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).push<void>(
                            CupertinoPageRoute<void>(builder: (_) => const SearchScreen()),
                          );
                        },
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: AppMaterialIcon(
                              AppIcons.magnifyingGlass,
                              size: 23,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: 'Nova conversa',
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _startNewConversation,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/svg/regular/new-message.svg',
                                width: 23,
                                height: 23,
                                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    final image = _pendingImage;
    if (image == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 7),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              image.bytes,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: mainText(context),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _pendingImage = null),
                child: SizedBox(
                  width: 19,
                  height: 19,
                  child: Center(child: AppMaterialIcon(AppIcons.x, size: 12, color: pageBg(context))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty || _pendingImage != null;
    final enabled = canSubmit && !_isLoading;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      // Mantém a barra ligeiramente acima da navegação Android, com margem
      // consistente em dispositivos com e sem gesture navigation.
      padding: EdgeInsets.fromLTRB(16, 8, 16, 21 + (bottomInset > 0 ? 2 : 0)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        decoration: BoxDecoration(
          color: inputBarTone(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: lineColor(context).withOpacity(.32), width: .7),
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _showAttachmentModal,
                child: SizedBox(
                  width: 44,
                  height: 48,
                  child: Center(child: AppMaterialIcon(AppIcons.plus, size: 28, color: mainText(context))),
                ),
              ),
            ),
            _buildAttachmentPreview(context),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: _submit,
                style: TextStyle(color: mainText(context), fontSize: 16, height: 1.35),
                cursorColor: accentColor(context),
                decoration: InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: mutedText(context).withOpacity(.95), fontSize: 16),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Material(
              color: enabled ? accentColor(context) : pillColor(context),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? () => _submit(_controller.text) : null,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AppMaterialIcon(
                      AppIcons.arrowUp,
                      size: 25,
                      color: enabled ? Colors.white : mutedText(context),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  Expanded(
                    child: _messages.isEmpty
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
                  _buildComposer(context),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),
        ],
      ),
    );
  }
}


/// The same neutral circular ring used by the native splash in both themes.
/// Geometry mirrors the Android VectorDrawable viewport (1000 x 1000).
class _LooplySplashRingPainter extends CustomPainter {
  const _LooplySplashRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * .082
      ..isAntiAlias = true;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      side * .25,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LooplySplashRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
