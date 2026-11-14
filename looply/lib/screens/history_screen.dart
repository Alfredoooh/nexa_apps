import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../localization.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/material_symbols.dart';
import 'activity_screen.dart' show SiteFaviconAvatar;
import '../shell/browser_navigation.dart';
import 'package:material_symbols_icons/symbols.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<String> _selectedKeys = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _searchActive = false;

  bool get _isSelecting => _selectedKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  void _onFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus && !_searchActive) {
      setState(() => _searchActive = true);
    }
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

  // Ordem de prioridade ao voltar: 1) sair da seleção, 2) fechar a busca
  // expandida, 3) sair da tela.
  void _handleBack() {
    if (_isSelecting) {
      HapticFeedback.selectionClick();
      setState(_selectedKeys.clear);
      return;
    }
    if (_searchActive) {
      _closeSearch();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openSearch() {
    setState(() => _searchActive = true);
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchActive = false;
      _query = '';
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('delete_history_selected'),
      icon: AppIcons.trash,
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
      canPop: !_isSelecting && !_searchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
        child: Scaffold(
          backgroundColor: bg,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              entries.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AppMaterialIcon(AppIcons.clockCounterClockwise, size: 48, color: muted),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty ? appText('no_history') : appText('no_results'),
                          style: TextStyle(color: text, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(14, topInset + 72, 14, bottomInset + 24),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isFirst = index == 0;
                        final isLast = index == entries.length - 1;
                        final previous = index > 0 ? entries[index - 1] : null;
                        final day = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
                        final previousDay = previous == null ? null : DateTime(previous.timestamp.year, previous.timestamp.month, previous.timestamp.day);
                        final showDay = previousDay == null || day != previousDay;
                        // Quando um cabeçalho de dia aparece, o item seguinte
                        // reinicia o agrupamento visual (topo arredondado),
                        // mesmo que não seja o primeiro da lista inteira.
                        final groupFirst = isFirst || showDay;
                        final nextEntry = index < entries.length - 1 ? entries[index + 1] : null;
                        final nextDay = nextEntry == null
                            ? null
                            : DateTime(nextEntry.timestamp.year, nextEntry.timestamp.month, nextEntry.timestamp.day);
                        final groupLast = isLast || nextDay != day;
                        final card = _HistoryCard(
                          entry: entry,
                          selected: _selectedKeys.contains(_key(entry)),
                          onTap: () {
                            if (_isSelecting) {
                              _toggle(entry);
                            } else if (entry.kind == ActivityKind.site) {
                              openOrbitTab(context, entry.url, title: entry.title);
                            }
                          },
                          onLongPress: () => _toggle(entry),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(groupFirst ? 22 : 8),
                            bottom: Radius.circular(groupLast ? 22 : 8),
                          ),
                        );
                        return Padding(
                          padding: EdgeInsets.only(bottom: groupLast ? 0 : 2),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (showDay) ...[
                              Padding(
                                padding: EdgeInsets.fromLTRB(4, isFirst ? 0 : 16, 4, 8),
                                child: Text(
                                  '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
                                  style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .2),
                                ),
                              ),
                            ],
                            card,
                          ]),
                        );
                      },
                    ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HistoryFadeAppBar(
                  topInset: topInset,
                  isSelecting: _isSelecting,
                  searchActive: _searchActive,
                  selectedCount: selectedCount,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onBack: _handleBack,
                  onOpenSearch: _openSearch,
                  onDelete: _deleteSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// AppBar com esmaecimento (mesmo gradiente das demais telas) que alterna
// entre três estados: normal (título + voltar + lupa), seleção (título
// "X selecionados" + lixeira), e busca (input expandido ocupando o lugar
// do título, com botão de voltar fechando a busca).
class _HistoryFadeAppBar extends StatelessWidget {
  const _HistoryFadeAppBar({
    required this.topInset,
    required this.isSelecting,
    required this.searchActive,
    required this.selectedCount,
    required this.searchController,
    required this.searchFocusNode,
    required this.onBack,
    required this.onOpenSearch,
    required this.onDelete,
  });

  final double topInset;
  final bool isSelecting;
  final bool searchActive;
  final int selectedCount;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);

    return Container(
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
          child: Row(
            children: [
              // Botão de voltar/fechar: sempre visível, troca de ícone
              // conforme o estado (voltar / sair da seleção / fechar busca).
              _HistoryHeaderButton(
                key: ValueKey<String>(isSelecting || searchActive ? 'close' : 'back'),
                tooltip: isSelecting || searchActive ? appText('close') : appText('back'),
                icon: isSelecting || searchActive ? AppIcons.x : AppIcons.arrowLeft,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              // O título encolhe e desaparece (fade + leve deslocamento)
              // exatamente quando a busca expande; o Expanded garante que
              // o input ocupa o espaço liberado sem saltos de layout.
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: searchActive
                      ? _HistorySearchField(
                          key: const ValueKey<String>('search-field'),
                          controller: searchController,
                          focusNode: searchFocusNode,
                        )
                      : Text(
                          isSelecting
                              ? appText('selected_count').replaceAll('{count}', selectedCount.toString())
                              : appText('history'),
                          key: const ValueKey<String>('title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Ação à direita: lixeira em seleção, lupa em repouso, nada
              // durante a busca (o próprio input já tem o ícone de lupa).
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: isSelecting
                    ? _HistoryHeaderButton(
                        key: const ValueKey<String>('delete'),
                        tooltip: '${appText('delete')} ($selectedCount)',
                        icon: AppIcons.trash,
                        foreground: const Color(0xFFFF453A),
                        onTap: onDelete,
                      )
                    : searchActive
                        ? const SizedBox(key: ValueKey<String>('empty'), width: 42, height: 42)
                        : _HistoryHeaderButton(
                            key: const ValueKey<String>('search'),
                            tooltip: appText('search_history'),
                            icon: AppIcons.magnifyingGlass,
                            onTap: onOpenSearch,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Campo de busca que some no lugar do título. Tem o mesmo fundo em
// pílula usado no restante do app (pillColor) e um "x" para limpar o
// texto sem precisar fechar a busca inteira.
class _HistorySearchField extends StatelessWidget {
  const _HistorySearchField({super.key, required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
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
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: controller.clear,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: AppMaterialIcon(AppIcons.x, color: muted, size: 15),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Card de histórico: toque ativa a seleção com um ícone de check que
// aparece com animação de escala + fade (TweenAnimationBuilder), sem
// depender de nenhum pacote externo de ícones animados. À direita, um
// ícone de abertura externa em Material Symbols Rounded no
// lugar do antigo chevron. À esquerda, usa SiteFaviconAvatar (o
// mesmo widget já usado nos cartões de "Recentes" da tela de Atividade)
// para entradas de site: mostra o favicon real quando disponível, ou um
// círculo cinza com a inicial do host — nunca mais o ícone de globo
// genérico. Entradas de jogo mantêm o ícone fixo de lupa, já que não há
// favicon de URL de jogo para buscar.
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: selected ? 0 : 1,
                      child: isSite
                          ? SiteFaviconAvatar(url: entry.url, size: 38)
                          : Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                              child: AppMaterialIcon(
                                AppIcons.magnifyingGlass,
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
                        child: const Icon(Symbols.check_rounded, color: Colors.white, size: 20),
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
                      style: TextStyle(color: text, fontSize: 14.2, fontWeight: FontWeight.w700),
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
              Icon(Symbols.open_in_new_rounded, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryHeaderButton extends StatelessWidget {
  const _HistoryHeaderButton({super.key, required this.tooltip, required this.icon, required this.onTap, this.foreground});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: icon == AppIcons.arrowLeft ? Colors.transparent : pillColor(context),
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: AppMaterialIcon(icon, color: foreground ?? mutedText(context), size: 20),
              ),
            ),
          ),
        ),
      );
}