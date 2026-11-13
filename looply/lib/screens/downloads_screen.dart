import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _DownloadsScreenState extends State<DownloadsScreen> {
  final Set<String> _selectedIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    downloadsController.addListener(_onChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    downloadsController.removeListener(_onChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
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

  void _toggle(DownloadEntry entry) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.add(entry.id)) _selectedIds.remove(entry.id);
    });
  }

  void _clearSelectionOrPop() {
    if (_isSelecting) {
      HapticFeedback.selectionClick();
      setState(_selectedIds.clear);
      return;
    }
    Navigator.of(context).maybePop();
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

  static const MethodChannel _nativeFileViewerChannel =
      MethodChannel('looply/native_ui');

  // O leitor de ficheiros é uma Activity Kotlin independente. Não cria
  // separadores nem inicializa o Orbit Browser.
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

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = _filteredEntries();
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selectedCount = _selectedIds.length;
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
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(14, topInset + 72, 14, bottomInset + 92),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final isFirst = index == 0;
                        final isLast = index == entries.length - 1;
                        final entry = entries[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                          child: _DownloadCard(
                            entry: entry,
                            selected: _selectedIds.contains(entry.id),
                            onTap: () => _isSelecting ? _toggle(entry) : _openEntry(entry),
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: animation, child: child),
                          ),
                          child: _DownloadHeaderButton(
                            key: ValueKey<bool>(_isSelecting),
                            tooltip: _isSelecting ? appText('close') : appText('back'),
                            icon: _isSelecting ? AppIcons.x : AppIcons.arrowLeft,
                            onTap: _clearSelectionOrPop,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isSelecting
                                ? appText('selected_count').replaceAll('{count}', selectedCount.toString())
                                : appText('downloads'),
                            style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (selectedCount > 0)
                          _DownloadHeaderButton(
                            tooltip: '${appText('delete')} ($selectedCount)',
                            icon: AppIcons.trash,
                            foreground: const Color(0xFFFF453A),
                            onTap: _deleteSelected,
                          )
                        else if (entries.isNotEmpty)
                          _DownloadHeaderButton(
                            tooltip: appText('clear_list'),
                            icon: AppIcons.trash,
                            onTap: () async {
                              final confirmed = await showLooplyDialog<bool>(
                                context: context,
                                title: appText('clear_list'),
                                icon: AppIcons.trash,
                                content: Text(appText('clear_downloads_confirmation')),
                                actions: <LooplyDialogAction<bool>>[
                                  LooplyDialogAction<bool>(label: appText('cancel'), value: false),
                                  LooplyDialogAction<bool>(label: appText('delete'), value: true, isDestructive: true),
                                ],
                              );
                              if (confirmed == true) await downloadsController.clear();
                            },
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
                child: _DownloadsSearchBar(
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

// Card de download: ícone por tipo de ficheiro, barra de progresso quando
// a transferir, check animado quando selecionado, e ícone de launch à
// direita (fallback para arrowSquareOut quando o asset não existe).
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

class _DownloadsSearchBar extends StatelessWidget {
  const _DownloadsSearchBar({required this.controller, required this.bottomInset});

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
              AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
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
              if (controller.text.isNotEmpty)
                GestureDetector(
                  onTap: controller.clear,
                  child: AppMaterialIcon(AppIcons.x, color: muted, size: 16),
                ),
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