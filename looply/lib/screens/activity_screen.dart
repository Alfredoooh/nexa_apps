import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../localization.dart';
import '../models.dart';
import '../browser_library.dart';
import '../theme.dart';
import '../widgets/stats_chart.dart';
import '../shell/browser_navigation.dart';
import 'history_screen.dart';
import '../widgets/phosphor_svg_icon.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    activityController.addListener(_onChanged);
    for (final entry in activityController.entries) {
      if (entry.kind == ActivityKind.site) {
        unawaited(browserFaviconCache.fetchForUrl(entry.url));
      }
    }
  }

  @override
  void dispose() {
    activityController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = activityController.entries;
    final recent = entries.take(5).toList();

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(appText('activity')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          const AdBlockStatsChart(),
          const SizedBox(height: 6),
          ActivitySummaryCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  appText('recent'),
                  style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                  child: Text(appText('view_all')),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  PhosphorSvgIcon(PhosphorIcons.clockCounterClockwise, size: 38, color: muted),
                  const SizedBox(height: 9),
                  Text(
                    appText('no_recent_activity'),
                    style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            ...List.generate(recent.length, (index) {
              final isFirst = index == 0;
              final isLast = index == recent.length - 1;
              final top = isFirst ? 22.0 : 8.0;
              final bottom = isLast ? 22.0 : 8.0;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                child: ActivityTile(
                  entry: recent[index],
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(top),
                    bottom: Radius.circular(bottom),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry, this.borderRadius, this.selected = false, this.onTap, this.onLongPress});
  final ActivityEntry entry;
  final BorderRadius? borderRadius;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: selected ? accentColor(context).withOpacity(.13) : settingsCardColor(context),
      borderRadius: borderRadius ?? BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => openOrbitTab(context, entry.url, title: entry.title),
        onLongPress: onLongPress,
        borderRadius: borderRadius ?? BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            AnimatedBuilder(
              animation: browserFaviconCache,
              builder: (context, _) {
                final encoded = browserFaviconCache.forUrl(entry.url);
                Widget icon = PhosphorSvgIcon(PhosphorIcons.globe, color: accentColor(context), size: 19);
                if (encoded != null) {
                  try {
                    icon = Image.memory(
                      base64Decode(encoded),
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => PhosphorSvgIcon(PhosphorIcons.globe, color: accentColor(context), size: 19),
                    );
                  } catch (_) {}
                }
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                  child: Center(child: icon),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(formatActivityTime(entry.timestamp), style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
            PhosphorSvgIcon(
              selected ? PhosphorIcons.checkCircle : PhosphorIcons.caretRight,
              color: selected ? accentColor(context) : muted,
              size: 19,
            ),
          ]),
        ),
      ),
    );
  }
}

String formatActivityTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return appText('time_now');
  if (diff.inMinutes < 60) return appText('time_minutes').replaceAll('{count}', diff.inMinutes.toString());
  if (diff.inHours < 24) return appText('time_hours').replaceAll('{count}', diff.inHours.toString());
  return appText('time_days').replaceAll('{count}', diff.inDays.toString());
}