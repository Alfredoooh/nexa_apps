// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/slides_app.dart
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';
import '../sheets/sheets_screen.dart';
import '../../../widgets/app_sheet.dart';
import '../../../services/auth_service.dart';
import '../../../services/export_service.dart';
import '../app_types.dart';


const Set<String> _kEditorSvgIcons = {
  'align_center',
  'align_left',
  'align_right',
  'bold',
  'brush',
  'bullet_point',
  'capital_letter',
  'chart',
  'edit_text',
  'eraser',
  'font',
  'font-2',
  'font_size',
  'hyperlink',
  'image',
  'indent_decrease',
  'indent_increase',
  'justify',
  'paste',
  'pencil_holder',
  'quote',
  'resize',
  'spacing_height',
  'spacing_width',
  'spellcheck',
  'subscript',
  'superscript',
  'text_color',
  'underline',
  'download',
  'share',
  'pdf',
  'check',
  'plus',
  'minus',
  'trash',
  'grid',
  'row',
  'column',
  'wand',
  'add',
};

const Map<String, String> _kEditorIconAliases = {
  'align_justify': 'justify',
  'bullet': 'bullet_point',
  'link': 'hyperlink',
  'palette': 'text_color',
  'highlight': 'brush',
  'text': 'edit_text',
};

class _EditorIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  const _EditorIcon(this.asset, {required this.size, required this.color});

  @override
  Widget build(BuildContext context) => AppIcon(asset, size: size, color: color);
}

// ══════════════════════════════════════════════════════════════
// POPUP CUSTOMIZADO — Container Transform, igual ao docs.dart
// ══════════════════════════════════════════════════════════════

Future<T?> _showMorphMenu<T>(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required List<_MorphMenuItem<T>> items,
  double width = 240,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final anchorSize = box.size;
  final screenSize = overlay.size;

  final anchorRect = Rect.fromLTWH(
    anchorTopLeft.dx,
    anchorTopLeft.dy,
    anchorSize.width,
    anchorSize.height,
  );

  double left = anchorRect.right - width;
  if (left < 12) left = 12;
  if (left + width > screenSize.width - 12) left = screenSize.width - 12 - width;
  double top = anchorRect.bottom + 8;

  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withOpacity(0.001),
    barrierDismissible: true,
    transitionDuration: const Duration(milliseconds: 480),
    pageBuilder: (ctx, anim, secAnim) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
      return Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: BackdropBlurBox(sigma: 6 * curved.value, color: s.barrier.withOpacity(0.18 * curved.value)),
              ),
            ),
          ),
          Positioned(
            left: Tween<double>(begin: anchorRect.left, end: left).transform(curved.value),
            top: Tween<double>(begin: anchorRect.top, end: top).transform(curved.value),
            width: Tween<double>(begin: anchorRect.width, end: width).transform(curved.value),
            child: Opacity(
              opacity: Curves.easeOut.transform(anim.value.clamp(0.0, 1.0)),
              child: Transform.scale(
                alignment: Alignment.topRight,
                scale: 0.86 + (0.14 * curved.value),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: s.floatingSurface.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: s.outline.withOpacity(0.14), width: 1),
                      boxShadow: s.floatingShadow,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          _MorphMenuTile<T>(
                            item: items[i],
                            s: s,
                            onSelected: (v) => Navigator.of(ctx).pop(v),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MorphMenuItem<T> {
  final T value;
  final String asset;
  final String label;
  final bool destructive;
  const _MorphMenuItem({
    required this.value,
    required this.asset,
    required this.label,
    this.destructive = false,
  });
}

class _MorphMenuTile<T> extends StatefulWidget {
  final _MorphMenuItem<T> item;
  final AppColorScheme s;
  final void Function(T) onSelected;
  const _MorphMenuTile({required this.item, required this.s, required this.onSelected});

  @override
  State<_MorphMenuTile<T>> createState() => _MorphMenuTileState<T>();
}

class _MorphMenuTileState<T> extends State<_MorphMenuTile<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final item = widget.item;
    final color = item.destructive ? s.error : s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => widget.onSelected(item.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _EditorIcon(item.asset, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackdropBlurBox extends StatelessWidget {
  final double sigma;
  final Color color;
  const BackdropBlurBox({super.key, required this.sigma, required this.color});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color);
  }
}

class SlidesScreen extends StatefulWidget {
  const SlidesScreen({super.key});
  @override State<SlidesScreen> createState() => _SlidesScreenState();
}

class _SlidesScreenState extends State<SlidesScreen> with ThemeReactive<SlidesScreen> {
  static const EditorType _type = EditorType.slides;
  InAppWebViewController? _ctrl;

  String _documentTitle = 'Apresentação';
  String? _lastSavedContent;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _restoringContent = false;

  bool _readyForWebView = false;

  final GlobalKey _moreMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
    appTheme.addListener(_pushPrimaryColorToWebView);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPendingLoad());
    WidgetsBinding.instance.addPostFrameCallback((_) => _armRouteListener());
  }

  void _armRouteListener() {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null) {
      if (mounted) setState(() => _readyForWebView = true);
      return;
    }
    if (animation.isCompleted) {
      setState(() => _readyForWebView = true);
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        if (mounted) setState(() => _readyForWebView = true);
      }
    }
    animation.addStatusListener(listener);
  }

  @override
  void dispose() {
    editTabController.removeListener(_onPendingLoad);
    appTheme.removeListener(_pushPrimaryColorToWebView);
    try { _ctrl?.dispose(); } catch (_) {}
    super.dispose();
  }

  void _onPendingLoad() {
    final pending = editTabController.pendingLocalLoad;
    if (pending == null || pending.kind.editorType != _type) return;
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _documentTitle = pending.title;
    _injectCanvas(ctrl, pending.content);
    _resetHistory(pending.content);
    editTabController.consumePendingLocalLoad();
    if (mounted) setState(() {});
  }

  void _injectCanvas(InAppWebViewController ctrl, String content) {
    final escaped = content.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    ctrl.evaluateJavascript(source: "editorApi.setContentFromAi('$escaped')");
  }

  void _resetHistory(String content) {
    _undoStack.clear();
    _redoStack.clear();
    _lastSavedContent = content;
    _restoringContent = false;
  }

  void _runJs(String script) => _ctrl?.evaluateJavascript(source: script);

  void _pushPrimaryColorToWebView() {
    final s = AppTheme.of(context);
    _runJs("editorApi.setPrimaryColor('${s.primaryColorHex}')");
  }

  void _onSaveDocument(String json) {
    if (_restoringContent) return;
    if (_lastSavedContent != null && _lastSavedContent == json) return;
    setState(() {
      if (_lastSavedContent != null) {
        _undoStack.add(_lastSavedContent!);
        if (_undoStack.length > 50) _undoStack.removeAt(0);
      }
      _redoStack.clear();
      _lastSavedContent = json;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_lastSavedContent ?? '{}');
      final previous = _undoStack.removeLast();
      _lastSavedContent = previous;
      _restoringContent = true;
      final escaped = previous.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _runJs("editorApi.setContent('$escaped')");
      Future.delayed(const Duration(milliseconds: 50), () => _restoringContent = false);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_lastSavedContent ?? '{}');
      final next = _redoStack.removeLast();
      _lastSavedContent = next;
      _restoringContent = true;
      final escaped = next.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
      _runJs("editorApi.setContent('$escaped')");
      Future.delayed(const Duration(milliseconds: 50), () => _restoringContent = false);
    });
  }

  void _openColorPicker(BuildContext context, AppColorScheme s, String cb) async {
    final hex = await showColorPickerSheet(context, s);
    if (hex != null) _runJs("$cb('$hex')");
  }

  Future<String> _getCurrentContent() async {
    final ctrl = _ctrl;
    if (ctrl == null) return '';
    try {
      final result = await ctrl.callAsyncJavaScript(functionBody: 'return editorApi.getContent();');
      return result?.value?.toString() ?? '';
    } catch (_) { return ''; }
  }

  void _setCurrentContent(String content) {
    final ctrl = _ctrl;
    if (ctrl != null) _injectCanvas(ctrl, content);
  }

  Future<void> _downloadCurrentDocument() async {
    final content = await _getCurrentContent();
    if (content.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o conteúdo atual.')),
      );
      return;
    }
    try {
      final item = LocalCanvasItem(
        id: 'export-pptx',
        kind: LocalCanvasKind.slide,
        title: _documentTitle,
        content: content,
      );
      final bytes = await ExportService.export(item: item, format: 'pptx');
      final safeTitle = _documentTitle.trim().isEmpty
          ? 'documento'
          : _documentTitle.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
      await ExportService.shareBytes(bytes, filename: '$safeTitle.pptx');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível descarregar apresentação PowerPoint: ${e.toString()}')),
      );
    }
  }

  void _onInsertImage() async {
    final url = await showImageUrlDialog(context, AppTheme.of(context));
    if (url == null || url.trim().isEmpty) return;
    _runJs("editorApi.insertImage('$url')");
  }

  void _onInsertShape(String shapeKind) {
    showColorPickerSheet(context, AppTheme.of(context)).then((hex) {
      if (hex != null) _runJs("editorApi.insertShape('$shapeKind','$hex')");
    });
  }

  void _onInsertChart() {
    showChartConfigDialog(context, AppTheme.of(context)).then((json) {
      if (json != null && json.trim().isNotEmpty) {
        final safe = json.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
        _runJs("editorApi.insertChart(JSON.parse('$safe'))");
      }
    });
  }

  // Menu "more" — popup morph igual ao docs.dart. Apenas ações que
  // NÃO existem no bottomtoolbar (que já tem: slide, apagar slide,
  // texto, imagem, forma, círculo, gráfico, apagar elemento,
  // negrito, itálico, sublinhado, cor de texto, cor de forma).
  void _openMenu() async {
    final s = AppTheme.of(context);
    final result = await _showMorphMenu<int>(
      context,
      s,
      anchorKey: _moreMenuKey,
      items: const [
        _MorphMenuItem(value: 1, asset: 'download', label: 'Descarregar documento'),
      ],
    );
    if (result == 1) _downloadCurrentDocument();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.only(top: 58, bottom: 44),
                child: (kIsWeb || !_readyForWebView)
                    ? const SizedBox.shrink()
                    : InAppWebView(
                        initialFile: _type.htmlAsset,
                        initialSettings: InAppWebViewSettings(
                          transparentBackground: true,
                          javaScriptEnabled: true,
                          allowFileAccessFromFileURLs: true,
                          allowUniversalAccessFromFileURLs: true,
                          useHybridComposition: true,
                          verticalScrollBarEnabled: false,
                          horizontalScrollBarEnabled: false,
                          supportZoom: false,
                        ),
                        onWebViewCreated: (c) {
                          _ctrl = c;
                          c.addJavaScriptHandler(
                            handlerName: 'openColorPicker',
                            callback: (args) {
                              final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setSelectedTextColor';
                              _openColorPicker(context, s, cb);
                            },
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'saveDocument',
                            callback: (args) {
                              final content = args.isNotEmpty ? args[0]?.toString() : null;
                              if (content != null) _onSaveDocument(content);
                            },
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'onElementSelected',
                            callback: (args) {},
                          );
                          c.addJavaScriptHandler(
                            handlerName: 'openImagePicker',
                            callback: (_) => showImagePickerSheet(context, s),
                          );
                        },
                        onLoadStop: (c, _) {
                          _onPendingLoad();
                          c.evaluateJavascript(source: "editorApi.setThemeMode('${s.isDark ? 'dark' : 'light'}')");
                          c.evaluateJavascript(source: "editorApi.setPrimaryColor('${s.primaryColorHex}')");
                        },
                      ),
              ),
              _ScreenHeader(
                s: s,
                title: _documentTitle,
                onUndo: _undo,
                onRedo: _redo,
                onMenu: _openMenu,
                menuKey: _moreMenuKey,
              ),
              _SlidesBottomToolbar(
                s: s,
                onAddSlide: () => _runJs("editorApi.addSlide()"),
                onDeleteSlide: () => _runJs("editorApi.deleteCurrentSlide()"),
                onInsertText: () => _runJs("editorApi.insertTextBox()"),
                onInsertImage: _onInsertImage,
                onInsertShape: () => _onInsertShape('rect'),
                onInsertCircle: () => _onInsertShape('circle'),
                onInsertChart: _onInsertChart,
                onDeleteElement: () => _runJs("editorApi.deleteSelectedElement()"),
                onBold: () => _runJs("editorApi.applyTextFormat('bold')"),
                onItalic: () => _runJs("editorApi.applyTextFormat('italic')"),
                onUnderline: () => _runJs("editorApi.applyTextFormat('underline')"),
                onTextColor: () => _openColorPicker(context, s, 'editorApi.setSelectedTextColor'),
                onShapeColor: () => _openColorPicker(context, s, 'editorApi.setSelectedShapeColor'),
                onFontSize: (px) => _runJs("editorApi.setSelectedFontSize($px)"),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onMenu;
  final GlobalKey menuKey;
  const _ScreenHeader({
    required this.s,
    required this.title,
    required this.onUndo,
    required this.onRedo,
    required this.onMenu,
    required this.menuKey,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)],
          ),
        ),
        child: Row(children: [
          ScreenBackButton(s: s),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: s.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo, withContainer: false),
          _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo, withContainer: false),
          const SizedBox(width: 8),
          _HeaderIconButton(s: s, assetName: 'more_vert', onTap: onMenu, anchorKey: menuKey),
        ]),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  final GlobalKey? anchorKey;
  final bool withContainer;
  const _HeaderIconButton({
    required this.s,
    required this.assetName,
    required this.onTap,
    this.anchorKey,
    this.withContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: withContainer
            ? BoxDecoration(color: s.cardBackground, shape: BoxShape.circle, boxShadow: s.cardShadow)
            : null,
        child: _EditorIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

class _SlidesBottomToolbar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onAddSlide;
  final VoidCallback onDeleteSlide;
  final VoidCallback onInsertText;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertShape;
  final VoidCallback onInsertCircle;
  final VoidCallback onInsertChart;
  final VoidCallback onDeleteElement;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onTextColor;
  final VoidCallback onShapeColor;
  final ValueChanged<double> onFontSize;

  const _SlidesBottomToolbar({
    required this.s,
    required this.onAddSlide,
    required this.onDeleteSlide,
    required this.onInsertText,
    required this.onInsertImage,
    required this.onInsertShape,
    required this.onInsertCircle,
    required this.onInsertChart,
    required this.onDeleteElement,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onTextColor,
    required this.onShapeColor,
    required this.onFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12, right: 12, bottom: 16,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: s.floatingShadow,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ToolbarButton(s: s, assetName: 'add', onTap: onAddSlide),
              _ToolbarButton(s: s, assetName: 'trash', onTap: onDeleteSlide),
              _ToolbarButton(s: s, assetName: 'text', onTap: onInsertText),
              _ToolbarButton(s: s, assetName: 'image', onTap: onInsertImage),
              _ToolbarButton(s: s, assetName: 'rect', onTap: onInsertShape),
              _ToolbarButton(s: s, assetName: 'circle', onTap: onInsertCircle),
              _ToolbarButton(s: s, assetName: 'chart', onTap: onInsertChart),
              _ToolbarButton(s: s, assetName: 'trash_element', onTap: onDeleteElement),
              _ToolbarButton(s: s, assetName: 'bold', onTap: onBold),
              _ToolbarButton(s: s, assetName: 'italic', onTap: onItalic),
              _ToolbarButton(s: s, assetName: 'underline', onTap: onUnderline),
              _ToolbarButton(s: s, assetName: 'palette', onTap: onTextColor),
              _ToolbarButton(s: s, assetName: 'fill', onTap: onShapeColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  const _ToolbarButton({required this.s, required this.assetName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        child: _EditorIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

Future<String?> showImageUrlDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('URL da imagem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'https://')),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context, ctrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir', style: TextStyle(color: s.onPrimary)),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<String?> showChartConfigDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Configuração do gráfico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: '{"type":"bar",...}')),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context, ctrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir', style: TextStyle(color: s.onPrimary)),
            ),
          ),
        ],
      ),
    ),
  );
}

class ScreenBackButton extends StatefulWidget {
  final AppColorScheme s;
  const ScreenBackButton({super.key, required this.s});
  @override State<ScreenBackButton> createState() => _ScreenBackButtonState();
}

class _ScreenBackButtonState extends State<ScreenBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: widget.s.cardBackground, shape: BoxShape.circle),
          child: AppIcon('back.svg', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}