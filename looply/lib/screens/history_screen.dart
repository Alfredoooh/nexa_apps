import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../localization.dart';
import '../widgets/looply_dialog.dart';
import 'activity_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Set<String> _selectedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final existing = activityController.entries.map(_key).toSet();
    _selectedKeys.removeWhere((key) => !existing.contains(key));
    setState(() {});
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

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('delete_history_selected'),
      icon: Symbols.delete_outline_rounded,
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

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = activityController.entries;
    final topInset = MediaQuery.of(context).padding.top;
    final selectedCount = _selectedKeys.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = pageBg(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                      Icon(Symbols.history_rounded, size: 48, color: muted),
                      const SizedBox(height: 12),
                      Text(appText('no_history'), style: TextStyle(color: text, fontWeight: FontWeight.w700)),
                    ]),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(14, topInset + 72, 14, 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final isFirst = index == 0;
                      final isLast = index == entries.length - 1;
                      final entry = entries[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                        child: ActivityTile(
                          entry: entry,
                          selected: _selectedKeys.contains(_key(entry)),
                          onTap: () => _toggle(entry),
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
                      _CircularHistoryButton(
                        tooltip: appText('back'),
                        icon: Symbols.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          appText('history'),
                          style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (selectedCount > 0)
                        _CircularHistoryButton(
                          tooltip: '${appText('delete')} ($selectedCount)',
                          icon: Symbols.delete_outline_rounded,
                          foreground: const Color(0xFFFF453A),
                          onTap: _deleteSelected,
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularHistoryButton extends StatelessWidget {
  const _CircularHistoryButton({required this.tooltip, required this.icon, required this.onTap, this.foreground});
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
              child: Icon(icon, color: foreground ?? mutedText(context), size: 20),
            ),
          ),
        ),
      );
}
