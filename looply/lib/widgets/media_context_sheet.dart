import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../theme.dart';
import 'phosphor_svg_icon.dart';

enum MediaSheetKind { image, video, link }

enum MediaSheetAction { openNewTab, preview, copyLink, download, bookmarkLink, shareLink }

class MediaSheetOption {
  const MediaSheetOption({
    required this.action,
    required this.label,
    required this.icon,
  });

  final MediaSheetAction action;
  final String label;
  final IconData icon;
}

Future<MediaSheetAction?> showMediaContextSheet({
  required BuildContext context,
  required MediaSheetKind kind,
  required String url,
  Uint8List? faviconBytes,
  required List<MediaSheetOption> options,
}) {
  final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<MediaSheetAction>(
    context: context,
    backgroundColor: scheme.surfaceContainerLow,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _MediaSheetBody(
      kind: kind,
      url: url,
      previewImageUrl: previewImageUrl,
      faviconBytes: faviconBytes,
      options: options,
    ),
  );
}

class _MediaSheetBody extends StatelessWidget {
  const _MediaSheetBody({
    required this.kind,
    required this.url,
    required this.faviconBytes,
    required this.options,
  });

  final MediaSheetKind kind;
  final String url;
  final Uint8List? faviconBytes;
  final List<MediaSheetOption> options;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final host = Uri.tryParse(url)?.host ?? url;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPreview(scheme),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: scheme.surfaceContainerHighest.withOpacity(.55),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 56,
                        color: scheme.outlineVariant.withOpacity(.35),
                      ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(options[i].action),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        child: Row(
                          children: [
                            PhosphorSvgIcon(options[i].icon, size: 21, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                options[i].label,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme scheme) {
    final height = kind == MediaSheetKind.link ? 100.0 : 150.0;
    Widget content;
    if (kind == MediaSheetKind.link) {
      content = Center(
        child: ClipOval(
          child: SizedBox(
            width: 56,
            height: 56,
            child: faviconBytes != null
                ? Image.memory(faviconBytes!, fit: BoxFit.cover)
                : ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: PhosphorSvgIcon(PhosphorIcons.link, size: 26, color: scheme.onSurfaceVariant),
                    ),
                  ),
          ),
        ),
      );
    } else {
      final image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: kind == MediaSheetKind.image
              ? PhosphorSvgIcon(PhosphorIcons.image, size: 36, color: scheme.onSurfaceVariant)
              : Icon(Icons.play_circle_outline, size: 36, color: scheme.onSurfaceVariant),
        ),
      );
      content = kind == MediaSheetKind.video
          ? Stack(
              fit: StackFit.expand,
              children: [
                image,
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(.45), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ],
            )
          : image;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ColoredBox(color: scheme.surfaceContainerHighest.withOpacity(.4), child: content),
      ),
    );
  }
}

class PagePreviewModal extends StatelessWidget {
  const PagePreviewModal({super.key, required this.url, required this.onOpenInNewTab});

  final String url;
  final VoidCallback onOpenInNewTab;

  static Future<void> show({
    required BuildContext context,
    required String url,
    required VoidCallback onOpenInNewTab,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PagePreviewModal(url: url, onOpenInNewTab: onOpenInNewTab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          Uri.tryParse(url)?.host ?? url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: PhosphorSvgIcon(PhosphorIcons.x, color: scheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Abrir num novo separador',
            icon: PhosphorSvgIcon(PhosphorIcons.arrowUpLeft, color: scheme.onSurface),
            onPressed: () {
              Navigator.of(context).pop();
              onOpenInNewTab();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useHybridComposition: true,
          supportZoom: true,
          builtInZoomControls: true,
          displayZoomControls: false,
        ),
      ),
    );
  }
}
