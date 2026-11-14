import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/richtext.dart';
import '../../widgets/app_sheet.dart';
import '../ai_widgets/ai_widgets.dart';
import '../apps/app_types.dart';
import '../apps/sheets/sheets_screen.dart';
import 'chat_models.dart';
import 'widgets/chat_widgets_shared.dart';
import 'chat_progress_cards.dart';
import '../../core/navigation/app_page_route.dart';
import 'chat_image_viewer_screen.dart';

TextStyle aiBodyTextStyle(AppColorScheme s) => TextStyle(
      fontSize: 15,
      height: 1.45,
      color: s.onSurface,
    );

const double _kFlatModalRadius = 10.0;

// ──────────────────────────────────────────────────────────────
// DIÁLOGO ABRIR LINK EXTERNO
// ──────────────────────────────────────────────────────────────

Future<void> showOpenLinkDialog(
  BuildContext context,
  AppColorScheme s, {
  required String url,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: s.isDark ? s.cardBackground : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Abrir link', style: TextStyle(color: s.onSurface, fontSize: 17, fontWeight: FontWeight.w700)),
      content: Text(
        'Abrir "$url" no navegador do telemóvel?',
        style: TextStyle(color: s.onSurfaceVariant, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancelar', style: TextStyle(color: s.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Abrir', style: TextStyle(color: s.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ──────────────────────────────────────────────────────────────
// BOLHA DO UTILIZADOR
// ──────────────────────────────────────────────────────────────

class UserBubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  final List<Map<String, dynamic>>? attachments;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSelectText;
  final bool isBeingEdited;
  const UserBubble({
    super.key,
    required this.s,
    required this.text,
    this.attachments,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onSelectText,
    this.isBeingEdited = false,
  });

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  bool _expanded = false;
  static const int _collapseThreshold = 360;

  bool get _isLong => widget.text.length > _collapseThreshold;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bubbleColor = s.userBubbleBg;
    final textColor = s.userBubbleText;
    final showCollapsed = _isLong && !_expanded;
    final displayText = showCollapsed
        ? widget.text.substring(0, _collapseThreshold).trimRight() + '…'
        : widget.text;

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.attachments != null && widget.attachments!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.attachments!
                      .map((a) => _UserAttachmentCard(s: s, attachment: a))
                      .toList(),
                ),
              ),
            ),
          if (widget.text.isNotEmpty)
            GestureDetector(
              onLongPress: widget.isBeingEdited
                  ? null
                  : () {
                      final box = context.findRenderObject() as RenderBox;
                      final off = box.localToGlobal(Offset.zero);
                      final sz = box.size;
                      showMessageActionsPopup(
                        context,
                        s,
                        anchorOffset: off,
                        anchorSize: sz,
                        onEdit: widget.onEdit,
                        onCopy: widget.onCopy,
                        onDelete: widget.onDelete,
                        onSelectText: widget.onSelectText,
                      );
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: s.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayText, style: TextStyle(color: textColor, fontSize: 14)),
                    if (_isLong) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded ? 'Mostrar menos' : 'Mostrar mais',
                              style: TextStyle(
                                color: textColor.withOpacity(0.85),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: Icon(RoundedSymbols.keyboardArrowDown, size: 16, color: textColor.withOpacity(0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CARD DE ANEXO — dispatcher
// ──────────────────────────────────────────────────────────────

class _UserAttachmentCard extends StatelessWidget {
  final AppColorScheme s;
  final Map<String, dynamic> attachment;
  const _UserAttachmentCard({required this.s, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final mimeType = attachment['mimeType']?.toString() ?? '';
    final isImage = mimeType.startsWith('image/');
    final isPdf = mimeType == 'application/pdf';

    if (isImage) return _ImageAttachmentThumb(s: s, attachment: attachment);
    if (isPdf) return _PdfAttachmentThumb(s: s, attachment: attachment);
    return _FileAttachmentCard(s: s, attachment: attachment);
  }
}

class _ImageAttachmentThumb extends StatelessWidget {
  final AppColorScheme s;
  final Map<String, dynamic> attachment;
  const _ImageAttachmentThumb({required this.s, required this.attachment});

  Uint8List? get _bytes {
    final b64 = attachment['base64']?.toString();
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  void _openFullScreen(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: AitabImageViewerScreen(
            file: AttachedFile(
              id: attachment['id']?.toString() ?? UniqueKey().toString(),
              name: attachment['name']?.toString() ?? 'imagem',
              mimeType: attachment['mimeType']?.toString() ?? 'image/jpeg',
              bytes: bytes,
            ),
            isImage: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: bytes != null
            ? Image.memory(bytes, width: 84, height: 84, fit: BoxFit.cover)
            : Container(
                width: 84,
                height: 84,
                color: s.cardBackground,
                child: Icon(RoundedSymbols.image, color: s.onSurfaceVariant),
              ),
      ),
    );
  }
}

class _PdfAttachmentThumb extends StatefulWidget {
  final AppColorScheme s;
  final Map<String, dynamic> attachment;
  const _PdfAttachmentThumb({required this.s, required this.attachment});

  @override
  State<_PdfAttachmentThumb> createState() => _PdfAttachmentThumbState();
}

class _PdfAttachmentThumbState extends State<_PdfAttachmentThumb> {
  Uint8List? _thumbBytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _renderFirstPage();
  }

  Future<void> _renderFirstPage() async {
    final b64 = widget.attachment['base64']?.toString();
    if (b64 == null || b64.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    try {
      final pdfBytes = base64Decode(b64);
      final doc = await PdfDocument.openData(pdfBytes);
      final page = await doc.getPage(1);
      final rendered = await page.render(
        width: page.width * 1.4,
        height: page.height * 1.4,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();
      if (mounted && rendered != null) {
        setState(() => _thumbBytes = rendered.bytes);
      } else if (mounted) {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _openFullScreen(BuildContext context) {
    final b64 = widget.attachment['base64']?.toString();
    if (b64 == null) return;
    Uint8List bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: AitabImageViewerScreen(
            file: AttachedFile(
              id: widget.attachment['id']?.toString() ?? UniqueKey().toString(),
              name: widget.attachment['name']?.toString() ?? 'documento.pdf',
              mimeType: 'application/pdf',
              bytes: bytes,
            ),
            isImage: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.attachment['name']?.toString() ?? 'documento.pdf';

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 118,
                height: 84,
                child: _failed || _thumbBytes == null
                    ? Container(
                        color: Colors.white.withOpacity(0.08),
                        alignment: Alignment.center,
                        child: AppIcon('pdf', size: 26, color: Colors.white),
                      )
                    : Image.memory(_thumbBytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileAttachmentCard extends StatelessWidget {
  final AppColorScheme s;
  final Map<String, dynamic> attachment;
  const _FileAttachmentCard({required this.s, required this.attachment});

  String get _formattedSize {
    final b64 = attachment['base64']?.toString() ?? '';
    if (b64.isEmpty) return '';
    final approxBytes = (b64.length * 3 / 4).round();
    if (approxBytes < 1024) return '$approxBytes B';
    final kb = approxBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB'.replaceAll('.', ',');
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)}MB'.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final name = attachment['name']?.toString() ?? 'ficheiro';
    final mimeType = attachment['mimeType']?.toString() ?? '';
    final isZip = mimeType == 'application/zip';
    final iconName = isZip ? 'folder_upload' : 'attach';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: AppIcon(iconName, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_formattedSize.isNotEmpty)
                  Text(
                    _formattedSize,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CARDS DE RESULTADO DE TOOL
// ──────────────────────────────────────────────────────────────

class ToolResultImageCard extends StatefulWidget {
  final AppColorScheme s;
  final String base64Png;
  final String label;

  const ToolResultImageCard({
    super.key,
    required this.s,
    required this.base64Png,
    required this.label,
  });

  @override
  State<ToolResultImageCard> createState() => _ToolResultImageCardState();
}

class _ToolResultImageCardState extends State<ToolResultImageCard> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant ToolResultImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Png != widget.base64Png) {
      _decode();
    }
  }

  void _decode() {
    try {
      _cachedBytes = base64Decode(widget.base64Png);
    } catch (_) {
      _cachedBytes = null;
    }
  }

  void _openFullscreen(BuildContext context) {
    final bytes = _cachedBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => _FullscreenImageScreen(
          bytes: bytes,
          label: widget.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bytes = _cachedBytes;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: s.cardShadow,
        ),
        child: Row(
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.memory(bytes, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: s.hover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(RoundedSymbols.imageNotSupported, size: 18, color: s.onSurfaceVariant),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque para visualizar',
                    style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            AppIcon('expand', size: 18, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImageScreen extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  const _FullscreenImageScreen({required this.bytes, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              clipBehavior: Clip.none,
              child: Center(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    _CircularBackButtonDark(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularBackButtonDark extends StatefulWidget {
  final VoidCallback onTap;
  const _CircularBackButtonDark({required this.onTap});
  @override
  State<_CircularBackButtonDark> createState() => _CircularBackButtonDarkState();
}

class _CircularBackButtonDarkState extends State<_CircularBackButtonDark> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? Colors.white24 : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: const Icon(RoundedSymbols.arrowBack, color: Colors.white, size: 18),
      ),
    );
  }
}

class _CircularBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _CircularBackButton({required this.s, required this.onTap});
  @override
  State<_CircularBackButton> createState() => _CircularBackButtonState();
}

class _CircularBackButtonState extends State<_CircularBackButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: AppIcon('back', color: s.onSurface, size: 18),
      ),
    );
  }
}

class ToolResultDownloadCard extends StatelessWidget {
  final AppColorScheme s;
  final String base64Data;
  final String filename;
  final String mimeType;

  const ToolResultDownloadCard({
    super.key,
    required this.s,
    required this.base64Data,
    required this.filename,
    required this.mimeType,
  });

  String get _icon {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.docx')) return 'doc';
    if (lower.endsWith('.xlsx')) return 'table';
    if (lower.endsWith('.pptx')) return 'stacks';
    if (lower.endsWith('.zip')) return 'folder_upload';
    return 'doc';
  }

  String get _label {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'Documento PDF';
    if (lower.endsWith('.docx')) return 'Documento Word';
    if (lower.endsWith('.xlsx')) return 'Folha de cálculo';
    if (lower.endsWith('.pptx')) return 'Apresentação';
    if (lower.endsWith('.zip')) return 'Projeto ZIP';
    return 'Documento';
  }

  Future<void> _download(BuildContext context) async {
    try {
      final bytes = base64Decode(base64Data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao preparar download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _download(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: s.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcon(_icon, size: 22, color: s.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                  const SizedBox(height: 2),
                  Text(_label, style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIcon('download', size: 20, color: s.primary),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CARROSSEL DE IMAGENS DE PESQUISA
// ──────────────────────────────────────────────────────────────

class ImageSearchCarousel extends StatefulWidget {
  final AppColorScheme s;
  final List<Map<String, dynamic>> images;
  const ImageSearchCarousel({super.key, required this.s, required this.images});

  @override
  State<ImageSearchCarousel> createState() => _ImageSearchCarouselState();
}

class _ImageSearchCarouselState extends State<ImageSearchCarousel> {
  final Set<String> _failedUrls = {};

  void _markFailed(String url) {
    if (_failedUrls.contains(url)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failedUrls.add(url));
    });
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    final visibleImages = widget.images.where((img) {
      final url = img['imageUrl']?.toString() ?? '';
      return url.isNotEmpty && !_failedUrls.contains(url);
    }).toList();

    if (visibleImages.isEmpty) return;

    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => _ImageSearchFullscreenScreen(
          images: visibleImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleImages = widget.images.where((img) {
      final url = img['imageUrl']?.toString() ?? '';
      return url.isNotEmpty && !_failedUrls.contains(url);
    }).toList();

    if (visibleImages.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: visibleImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final img = visibleImages[i];
            final url = img['imageUrl']?.toString() ?? '';
            return GestureDetector(
              key: ValueKey(url),
              onTap: () => _openFullscreen(context, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  url,
                  key: ValueKey(url),
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: child,
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    _markFailed(url);
                    return const SizedBox(width: 160, height: 160);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageSearchFullscreenScreen extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  const _ImageSearchFullscreenScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageSearchFullscreenScreen> createState() => _ImageSearchFullscreenScreenState();
}

class _ImageSearchFullscreenScreenState extends State<_ImageSearchFullscreenScreen> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final currentTitle = widget.images[_current]['title']?.toString() ?? '${_current + 1}/${widget.images.length}';

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageCtrl,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) {
                    final url = widget.images[i]['imageUrl']?.toString() ?? '';
                    return Center(
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            RoundedSymbols.imageNotSupported,
                            color: s.onSurfaceVariant,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        s.pageBackground,
                        s.pageBackground.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      _CircularBackButton(
                        s: s,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// FONTES (web_search)
// ──────────────────────────────────────────────────────────────

class SourcesRow extends StatelessWidget {
  final AppColorScheme s;
  final List<String> urls;
  const SourcesRow({super.key, required this.s, required this.urls});

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String _faviconUrl(String url) => 'https://www.google.com/s2/favicons?sz=64&domain=${_domain(url)}';

  void _openSourcesModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: s.cardBackground,
      barrierColor: Colors.black.withOpacity(0.35),
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _SourcesModalContent(s: s, urls: urls),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _openSourcesModal(context),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: s.outline.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              width: 18.0 + (urls.length - 1).clamp(0, 3) * 11.0,
              child: Stack(
                children: [
                  for (int i = 0; i < urls.length.clamp(0, 4); i++)
                    Positioned(
                      left: i * 11.0,
                      child: ClipOval(
                        child: Container(
                          width: 18,
                          height: 18,
                          color: s.pageBackground,
                          child: Image.network(
                            _faviconUrl(urls[i]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => AppIcon('globe', size: 10, color: s.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('Fontes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: s.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SourcesModalContent extends StatelessWidget {
  final AppColorScheme s;
  final List<String> urls;
  const _SourcesModalContent({required this.s, required this.urls});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: s.onSurfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Fontes',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: s.onSurface)),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: urls.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Divider(
                      height: 1,
                      thickness: 0.6,
                      color: s.outline.withOpacity(0.3),
                    ),
                  ),
                  itemBuilder: (_, i) {
                    final url = urls[i];
                    return _SourceModalRow(s: s, url: url);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SourceModalRow extends StatelessWidget {
  final AppColorScheme s;
  final String url;
  const _SourceModalRow({required this.s, required this.url});

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String _faviconUrl(String url) => 'https://www.google.com/s2/favicons?sz=64&domain=${_domain(url)}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showOpenLinkDialog(context, s, url: url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: Container(
                width: 28,
                height: 28,
                color: s.hover,
                child: Image.network(
                  _faviconUrl(url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => AppIcon('globe', size: 14, color: s.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_domain(url), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                  Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// BOLHA DO ASSISTENTE
// ──────────────────────────────────────────────────────────────

class AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  final List<LocalCanvasItem> canvases;
  final List<ResponseSegment> segments;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  const AssistantBubble({
    super.key,
    required this.s,
    required this.text,
    this.thinking,
    required this.canvases,
    this.segments = const [],
    required this.onOpenCanvas,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (thinking != null && thinking!.isNotEmpty) {
      children.add(_ThinkingHistoryCollapsible(s: s, thinking: thinking!));
    }

    for (final v in extractVisualResults(text)) {
      children.add(ToolResultImageCard(s: s, base64Png: v.base64Png, label: v.label));
    }
    for (final d in extractDocumentResults(text)) {
      children.add(ToolResultDownloadCard(s: s, base64Data: d.base64Data, filename: d.filename, mimeType: d.mimeType));
    }

    if (segments.isNotEmpty) {
      for (final seg in segments) {
        switch (seg) {
          case TextSegment(:final text):
            if (text.trim().isNotEmpty) {
              children.add(RichAiText(
                text: text,
                s: s,
                widgetsEnabled: widgetsEnabled,
                onEnableWidgets: onEnableWidgets,
                onSuggestionTap: onSuggestionTap,
                bodyTextStyle: aiBodyTextStyle(s),
              ));
            }
          case ProcessSegment(:final steps):
            if (steps.isNotEmpty) {
              children.add(ProcessCollapsible(s: s, steps: steps, isActive: false, startExpanded: false));
            }
          case ImagesSegment(:final images):
            if (images.isNotEmpty) {
              children.add(ImageSearchCarousel(s: s, images: images));
            }
        }
      }
    } else if (text.isNotEmpty) {
      children.add(RichAiText(
        text: text
            .replaceAll(kVisualResultRe, '')
            .replaceAll(kDocumentResultRe, '')
            .replaceAll(kSourcesRe, '')
            .replaceAll(kImagesRe, '')
            .trim(),
        s: s,
        widgetsEnabled: widgetsEnabled,
        onEnableWidgets: onEnableWidgets,
        onSuggestionTap: onSuggestionTap,
        bodyTextStyle: aiBodyTextStyle(s),
      ));
    }

    for (final item in canvases) {
      children.add(const SizedBox(height: 8));
      children.add(SimpleCanvasCard(s: s, item: item, onTap: () => onOpenCanvas(item)));
    }

    children.add(const SizedBox(height: 6));
    final aggregatedSources = allSourceUrlsFromSegments(segments);
    children.add(_AssistantActionBar(
      s: s,
      onThumbUp: onThumbUp,
      onThumbDown: onThumbDown,
      onCopy: onCopy,
      onRefresh: onRefresh,
      sources: aggregatedSources.isNotEmpty ? aggregatedSources : extractSources(text),
    ));

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ThinkingHistoryCollapsible extends StatelessWidget {
  final AppColorScheme s;
  final String thinking;
  const _ThinkingHistoryCollapsible({
    required this.s,
    required this.thinking,
  });

  @override
  Widget build(BuildContext context) {
    return ThinkingCollapsible(
      s: s,
      thinking: thinking,
      isActive: false,
      startExpanded: false,
    );
  }
}

class _AssistantActionBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final List<String> sources;
  const _AssistantActionBar({
    required this.s,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
    this.sources = const [],
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _AssistantActionIcon(s: s, assetName: 'thumbs_up', onTap: onThumbUp),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'thumbs_down', onTap: onThumbDown),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'copy', onTap: onCopy),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'refresh', onTap: onRefresh),
          if (sources.isNotEmpty) ...[
            const Spacer(),
            SourcesRow(s: s, urls: sources),
          ],
        ],
      );
}

class _AssistantActionIcon extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  const _AssistantActionIcon({
    required this.s,
    required this.assetName,
    required this.onTap,
  });
  @override
  State<_AssistantActionIcon> createState() => _AssistantActionIconState();
}

class _AssistantActionIconState extends State<_AssistantActionIcon> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          widget.assetName,
          color: s.onSurfaceVariant,
          size: 16,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// BOLHA DE STREAMING
// ──────────────────────────────────────────────────────────────

class StreamingBubble extends StatefulWidget {
  final AppColorScheme s;
  final List<ResponseSegment> segments;
  final List<StreamElement> elements;
  final String? thinking;
  final bool isThinkingActive;
  final bool showLogoLoader;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final ValueNotifier<String> openCanvasContentNotifier;
  final ValueNotifier<bool> openCanvasDoneNotifier;
  final LocalCanvasItem? Function() openCanvasFinalItem;
  final ValueNotifier<String> openWidgetContentNotifier;
  final ValueNotifier<bool> openWidgetDoneNotifier;
  const StreamingBubble({
    super.key,
    required this.s,
    this.segments = const [],
    required this.elements,
    this.thinking,
    this.isThinkingActive = false,
    this.showLogoLoader = false,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
    required this.onOpenCanvas,
    required this.openCanvasContentNotifier,
    required this.openCanvasDoneNotifier,
    required this.openCanvasFinalItem,
    required this.openWidgetContentNotifier,
    required this.openWidgetDoneNotifier,
  });

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final thinking = widget.thinking;
    final children = <Widget>[];

    if (thinking != null && thinking.isNotEmpty) {
      children.add(ThinkingCollapsible(
        s: s,
        thinking: thinking,
        isActive: widget.isThinkingActive,
        startExpanded: true,
      ));
    }

    for (final seg in widget.segments) {
      switch (seg) {
        case TextSegment(:final text):
          if (text.trim().isNotEmpty) {
            children.add(RichAiText(
              text: text,
              s: s,
              widgetsEnabled: widget.widgetsEnabled,
              onEnableWidgets: widget.onEnableWidgets,
              onSuggestionTap: widget.onSuggestionTap,
              bodyTextStyle: aiBodyTextStyle(s),
            ));
          }
        case ProcessSegment(:final steps):
          if (steps.isNotEmpty) {
            children.add(ProcessCollapsible(
              s: s,
              steps: steps,
              isActive: steps.any((step) => !step.done),
              startExpanded: true,
            ));
          }
        case ImagesSegment(:final images):
          if (images.isNotEmpty) {
            children.add(ImageSearchCarousel(s: s, images: images));
          }
      }
    }

    bool anyContent = widget.segments.isNotEmpty;
    for (final el in widget.elements) {
      switch (el) {
        case StreamText(:final text):
          final cleaned = cleanAiText(text);
          if (cleaned.trim().isEmpty) continue;
          anyContent = true;
          children.add(
            RichAiText(
              text: cleaned,
              s: s,
              widgetsEnabled: widget.widgetsEnabled,
              onEnableWidgets: widget.onEnableWidgets,
              onSuggestionTap: widget.onSuggestionTap,
              bodyTextStyle: aiBodyTextStyle(s),
            ),
          );
        case StreamCanvasBlock(:final label, :final item):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CanvasProgressCard(
              s: s,
              title: label,
              item: item,
              contentNotifier: widget.openCanvasContentNotifier,
              doneNotifier: widget.openCanvasDoneNotifier,
              finalItem: widget.openCanvasFinalItem,
              onOpenCanvas: widget.onOpenCanvas,
            ),
          ));
        case StreamWidgetBlock(:final label, :final block):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: WidgetProgressCard(
              s: s,
              label: label,
              block: block,
              contentNotifier: widget.openWidgetContentNotifier,
              doneNotifier: widget.openWidgetDoneNotifier,
            ),
          ));
        case StreamVisualResult(:final base64Png, :final label):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('visual_${base64Png.hashCode}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolResultImageCard(
                key: ValueKey('tool_image_${base64Png.hashCode}'),
                s: s,
                base64Png: base64Png,
                label: label,
              ),
            ),
          );
        case StreamDocumentResult(:final base64Data, :final filename, :final mimeType):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('doc_${base64Data.hashCode}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolResultDownloadCard(
                key: ValueKey('download_${base64Data.hashCode}'),
                s: s,
                base64Data: base64Data,
                filename: filename,
                mimeType: mimeType,
              ),
            ),
          );
        case StreamImagesResult(:final images):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('images_${images.map((e) => e['imageUrl']?.toString() ?? '').join('|')}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ImageSearchCarousel(s: s, images: images),
            ),
          );
        case StreamGenericOpenBlock(:final label):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: StreamingMarkdownCard(s: s, label: label),
          ));
      }
    }

    if (!anyContent && thinking == null) {
      children.add(widget.showLogoLoader
          ? const NexaLottieLoader(size: 28)
          : AiSmallDotsLoader(color: s.onSurfaceVariant));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PENSAMENTO
// ══════════════════════════════════════════════════════════════

class ThinkingCollapsible extends StatefulWidget {
  final AppColorScheme s;
  final String thinking;
  final bool isActive;
  final bool startExpanded;

  const ThinkingCollapsible({
    super.key,
    required this.s,
    required this.thinking,
    required this.isActive,
    this.startExpanded = true,
  });

  @override
  State<ThinkingCollapsible> createState() => _ThinkingCollapsibleState();
}

class _ThinkingCollapsibleState extends State<ThinkingCollapsible> {
  late bool _expanded = widget.startExpanded;
  bool _userOverrode = false;
  bool _wasActive = true;

  @override
  void didUpdateWidget(covariant ThinkingCollapsible old) {
    super.didUpdateWidget(old);
    if (_wasActive && !widget.isActive && !_userOverrode) {
      _expanded = false;
    }
    _wasActive = widget.isActive;
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _userOverrode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                widget.isActive
                    ? ShimmerText(
                        text: 'Pensamento',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
                        active: true,
                      )
                    : Text(
                        'Pensamento',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
                      ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AppIcon('chevron_down', size: 14, color: s.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeInCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.thinking,
                style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant, height: 1.4),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// ESTADOS ESPECIAIS DA LISTA
// ──────────────────────────────────────────────────────────────

class IncognitoState extends StatelessWidget {
  const IncognitoState({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Center(
      child: AppIcon(
        'incognito',
        color: s.onSurface,
        size: 72,
      ),
    );
  }
}

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'O DeepSeek é uma IA e pode cometer erros.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10.5,
            color: s.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO DE DESCER — agora um CÍRCULO PERFEITO (44x44), sem mais
// forma de cápsula. A posição (canto direito, acima do input bar)
// é controlada pelo Positioned no aitab.dart; este widget só
// desenha o círculo em si e a animação de press.
// ══════════════════════════════════════════════════════════════

class ScrollToBottomButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const ScrollToBottomButton({super.key, required this.s, required this.onTap});
  @override
  State<ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<ScrollToBottomButton> {
  bool _p = false;

  static const double _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.isDark ? s.cardBackground : Colors.white,
            shape: BoxShape.circle,
            boxShadow: s.floatingShadow,
          ),
          child: AppIcon('arrow_down', color: s.onSurface, size: 18),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final AppColorScheme s;
  final double topPadding;
  const EmptyState({super.key, required this.s, required this.topPadding});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Logo com tema + shimmer ──────────────────
                // Antes: SvgPicture.asset direto sem colorFilter,
                // por isso ficava sempre com o fill="#000000"
                // original do arquivo, preto em qualquer tema.
                // Agora usa o mesmo padrão de colorFilter que
                // AppIcon/NexaBrandLogo já usam nos outros ícones
                // (branco no escuro, preto no claro), injetado via
                // ShaderMask por cima do colorFilter — não altera
                // o ficheiro logo.svg em si.
                ShimmeringThemedLogo(s: s, size: 112),
                const SizedBox(height: 14),
                Text(
                  greetingForNow(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: s.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// LOGO COM TEMA + SHIMMER
// Recolore o logo.svg via colorFilter (branco no escuro, preto no
// claro — igual à lógica de AppIcon para todos os outros ícones do
// app) e sobrepõe um brilho contínuo com ShaderMask. Nenhum
// ficheiro .svg é tocado; a cor é 100% injetada em runtime.
// ══════════════════════════════════════════════════════════════

class ShimmeringThemedLogo extends StatefulWidget {
  final AppColorScheme s;
  final double size;
  const ShimmeringThemedLogo({super.key, required this.s, this.size = 112});

  @override
  State<ShimmeringThemedLogo> createState() => _ShimmeringThemedLogoState();
}

class _ShimmeringThemedLogoState extends State<ShimmeringThemedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final themeColor = s.isDark ? Colors.white : Colors.black;

    // 1ª camada: o SVG recolorido pelo tema (mesma técnica que
    // AppIcon usa nos outros ícones — colorFilter com BlendMode.srcIn
    // sobrescreve qualquer fill="#..." definido dentro do arquivo).
    final themedLogo = SvgPicture.asset(
      'assets/images/logo.svg',
      width: widget.size,
      height: widget.size,
      colorFilter: ColorFilter.mode(themeColor, BlendMode.srcIn),
    );

    // 2ª camada: ShaderMask com gradiente deslizante por cima —
    // dá o efeito de brilho passando pelo logo, em loop contínuo.
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final shift = (_c.value * 2 - 1) * bounds.width * 1.5;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                themeColor.withOpacity(0.0),
                themeColor.withOpacity(0.0),
                (s.isDark ? Colors.white : Colors.black87).withOpacity(0.55),
                themeColor.withOpacity(0.0),
                themeColor.withOpacity(0.0),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds.shift(Offset(shift, 0)));
          },
          child: themedLogo,
        );
      },
    );
  }
}