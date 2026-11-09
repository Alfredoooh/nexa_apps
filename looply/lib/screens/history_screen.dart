import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';
import '../localization.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/phosphor_svg_icon.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<String> _selectedKeys = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool get _isSelecting => _selectedKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final existing = activityController.entries.map(_key).toSet();
    _selectedKeys.removeWhere((key) => !existing.contains(key));
    setState(() {});
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text.trim().toLowerCase());
  }

  String _key(ActivityEntry entry) =>
      '${entry.kind.name}|${entry.url}|${entry.timestamp.microsecondsSinceEpoch}';

  void _toggle(ActivityEntry entry) {
    HapticFeedback.selectionClick();
    setState(() {
      final key = _key(entry);
      if (!_selectedKeys.add(key)) _selectedKeys.remove(key);
    });
  }

  // Ao voltar com seleção ativa, o primeiro toque em "fechar" apenas
  // desativa a seleção; só um segundo toque (ou voltar sem seleção)
  // efetivamente sai da tela.
  void _clearSelectionOrPop() {
    if (_isSelecting) {
      HapticFeedback.selectionClick();
      setState(_selectedKeys.clear);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('delete_history_selected'),
      icon: PhosphorIcons.trash,
      content: Text(appText('delete_history_count').replaceAll('{count}', _selectedKeys.length.toString())),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('delete'), value: true, isDestructive: true),
      ],
    );
    if (confirmed != true || !mounted) return;
    final selected = activityController.entries.where((entry) => _selectedKeys.contains(_key(entry))).toList();
    activityController.removeEntries(selected);
    setState(_selectedKeys.clear);
  }

  List<ActivityEntry> _filteredEntries() {
    final all = activityController.entries;
    if (_query.isEmpty) return all;
    return all.where((entry) {
      final title = entry.title.toLowerCase();
      final url = entry.url.toLowerCase();
      return title.contains(_query) || url.contains(_query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = _filteredEntries();
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCount = _selectedKeys.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);

    return PopScope<void>(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _clearSelectionOrPop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: bg,
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Stack(
            children: [
              entries.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        PhosphorSvgIcon(PhosphorIcons.clockCounterClockwise, size: 48, color: muted),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty ? appText('no_history') : appText('no_results'),
                          style: TextStyle(color: text, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(14, topInset + 72, 14, bottomInset + 92),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final isFirst = index == 0;
                        final isLast = index == entries.length - 1;
                        final entry = entries[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                          child: _HistoryCard(
                            entry: entry,
                            selected: _selectedKeys.contains(_key(entry)),
                            onTap: () => _isSelecting ? _toggle(entry) : _toggle(entry),
                            onLongPress: () => _toggle(entry),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(isFirst ? 22 : 8),
                              bottom: Radius.circular(isLast ? 22 : 8),
                            ),
                          ),
                        );
                      },
                    ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: topInset),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bg, bg, bg.withOpacity(0)],
                      stops: const [0, .58, 1],
                    ),
                  ),
                  child: SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(children: [
                        // O botão troca entre "voltar" e "fechar seleção"
                        // com um fade/scale suave, sem substituir o widget
                        // abruptamente — a posição e o tamanho não mudam.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: animation, child: child),
                          ),
                          child: _CircularHistoryButton(
                            key: ValueKey<bool>(_isSelecting),
                            tooltip: _isSelecting ? appText('close') : appText('back'),
                            icon: _isSelecting ? PhosphorIcons.x : PhosphorIcons.arrowLeft,
                            onTap: _clearSelectionOrPop,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isSelecting
                                ? appText('selected_count').replaceAll('{count}', selectedCount.toString())
                                : appText('history'),
                            style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (selectedCount > 0)
                          _CircularHistoryButton(
                            tooltip: '${appText('delete')} ($selectedCount)',
                            icon: PhosphorIcons.trash,
                            foreground: const Color(0xFFFF453A),
                            onTap: _deleteSelected,
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _HistorySearchBar(
                  controller: _searchController,
                  bottomInset: bottomInset,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Card de histórico: toque ativa a seleção com um ícone de check que
// aparece com animação de escala + fade (TweenAnimationBuilder), sem
// depender de nenhum pacote externo de ícones animados. À direita, um
// ícone de "abrir" (launch.svg, com fallback para arrowSquareOut) no
// lugar do antigo chevron.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.borderRadius,
  });

  final ActivityEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final isSite = entry.kind == ActivityKind.site;

    return Material(
      color: selected ? accent.withOpacity(.12) : settingsCardColor(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Ícone do site/atividade à esquerda, substituído pelo check
              // animado quando o card está selecionado.
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: selected ? 0 : 1,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                        child: PhosphorSvgIcon(
                          isSite ? PhosphorIcons.globe : PhosphorIcons.magnifyingGlass,
                          color: accent,
                          size: 18,
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Opacity(
                        opacity: value.clamp(0, 1),
                        child: Transform.scale(scale: value, child: child),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title.trim().isNotEmpty ? entry.title : entry.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(
                'assets/images/launch.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
                placeholderBuilder: (context) => PhosphorSvgIcon(PhosphorIcons.arrowUpLeft, color: muted, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom bar com o mesmo efeito de esmaecimento do antigo _LooplyBottomBar
// (gradiente transparente no topo, opaco na base), contendo um campo de
// busca que filtra o histórico em tempo real por título ou URL.
class _HistorySearchBar extends StatelessWidget {
  const _HistorySearchBar({required this.controller, required this.bottomInset});

  final TextEditingController controller;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withOpacity(0.0), bg, bg],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: pillColor(context),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Row(
            children: [
              PhosphorSvgIcon(PhosphorIcons.magnifyingGlass, color: muted, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: appText('search_history'),
                    hintStyle: TextStyle(color: muted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                GestureDetector(
                  onTap: controller.clear,
                  child: PhosphorSvgIcon(PhosphorIcons.x, color: muted, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularHistoryButton extends StatelessWidget {
  const _CircularHistoryButton({super.key, required this.tooltip, required this.icon, required this.onTap, this.foreground});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: pillColor(context),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: PhosphorSvgIcon(icon, color: foreground ?? mutedText(context), size: 20),
            ),
          ),
        ),
      );
}