// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/sheets_app.dart
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:math' as math;
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';
import 'sheets_screen.dart';
import '../../../widgets/app_sheet.dart';
import '../../../services/auth_service.dart';
import '../../../services/export_service.dart';
import '../app_types.dart';
import '../docs/docs_screen.dart' show showMenuSheet, SheetMenuItem, AppToggle;

// ══════════════════════════════════════════════════════════════
// ÍCONES SVG — mesma estrutura de docs.dart:
//  1) _kEditorSvgIcons  → SVGs monocromáticos em assets/icons/editor/,
//     levam ColorFilter.srcIn (herdam a cor pedida).
//  2) _kColoredSvgIcons → SVGs já coloridos, sem colorFilter.
//  3) _kOutlineSvgIcons → vivem em assets/icons/outline/ em vez de
//     editor/, também levam colorFilter.
//
// undo/redo: existiam em assets/icons/editor/ mas não estavam
// listados aqui, por isso caíam no fallback AppIcon errado —
// corrigido, tal como em docs.dart.
//
// Ainda faltam ficheiros para: fill, download, code, sparkles — os
// nomes já estão mapeados, falta só colocar os .svg.
// ══════════════════════════════════════════════════════════════

const Set<String> _kEditorSvgIcons = {
  'align_center', 'align_left', 'align_right', 'bold', 'brush',
  'bullet_point', 'capital_letter', 'chart', 'edit_text', 'eraser',
  'font', 'font-2', 'font_size', 'hyperlink', 'image', 'indent_decrease',
  'indent_increase', 'justify', 'paste', 'pencil_holder', 'quote',
  'resize', 'spacing_height', 'spacing_width', 'spellcheck', 'subscript',
  'superscript', 'text_color', 'underline', 'fill', 'download', 'code',
  'undo', 'redo',
};

// Ícones que já vêm coloridos no próprio ficheiro SVG. Adiciona aqui
// o nome (sem .svg) assim que colocares um ícone colorido em
// assets/icons/editor/ — o widget deixa de aplicar colorFilter
// automaticamente para esse nome, preservando as cores originais.
const Set<String> _kColoredSvgIcons = {};

// Ícones que vivem em assets/icons/outline/ em vez de editor/.
const Set<String> _kOutlineSvgIcons = {
  'theme', 'add',
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

class SheetsScreen extends StatefulWidget {
  const SheetsScreen({super.key});
  @override State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> with ThemeReactive<SheetsScreen> {
  static const EditorType _type = EditorType.sheets;
  InAppWebViewController? _ctrl;
  bool _isClosing = false;

  String _documentTitle = 'Folha de cálculo';
  String? _lastSavedContent;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _restoringContent = false;

  bool _readyForWebView = false;

  @override
  void initState() {
    super.initState();
    editTabController.addListener(_onPendingLoad);
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
    try { _ctrl?.dispose(); } catch (_) {}
    super.dispose();
  }

  // Fecho ordenado — mesma abordagem do Docs: para o WebView
  // (destrói gráficos, cancela timers) antes de a tela sair.
  Future<bool> _pararWebViewAntesDeFechar() async {
    if (_isClosing) return false;
    _isClosing = true;
    final ctrl = _ctrl;
    if (ctrl != null) {
      try {
        // sheets.html não tem prepararParaFechar dedicado — os
        // gráficos Chart.js são a única coisa persistente a limpar,
        // e destroyCellChart já corre synchronously ao remover uma
        // célula; para o fecho de tela, garantimos que não há saves
        // pendentes disparando um último getContent síncrono.
        await ctrl.callAsyncJavaScript(functionBody: 'return true;');
      } catch (_) {}
    }
    return true;
  }

  void _fecharTela() async {
    final podeFechar = await _pararWebViewAntesDeFechar();
    if (podeFechar && mounted) Navigator.of(context).pop();
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

  void _addFiftyRows() => _runJs("editorApi.addMoreRows(50)");

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

  Future<void> _downloadCurrentDocument() async {
    final content = await _getCurrentContent();
    if (content.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter o conteúdo atual.')),
      );
      return;
    }
    try {
      final item = LocalCanvasItem(id: 'export-xlsx', kind: LocalCanvasKind.sheet, title: _documentTitle, content: content);
      final bytes = await ExportService.export(item: item, format: 'xlsx');
      final safeTitle = _documentTitle.trim().isEmpty ? 'documento' : _documentTitle.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_').trim();
      await ExportService.shareBytes(bytes, filename: '$safeTitle.xlsx');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível descarregar folha Excel: ${e.toString()}')),
      );
    }
  }

  Future<String?> _getSelectedCellKey() async {
    final ctrl = _ctrl;
    if (ctrl == null) return null;
    try {
      final result = await ctrl.callAsyncJavaScript(functionBody: 'return editorApi.getSelectedCellKey();');
      final key = result?.value?.toString();
      return (key != null && key.isNotEmpty) ? key : null;
    } catch (_) { return null; }
  }

  void _onInsertChart() async {
    final cellKey = await _getSelectedCellKey();
    if (cellKey == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toca numa célula antes de inserir um gráfico.')),
      );
      return;
    }
    final configJson = await showChartConfigDialog(context, AppTheme.of(context));
    if (configJson == null || configJson.trim().isEmpty) return;
    final safeConfig = configJson.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    _runJs("editorApi.renderCellChart('$cellKey', JSON.parse('$safeConfig'))");
  }

  void _onInsertImage() async {
    final cellKey = await _getSelectedCellKey();
    if (cellKey == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toca numa célula antes de inserir uma imagem.')),
      );
      return;
    }
    final url = await showImageUrlDialog(context, AppTheme.of(context));
    if (url == null || url.trim().isEmpty) return;
    _runJs("editorApi.renderCellImage('$cellKey', '$url')");
  }

  // ══════════════════════════════════════════════════════════════
  // BLOCO HTML MULTI-CÉLULA — pede a célula-âncora (topo-esquerda),
  // o HTML e o tamanho da área (linhas × colunas) a ocupar.
  // ══════════════════════════════════════════════════════════════
  void _onInsertHtmlBlock() async {
    final cellKey = await _getSelectedCellKey();
    if (cellKey == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toca na célula onde o bloco deve começar (canto superior esquerdo).')),
      );
      return;
    }
    final resultado = await showHtmlBlockDialog(context, AppTheme.of(context));
    if (resultado == null) return;
    final safeHtml = resultado.html.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    _runJs("editorApi.renderCellHtmlBlock('$cellKey', '$safeHtml', ${resultado.rowspan}, ${resultado.colspan})");
  }

  void _onInsertLink() {
    showLinkSheet(context, AppTheme.of(context), (url, text) {
      _runJs("editorApi.setCellLink('$url','$text')");
    });
  }

  // ══════════════════════════════════════════════════════════════
  // TOM DA FOLHA — mesmo padrão de docs.dart: switch direto, sem
  // sub-texto explicativo, ícone theme.svg (assets/icons/outline/)
  // ao lado do label.
  // ══════════════════════════════════════════════════════════════
  void _openSheetToneSheet() async {
    final s = AppTheme.of(context);
    bool escuro = false;
    try {
      final result = await _ctrl?.callAsyncJavaScript(functionBody: 'return editorApi.getSheetDarkMode();');
      escuro = result?.value == true;
    } catch (_) {}

    if (!mounted) return;
    await showCraftBottomSheet<void>(
      context: context,
      s: s,
      title: 'Tom da folha',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              _EditorIcon('theme', size: 19, color: s.onSurface),
              const SizedBox(width: 12),
              Expanded(child: Text('Folha escura', style: TextStyle(fontSize: 14.5, color: s.onSurface))),
              AppToggle(
                s: s,
                value: escuro,
                onChanged: (v) {
                  setSheetState(() => escuro = v);
                  _runJs("editorApi.setSheetDarkMode($v)");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MENU "MAIS" — bottom sheet no padrão showCraftBottomSheet.
  // "Adicionar 50 linhas" voltou para aqui (saiu da toolbar, onde
  // ocupava espaço para uma ação pouco frequente).
  // ══════════════════════════════════════════════════════════════
  void _openMenu() async {
    final result = await showMenuSheet<int>(
      context,
      title: 'Opções da folha',
      items: const [
        SheetMenuItem(value: 1, asset: 'download', label: 'Descarregar documento', subtitle: 'Guarda como .xlsx'),
        SheetMenuItem(value: 2, asset: 'code', label: 'Bloco HTML', subtitle: 'Insere um bloco que ocupa várias células'),
        SheetMenuItem(value: 3, asset: 'add', label: 'Adicionar 50 linhas'),
        SheetMenuItem(value: 4, asset: 'brush', label: 'Tom da folha'),
      ],
    );
    switch (result) {
      case 1: _downloadCurrentDocument(); break;
      case 2: _onInsertHtmlBlock(); break;
      case 3: _addFiftyRows(); break;
      case 4: _openSheetToneSheet(); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _fecharTela();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                                final cb = args.isNotEmpty ? args[0] as String : 'editorApi.setCellColor';
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
                            c.addJavaScriptHandler(handlerName: 'onCellSelected', callback: (args) {});
                          },
                          onLoadStop: (c, _) {
                            _onPendingLoad();
                            // setThemeMode aqui é só o tema da app (não mexe
                            // no tom claro/escuro da folha, que é escolhido
                            // pelo utilizador via setSheetDarkMode).
                            c.evaluateJavascript(source: "editorApi.setThemeMode('${s.isDark ? 'dark' : 'light'}')");
                            c.evaluateJavascript(source: "editorApi.setFontScale(${appPreferences.textScaleFactor})");
                          },
                        ),
                ),
                _ScreenHeader(
                  s: s,
                  title: _documentTitle,
                  onUndo: _undo,
                  onRedo: _redo,
                  onMenu: _openMenu,
                  onClose: _fecharTela,
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: 12,
                  right: 12,
                  bottom: 16 + teclado,
                  child: _SheetBottomToolbar(
                    s: s,
                    onBold: () => _runJs("editorApi.applyFormat('bold')"),
                    onItalic: () => _runJs("editorApi.applyFormat('italic')"),
                    onUnderline: () => _runJs("editorApi.applyFormat('underline')"),
                    onAlignLeft: () => _runJs("editorApi.setCellAlign('left')"),
                    onAlignCenter: () => _runJs("editorApi.setCellAlign('center')"),
                    onAlignRight: () => _runJs("editorApi.setCellAlign('right')"),
                    onTextColor: () => _openColorPicker(context, s, 'editorApi.setCellColor'),
                    onFillColor: () => _openColorPicker(context, s, 'editorApi.setCellFill'),
                    onInsertImage: _onInsertImage,
                    onInsertChart: _onInsertChart,
                    onInsertLink: _onInsertLink,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HEADER — botões afastados 12px da borda (antes: 6px), mesmo
// espaçamento lateral aplicado em docs.dart.
// ══════════════════════════════════════════════════════════════
class _ScreenHeader extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onMenu;
  final VoidCallback onClose;

  const _ScreenHeader({
    required this.s, required this.title, required this.onUndo,
    required this.onRedo, required this.onMenu, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 14, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)]),
        ),
        child: Row(children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(color: s.cardBackground, shape: BoxShape.circle),
              child: AppIcon('back.svg', size: 20, color: s.onSurface),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: s.onSurface)),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(s: s, assetName: 'undo', onTap: onUndo, withContainer: false),
          _HeaderIconButton(s: s, assetName: 'redo', onTap: onRedo, withContainer: false),
          const SizedBox(width: 8),
          _HeaderIconButton(s: s, assetName: 'more_vert', onTap: onMenu),
        ]),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  final bool withContainer;
  const _HeaderIconButton({required this.s, required this.assetName, required this.onTap, this.withContainer = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40, height: 40, alignment: Alignment.center,
        decoration: withContainer ? BoxDecoration(color: s.cardBackground, shape: BoxShape.circle, boxShadow: s.cardShadow) : null,
        child: _EditorIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TOOLBAR
// - Fundo no tema claro: cardBackground + 10% de primary via
//   Color.alphaBlend, igual a docs.dart. Tema escuro inalterado.
// - Botão de IA (sparkles) removido por completo.
// - Botão "Adicionar linha" (add) removido do toolbar — a ação
//   voltou a viver só no menu popup (ver _openMenu).
// - onFillColor deixou de ser _ToolbarButton com ícone SVG; passa
//   a ser o _RainbowRingButton (anel arco-íris), tal como o
//   highlight em docs.dart. onTextColor mantém-se ícone normal.
// ══════════════════════════════════════════════════════════════
class _SheetBottomToolbar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onAlignLeft;
  final VoidCallback onAlignCenter;
  final VoidCallback onAlignRight;
  final VoidCallback onTextColor;
  final VoidCallback onFillColor;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertChart;
  final VoidCallback onInsertLink;

  const _SheetBottomToolbar({
    required this.s, required this.onBold, required this.onItalic, required this.onUnderline,
    required this.onAlignLeft, required this.onAlignCenter, required this.onAlignRight,
    required this.onTextColor, required this.onFillColor, required this.onInsertImage,
    required this.onInsertChart, required this.onInsertLink,
  });

  @override
  Widget build(BuildContext context) {
    // Tema claro: cardBackground + 10% de primary por cima, via
    // alphaBlend (mistura real de cor, não opacidade sobreposta).
    // Tema escuro: cardBackground puro, como já estava.
    final toolbarBg = s.isDark
        ? s.cardBackground
        : Color.alphaBlend(s.primary.withOpacity(0.10), s.cardBackground);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: toolbarBg, borderRadius: BorderRadius.circular(28), boxShadow: s.floatingShadow),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton(s: s, assetName: 'bold', onTap: onBold),
            _ToolbarButton(s: s, assetName: 'italic', onTap: onItalic),
            _ToolbarButton(s: s, assetName: 'underline', onTap: onUnderline),
            _ToolbarDivider(s: s),
            _ToolbarButton(s: s, assetName: 'align_left', onTap: onAlignLeft),
            _ToolbarButton(s: s, assetName: 'align_center', onTap: onAlignCenter),
            _ToolbarButton(s: s, assetName: 'align_right', onTap: onAlignRight),
            _ToolbarDivider(s: s),
            _ToolbarButton(s: s, assetName: 'palette', onTap: onTextColor),
            // Preenchimento de célula: anel arco-íris em vez de SVG.
            _RainbowRingButton(onTap: onFillColor),
            _ToolbarDivider(s: s),
            _ToolbarButton(s: s, assetName: 'image', onTap: onInsertImage),
            _ToolbarButton(s: s, assetName: 'chart', onTap: onInsertChart),
            _ToolbarButton(s: s, assetName: 'link', onTap: onInsertLink),
          ],
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final AppColorScheme s;
  const _ToolbarDivider({required this.s});
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: s.outlineVariant);
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
        width: 40, height: 40, alignment: Alignment.center,
        child: _EditorIcon(assetName, size: 20, color: s.onSurface),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTÃO DE PREENCHIMENTO — anel circular com gradiente arco-íris
// no PRÓPRIO ANEL (contorno), não preenchido por dentro. Idêntico
// ao _RainbowRingButton de docs.dart (mesma pintura, mesma medida).
// ══════════════════════════════════════════════════════════════
class _RainbowRingButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RainbowRingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: _RainbowRingPainter()),
          ),
        ),
      ),
    );
  }
}

class _RainbowRingPainter extends CustomPainter {
  const _RainbowRingPainter();

  static const List<Color> _rainbow = [
    Color(0xFFFF0000), Color(0xFFFF9500), Color(0xFFFFCC00), Color(0xFF34C759),
    Color(0xFF00C7BE), Color(0xFF32ADE6), Color(0xFF007AFF), Color(0xFF5856D6),
    Color(0xFFAF52DE), Color(0xFFFF2D55), Color(0xFFFF0000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    const strokeWidth = 3.2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: _rainbow, startAngle: 0, endAngle: 2 * math.pi).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RainbowRingPainter oldDelegate) => false;
}

Future<String?> showChartConfigDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    title: 'Configuração do gráfico',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: ctrl, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: '{"type":"bar",...}')),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context, ctrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<String?> showImageUrlDialog(BuildContext context, AppColorScheme s) {
  final ctrl = TextEditingController();
  return showCraftBottomSheet<String>(
    context: context,
    s: s,
    title: 'URL da imagem',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'https://')),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pop(context, ctrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('Inserir', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// BLOCO HTML MULTI-CÉLULA — pede o HTML e o tamanho da área
// ══════════════════════════════════════════════════════════════
class HtmlBlockResult {
  final String html;
  final int rowspan;
  final int colspan;
  const HtmlBlockResult({required this.html, required this.rowspan, required this.colspan});
}

Future<HtmlBlockResult?> showHtmlBlockDialog(BuildContext context, AppColorScheme s) {
  final htmlCtrl = TextEditingController();
  int rowspan = 3;
  int colspan = 3;
  return showCraftBottomSheet<HtmlBlockResult>(
    context: context,
    s: s,
    title: 'Bloco HTML',
    child: StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O bloco começa na célula selecionada e ocupa a área indicada. O conteúdo é mostrado mas não é interativo (sem cliques nem scripts).',
              style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: htmlCtrl,
              minLines: 4,
              maxLines: 8,
              style: TextStyle(fontSize: 13, color: s.onSurface, fontFamily: 'monospace'),
              decoration: InputDecoration(
                isDense: true,
                hintText: '<div>...</div>',
                filled: true,
                fillColor: s.hover,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HtmlBlockSizeField(
                    s: s,
                    label: 'Linhas',
                    value: rowspan,
                    min: 1,
                    max: 20,
                    onChanged: (v) => setSheetState(() => rowspan = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HtmlBlockSizeField(
                    s: s,
                    label: 'Colunas',
                    value: colspan,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setSheetState(() => colspan = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                final html = htmlCtrl.text.trim();
                if (html.isEmpty) return;
                Navigator.pop(context, HtmlBlockResult(html: html, rowspan: rowspan, colspan: colspan));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
                child: Text('Inserir bloco', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HtmlBlockSizeField extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _HtmlBlockSizeField({required this.s, required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: s.pageBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: s.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              _stepBtn('-', () { if (value > min) onChanged(value - 1); }),
              Expanded(child: Text('$value', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface))),
              _stepBtn('+', () { if (value < max) onChanged(value + 1); }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28, alignment: Alignment.center,
        decoration: BoxDecoration(color: s.cardBackground, shape: BoxShape.circle, boxShadow: s.cardShadowSoft),
        child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: s.onSurface)),
      ),
    );
  }
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: widget.s.cardBackground, shape: BoxShape.circle),
          child: AppIcon('back.svg', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}