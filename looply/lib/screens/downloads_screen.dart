import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models.dart';
import '../browser_library.dart';
import '../theme.dart';
import '../localization.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/material_symbols.dart';
import 'package:material_symbols_icons/symbols.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

// Uma "run" é uma sequência consecutiva de entradas do mesmo tipo
// (mídia visual ou documento/outro), preservando a ordem cronológica
// original da lista. A timeline nunca mistura os dois tipos dentro da
// mesma run: assim que o tipo muda, a run fecha e outra abre. Cada run
// de mídia vira um SliverMasonryGrid próprio (2 colunas, altura real);
// cada run de documento vira um SliverList (1 coluna, layout original).
class _TimelineRun {
  _TimelineRun({required this.isMedia, required this.entries});
  final bool isMedia;
  final List<DownloadEntry> entries;
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final Set<String> _selectedIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _searchActive = false;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    downloadsController.addListener(_onChanged);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    downloadsController.removeListener(_onChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final existing = downloadsController.entries.map((entry) => entry.id).toSet();
    _selectedIds.removeWhere((id) => !existing.contains(id));
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

  void _toggle(DownloadEntry entry) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.add(entry.id)) _selectedIds.remove(entry.id);
    });
  }

  void _handleBack() {
    if (_isSelecting) {
      HapticFeedback.selectionClick();
      setState(_selectedIds.clear);
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
    if (_selectedIds.isEmpty) return;
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('delete_downloads_selected'),
      icon: AppIcons.trash,
      content: Text(appText('delete_downloads_count').replaceAll('{count}', _selectedIds.length.toString())),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('delete'), value: true, isDestructive: true),
      ],
    );
    if (confirmed != true || !mounted) return;
    final ids = _selectedIds.toList(growable: false);
    for (final id in ids) {
      await downloadsController.remove(id);
    }
    if (mounted) setState(_selectedIds.clear);
  }

  List<DownloadEntry> _filteredEntries() {
    final all = downloadsController.entries;
    if (_query.isEmpty) return all;
    return all.where((entry) => entry.filename.toLowerCase().contains(_query)).toList(growable: false);
  }

  bool _isVisualMedia(DownloadEntry entry) {
    final mime = entry.mimeType ?? '';
    return mime.startsWith('image/') || mime.startsWith('video/');
  }

  // Quebra a lista (já ordenada por data, mais recente primeiro) em
  // runs consecutivas do mesmo tipo. Isso é diferente de agrupar em
  // pares fixos: uma run de mídia pode ter 1, 2, 5 ou 20 itens seguidos
  // — o MasonryGrid é quem decide como eles se encaixam nas 2 colunas.
  List<_TimelineRun> _buildRuns(List<DownloadEntry> entries) {
    final runs = <_TimelineRun>[];
    var index = 0;
    while (index < entries.length) {
      final startIsMedia = _isVisualMedia(entries[index]);
      final group = <DownloadEntry>[entries[index]];
      var next = index + 1;
      while (next < entries.length && _isVisualMedia(entries[next]) == startIsMedia) {
        group.add(entries[next]);
        next += 1;
      }
      runs.add(_TimelineRun(isMedia: startIsMedia, entries: group));
      index = next;
    }
    return runs;
  }

  static const MethodChannel _nativeFileViewerChannel =
      MethodChannel('looply/native_ui');

  Future<void> _openEntry(DownloadEntry entry) async {
    if (!entry.canOpenLocally || entry.localPath == null) return;

    if (Theme.of(context).platform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText('file_viewer_android_only'))),
      );
      return;
    }

    try {
      await _nativeFileViewerChannel.invokeMethod<bool>(
        'openNativeFileViewer',
        <String, Object?>{
          'path': entry.localPath!,
          'filename': entry.filename,
          'mimeType': entry.mimeType ?? '',
        },
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? appText('file_open_failed'))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText('file_open_failed'))),
      );
    }
  }

  void _onEntryTap(DownloadEntry entry) {
    if (_isSelecting) {
      _toggle(entry);
    } else {
      _openEntry(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = _filteredEntries();
    final runs = _buildRuns(entries);
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCount = _selectedIds.length;
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
                        AppMaterialIcon(AppIcons.downloadSimple, size: 48, color: muted),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty ? appText('no_downloads') : appText('no_results'),
                          style: TextStyle(color: text, fontWeight: FontWeight.w700),
                        ),
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 5),
                          Text(appText('downloads_intro'), style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ]),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(14, topInset + 72, 14, 0),
                          sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                        ),
                        for (var runIndex = 0; runIndex < runs.length; runIndex++)
                          ..._buildRunSlivers(
                            runs[runIndex],
                            isFirstRun: runIndex == 0,
                            isLastRun: runIndex == runs.length - 1,
                          ),
                        SliverPadding(padding: EdgeInsets.only(bottom: bottomInset + 24)),
                      ],
                    ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _DownloadsFadeAppBar(
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

  // Cada run vira 1 ou 2 slivers: o conteúdo (grid ou list) e um
  // espaçador de 2px entre runs (exceto após a última), para manter o
  // mesmo respiro visual que já existia entre cards soltos.
  List<Widget> _buildRunSlivers(
    _TimelineRun run, {
    required bool isFirstRun,
    required bool isLastRun,
  }) {
    final slivers = <Widget>[];

    if (run.isMedia) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childCount: run.entries.length,
            itemBuilder: (context, index) {
              final entry = run.entries[index];
              final isFirstItem = isFirstRun && index < 2;
              final isLastItem = isLastRun && index >= run.entries.length - 2;
              return _MediaTile(
                entry: entry,
                selected: _selectedIds.contains(entry.id),
                onTap: () => _onEntryTap(entry),
                onLongPress: () => _toggle(entry),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isFirstItem ? 22 : 10),
                  bottom: Radius.circular(isLastItem ? 22 : 10),
                ),
              );
            },
          ),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          sliver: SliverList.builder(
            itemCount: run.entries.length,
            itemBuilder: (context, index) {
              final entry = run.entries[index];
              final isFirstItem = isFirstRun && index == 0;
              final isLastItem = isLastRun && index == run.entries.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: index == run.entries.length - 1 ? 0 : 2),
                child: _DownloadCard(
                  entry: entry,
                  selected: _selectedIds.contains(entry.id),
                  onTap: () => _onEntryTap(entry),
                  onLongPress: () => _toggle(entry),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(isFirstItem ? 22 : 8),
                    bottom: Radius.circular(isLastItem ? 22 : 8),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (!isLastRun) {
      slivers.add(const SliverPadding(padding: EdgeInsets.only(top: 2)));
    }

    return slivers;
  }
}

class _DownloadsFadeAppBar extends StatelessWidget {
  const _DownloadsFadeAppBar({
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
              _DownloadHeaderButton(
                key: ValueKey<String>(isSelecting || searchActive ? 'close' : 'back'),
                tooltip: isSelecting || searchActive ? appText('close') : appText('back'),
                icon: isSelecting || searchActive ? AppIcons.x : AppIcons.arrowLeft,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
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
                      ? _DownloadsSearchField(
                          key: const ValueKey<String>('search-field'),
                          controller: searchController,
                          focusNode: searchFocusNode,
                        )
                      : Text(
                          isSelecting
                              ? appText('selected_count').replaceAll('{count}', selectedCount.toString())
                              : appText('downloads'),
                          key: const ValueKey<String>('title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: isSelecting
                    ? _DownloadHeaderButton(
                        key: const ValueKey<String>('delete'),
                        tooltip: '${appText('delete')} ($selectedCount)',
                        icon: AppIcons.trash,
                        foreground: const Color(0xFFFF453A),
                        onTap: onDelete,
                      )
                    : searchActive
                        ? const SizedBox(key: ValueKey<String>('empty'), width: 42, height: 42)
                        : _DownloadHeaderButton(
                            key: const ValueKey<String>('search'),
                            tooltip: appText('search_downloads'),
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

class _DownloadsSearchField extends StatelessWidget {
  const _DownloadsSearchField({super.key, required this.controller, required this.focusNode});

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
                hintText: appText('search_downloads'),
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

// Tile individual de mídia dentro do SliverMasonryGrid. Resolve a
// proporção real da imagem via ImageStreamListener (sem depender de
// campo de dimensão pré-calculado em DownloadEntry) e usa AspectRatio
// para reportar sua altura verdadeira ao masonry — é esse AspectRatio
// que faz o encaixe staggered funcionar de verdade entre colunas.
class _MediaTile extends StatefulWidget {
  const _MediaTile({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.borderRadius,
  });

  final DownloadEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final BorderRadius borderRadius;

  @override
  State<_MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<_MediaTile> {
  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get _isVideo => (widget.entry.mimeType ?? '').startsWith('video/');

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _MediaTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.localPath != widget.entry.localPath) {
      _detachStream();
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachStream();
    super.dispose();
  }

  void _detachStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolveAspectRatio() {
    final path = widget.entry.localPath;
    if (path == null || path.isEmpty) return;

    final provider = ResizeImage(FileImage(File(path)), width: 600);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (width > 0 && height > 0) {
        setState(() => _aspectRatio = width / height);
      }
      stream.removeListener(listener);
    }, onError: (error, stackTrace) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    final accent = accentColor(context);
    final ratio = (_aspectRatio ?? 1.0).clamp(0.5, 2.2);
    final path = widget.entry.localPath;

    return Material(
      color: pillColor(context),
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null && path.isNotEmpty)
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: pillColor(context),
                    alignment: Alignment.center,
                    child: AppMaterialIcon(
                      _isVideo ? AppIcons.playCircle : AppIcons.image,
                      color: muted,
                      size: 32,
                    ),
                  ),
                )
              else
                Container(
                  color: pillColor(context),
                  alignment: Alignment.center,
                  child: AppMaterialIcon(
                    _isVideo ? AppIcons.playCircle : AppIcons.image,
                    color: muted,
                    size: 32,
                  ),
                ),
              if (_isVideo)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(.45)],
                        stops: const [.6, 1],
                      ),
                    ),
                  ),
                ),
              if (_isVideo)
                const Center(
                  child: Icon(Symbols.play_circle_rounded, color: Colors.white, size: 40),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  widget.entry.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: widget.selected ? 1 : 0,
                child: Container(
                  color: accent.withOpacity(.35),
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                    child: const Icon(Symbols.check_rounded, color: Colors.white, size: 16),
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

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.borderRadius,
  });

  final DownloadEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final BorderRadius borderRadius;

  String _statusLabel() {
    switch (entry.status) {
      case DownloadStatus.pending:
        return appText('download_pending');
      case DownloadStatus.downloading:
        return '${appText('download_downloading')} · ${(entry.progress * 100).toStringAsFixed(0)}%';
      case DownloadStatus.completed:
        return appText('download_completed');
      case DownloadStatus.failed:
        return appText('download_failed');
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final isDownloading = entry.status == DownloadStatus.downloading;
    final isFailed = entry.status == DownloadStatus.failed;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: selected ? 0 : 1,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                            child: AppMaterialIcon(
                              isFailed ? AppIcons.warningCircle : entry.icon,
                              color: isFailed ? const Color(0xFFFF453A) : accent,
                              size: 20,
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
                            width: 40,
                            height: 40,
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
                          entry.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_statusLabel()} · ${_date(entry.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isFailed ? const Color(0xFFFF453A) : muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (entry.canOpenLocally)
                    Icon(Symbols.open_in_new_rounded, color: muted, size: 18)
                  else if (isDownloading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    ),
                ],
              ),
              if (isDownloading) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: entry.progress > 0 ? entry.progress : null,
                    minHeight: 3,
                    color: accent,
                    backgroundColor: muted.withOpacity(.15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadHeaderButton extends StatelessWidget {
  const _DownloadHeaderButton({super.key, required this.tooltip, required this.icon, required this.onTap, this.foreground});
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