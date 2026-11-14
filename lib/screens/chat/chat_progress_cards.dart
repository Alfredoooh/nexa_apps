import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/animated_canvas_icon.dart';
import '../apps/app_types.dart';
// TODO: depende de apps/docs.dart (split futuro); manter este import para a etapa futura de split.
import '../apps/docs/docs_screen.dart';
import '../apps/sheets/sheets_app.dart';
import '../apps/slides/slides_app.dart';
import '../../widgets/app_sheet.dart';
// TODO: depende de aiwidgets.dart (split futuro); manter este import para a etapa futura de split.
import '../ai_widgets/ai_widgets.dart';
import '../apps/sheets/sheets_screen.dart';
import 'chat_models.dart';
import 'widgets/chat_widgets_shared.dart';
import 'chat_tools.dart';


class StreamingMarkdownCard extends StatelessWidget {
  final AppColorScheme s;
  final String label;

  const StreamingMarkdownCard({
    super.key,
    required this.s,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: s.pageBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NexaLoaderLogo(size: 18, tintColor: s.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShimmerText(
                  text: label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: s.onSurfaceVariant,
                  ),
                  active: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasProgressCard extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final LocalCanvasItem? item;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<bool> doneNotifier;
  final LocalCanvasItem? Function() finalItem;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;

  const CanvasProgressCard({
    super.key,
    required this.s,
    required this.title,
    required this.item,
    required this.contentNotifier,
    required this.doneNotifier,
    required this.finalItem,
    required this.onOpenCanvas,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: doneNotifier,
      builder: (_, done, __) {
        if (done && item != null) {
          return GestureDetector(
            onTap: () => showCanvasPreviewModal(
              context,
              s,
              title: item!.title,
              content: item!.content,
              onOpen: () => onOpenCanvas(item!),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: s.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.cardShadow,
              ),
              child: Row(
                children: [
                  AnimatedCanvasIcon(
                    editorType: item!.kind.editorType,
                    s: s,
                    size: 44,
                    animated: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: s.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item!.kind.shortLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: s.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => showCanvasStreamingModal(
            context, s,
            title: title,
            contentNotifier: contentNotifier,
            doneNotifier: doneNotifier,
            finalItem: finalItem,
            onOpenCanvas: onOpenCanvas,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: s.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: s.cardShadow,
            ),
            child: Row(
              children: [
                AnimatedCanvasIcon(
                  editorType: editorTypeFromProgressTitle(title),
                  s: s,
                  size: 44,
                  animated: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerText(
                        text: title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: s.onSurface),
                        active: true,
                      ),
                      const SizedBox(height: 2),
                      ShimmerText(
                        text: 'A gerar...',
                        style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                        active: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WidgetProgressCard extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final AiWidgetBlock? block;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<bool> doneNotifier;

  const WidgetProgressCard({
    super.key,
    required this.s,
    required this.label,
    required this.block,
    required this.contentNotifier,
    required this.doneNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: doneNotifier,
      builder: (_, done, __) {
        if (done && block != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: buildAiWidget(block!, s),
          );
        }
        return GestureDetector(
          onTap: () => showWidgetStreamingModal(
            context, s,
            title: label,
            contentNotifier: contentNotifier,
            doneNotifier: doneNotifier,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: s.pageBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NexaLoaderLogo(size: 20, tintColor: s.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerText(
                      text: label,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: s.onSurface),
                      active: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Card mostrado enquanto uma tool call está a ser executada
/// (antes do texto de resposta começar a chegar). Ícone específico
/// por tool (com fallback), texto sempre alinhado à esquerda.
class ToolCallProgressCard extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  final String toolName;

  const ToolCallProgressCard({
    super.key,
    required this.s,
    required this.label,
    required this.toolName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.pageBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                s.onSurfaceVariant.withOpacity(0.3),
                s.onSurfaceVariant,
                s.onSurfaceVariant.withOpacity(0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: ToolIcon(toolName: toolName, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShimmerText(
                text: label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: s.onSurface),
                active: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODAIS DE STREAMING / PREVIEW
// ══════════════════════════════════════════════════════════════

Future<void> showCanvasStreamingModal(
  BuildContext context,
  AppColorScheme s, {
  required String title,
  required ValueNotifier<String> contentNotifier,
  required ValueNotifier<bool> doneNotifier,
  required LocalCanvasItem? Function() finalItem,
  required ValueChanged<LocalCanvasItem> onOpenCanvas,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: _CanvasStreamingModalContent(
      s: s,
      title: title,
      contentNotifier: contentNotifier,
      doneNotifier: doneNotifier,
      finalItem: finalItem,
      onOpenCanvas: onOpenCanvas,
    ),
  );
}

class _CanvasStreamingModalContent extends StatelessWidget {
  final AppColorScheme s;
  final String title;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<bool> doneNotifier;
  final LocalCanvasItem? Function() finalItem;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;

  const _CanvasStreamingModalContent({
    required this.s,
    required this.title,
    required this.contentNotifier,
    required this.doneNotifier,
    required this.finalItem,
    required this.onOpenCanvas,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: doneNotifier,
            builder: (_, done, __) => Row(
              children: [
                AnimatedCanvasIcon(
                  editorType: finalItem()?.kind.editorType ?? EditorType.docs,
                  s: s,
                  size: 32,
                  animated: !done,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: s.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: ValueListenableBuilder<String>(
                valueListenable: contentNotifier,
                builder: (_, content, __) => SelectableText(
                  content,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: s.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: doneNotifier,
            builder: (_, done, __) => GestureDetector(
              onTap: done
                  ? () {
                      final item = finalItem();
                      if (item != null) {
                        Navigator.pop(context);
                        onOpenCanvas(item);
                      }
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? s.primary : s.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  done ? 'Abrir' : 'A gerar...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: done ? s.onPrimary : s.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCanvasPreviewModal(
  BuildContext context,
  AppColorScheme s, {
  required String title,
  required String content,
  required VoidCallback onOpen,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                RoundedSymbols.description,
                size: 28,
                color: s.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: s.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: s.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onOpen();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Abrir',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showWidgetStreamingModal(
  BuildContext context,
  AppColorScheme s, {
  required String title,
  required ValueNotifier<String> contentNotifier,
  required ValueNotifier<bool> doneNotifier,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NexaLoaderLogo(size: 20, tintColor: s.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: s.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              child: ValueListenableBuilder<String>(
                valueListenable: contentNotifier,
                builder: (_, content, __) => SelectableText(
                  content,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: s.onSurfaceVariant, height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// COLLAPSIBLE "EM PROCESSO" — lista acumulada de passos de tool
// calls. Sem fundo/card — texto no tom do corpo, como o
// "Pensamento". Começa aberto, fecha sozinho no fim, mas o
// utilizador pode abrir/fechar livremente a qualquer momento. Os
// passos NUNCA são removidos ou ocultados individualmente — só a
// visibilidade do bloco inteiro (expandido/colapsado) muda.
// ══════════════════════════════════════════════════════════════

class ProcessCollapsible extends StatefulWidget {
  final AppColorScheme s;
  final List<ProcessStep> steps;
  final bool isActive;
  final bool startExpanded;

  const ProcessCollapsible({
    super.key,
    required this.s,
    required this.steps,
    required this.isActive,
    this.startExpanded = true,
  });

  @override
  State<ProcessCollapsible> createState() => _ProcessCollapsibleState();
}

class _ProcessCollapsibleState extends State<ProcessCollapsible> {
  late bool _expanded = widget.startExpanded;
  bool _userOverrode = false;
  bool _wasActive = true;

  @override
  void didUpdateWidget(covariant ProcessCollapsible old) {
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
    if (widget.steps.isEmpty) return const SizedBox.shrink();

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
                        text: 'Em processo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
                        active: true,
                      )
                    : Text(
                        'Em processo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
                      ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: AppIcon('chevron_down', size: 14, color: s.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ProcessStepsList(s: s, steps: widget.steps, isActive: widget.isActive),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

class _ProcessStepsList extends StatelessWidget {
  final AppColorScheme s;
  final List<ProcessStep> steps;
  final bool isActive;
  const _ProcessStepsList({required this.s, required this.steps, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++)
          _ProcessStepRow(
            s: s,
            step: steps[i],
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _ProcessStepRow extends StatelessWidget {
  final AppColorScheme s;
  final ProcessStep step;
  final bool isLast;
  const _ProcessStepRow({
    required this.s,
    required this.step,
    required this.isLast,
  });

  String _faviconUrl(String domain) =>
      'https://www.google.com/s2/favicons?sz=64&domain=$domain';

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: step.done ? s.onSurfaceVariant : s.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 3, bottom: 3),
                      color: s.outline.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  step.done
                      ? Text(
                          step.label.replaceAll('...', ''),
                          style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
                        )
                      : ShimmerText(
                          text: step.label,
                          style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
                          active: true,
                        ),
                  if (step.summary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.summary!,
                      style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant.withOpacity(0.75)),
                    ),
                  ],
                  if (step.faviconDomains.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: step.faviconDomains.map((domain) {
                        return ClipOval(
                          child: Container(
                            width: 18,
                            height: 18,
                            color: s.hover,
                            child: Image.network(
                              _faviconUrl(domain),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(RoundedSymbols.public, size: 10, color: s.onSurfaceVariant),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (step.foundImages.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        itemCount: step.foundImages.length.clamp(0, 6),
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final url = step.foundImages[i]['imageUrl']?.toString() ?? '';
                          if (url.isEmpty) return const SizedBox.shrink();
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40),
                            ),
                          );
                        },
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