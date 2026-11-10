import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/svg_icon.dart';

class AdBlockCalendarScreen extends StatefulWidget {
  const AdBlockCalendarScreen({super.key});

  @override
  State<AdBlockCalendarScreen> createState() => _AdBlockCalendarScreenState();
}

class _AdBlockCalendarScreenState extends State<AdBlockCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
      _selectedDate = DateTime(
        _month.year,
        _month.month,
        _selectedDate.day.clamp(1, lastDay).toInt(),
      );
    });
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final stats = AdBlockStats.instance;
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final card = settingsCardColor(context);
    final pill = pillColor(context);

    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - DateTime.monday;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final gridStart = firstDay.subtract(Duration(days: leading));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthNames = const <String>[
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    const weekdays = <String>['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    // Cores de estado fixas (vermelho/azul/verde): não variam com o tema
    // porque identificam o mesmo significado (sem uso / bloqueios / uso)
    // em qualquer aparência, tal como na tela original.
    const red = Color(0xFFFF6B61);
    const blue = Color(0xFF45B9F4);
    const green = Color(0xFF7DDA91);

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: appText('back'),
          style: IconButton.styleFrom(
            foregroundColor: text,
            fixedSize: const Size(42, 42),
            shape: const CircleBorder(),
          ),
          icon: const AppSvgIcon(AppIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text('Calendário de bloqueios'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[stats, activityController]),
        builder: (context, _) {
          final navigationDays = activityController.entries
              .where((entry) => entry.kind == ActivityKind.site)
              .map((entry) => AdBlockStats.dateKey(entry.timestamp))
              .toSet();
          final activeDays = navigationDays.where((key) =>
              key.startsWith('${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}-')).length;
          final totalBlocked = List<int>.generate(
            daysInMonth,
            (index) => stats.countForDate(DateTime(_month.year, _month.month, index + 1)),
          ).fold<int>(0, (sum, value) => sum + value);
          final elapsedDays = _month.year == today.year && _month.month == today.month
              ? today.day
              : _month.isBefore(DateTime(today.year, today.month, 1))
                  ? daysInMonth
                  : 0;
          final noNavigationDays = (elapsedDays - activeDays).clamp(0, daysInMonth).toInt();
          final selectedKey = AdBlockStats.dateKey(_selectedDate);
          final selectedNavigation = navigationDays.contains(selectedKey);
          final selectedBlocks = stats.countForDate(_selectedDate);
          final daysWithBlocks = List<bool>.generate(
            daysInMonth,
            (index) => stats.countForDate(DateTime(_month.year, _month.month, index + 1)) > 0,
          ).where((used) => used).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${monthNames[_month.month - 1]} ${_month.year}',
                            style: TextStyle(
                              color: text,
                              fontSize: 19,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.3,
                            ),
                          ),
                        ),
                        _RoundIconButton(
                          icon: Symbols.arrow_back_ios_new_rounded,
                          background: pill,
                          foreground: text,
                          onTap: () => _changeMonth(-1),
                        ),
                        const SizedBox(width: 8),
                        _RoundIconButton(
                          icon: Symbols.arrow_forward_ios_rounded,
                          background: pill,
                          foreground: text,
                          onTap: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: weekdays.map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalCells,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 2,
                        childAspectRatio: .88,
                      ),
                      itemBuilder: (context, index) {
                        final date = gridStart.add(Duration(days: index));
                        final dateOnly = DateTime(date.year, date.month, date.day);
                        final inMonth = date.month == _month.month;
                        final isFuture = dateOnly.isAfter(today);
                        final selected = dateOnly.year == _selectedDate.year &&
                            dateOnly.month == _selectedDate.month &&
                            dateOnly.day == _selectedDate.day;
                        final key = AdBlockStats.dateKey(dateOnly);
                        final navigated = !isFuture && navigationDays.contains(key);
                        final blocked = !isFuture && stats.countForDate(dateOnly) > 0;
                        final noNavigation = !isFuture && !navigated;

                        return InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => setState(() {
                            _selectedDate = dateOnly;
                            if (!inMonth) {
                              _month = DateTime(dateOnly.year, dateOnly.month);
                            }
                          }),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: selected ? accent : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : isFuture
                                            ? muted.withOpacity(.35)
                                            : inMonth
                                                ? text
                                                : muted.withOpacity(.5),
                                    fontSize: 14,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _StatusDot(color: red, active: noNavigation),
                                  const SizedBox(width: 3),
                                  _StatusDot(color: blue, active: blocked),
                                  const SizedBox(width: 3),
                                  _StatusDot(color: green, active: navigated),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(child: _CalendarMetric(label: 'Dias ativos', value: '$activeDays', color: text, labelColor: muted)),
                    _VerticalMetricDivider(color: muted),
                    Expanded(child: _CalendarMetric(label: 'Dias sem uso', value: '$noNavigationDays', color: text, labelColor: muted)),
                    _VerticalMetricDivider(color: muted),
                    Expanded(child: _CalendarMetric(label: 'Bloqueios', value: '$totalBlocked', color: text, labelColor: muted)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _UsageSummaryRow(
                color: green,
                icon: Symbols.language_rounded,
                label: 'Dias com navegação',
                value: '$activeDays / $elapsedDays dias',
                trailing: '${elapsedDays == 0 ? 0 : (activeDays * 100 / elapsedDays).round()}%',
                card: card,
                text: text,
                muted: muted,
              ),
              const SizedBox(height: 10),
              _UsageSummaryRow(
                color: blue,
                icon: Symbols.shield_rounded,
                label: 'Anúncios bloqueados',
                value: '$totalBlocked neste mês',
                trailing: '$daysWithBlocks dias',
                card: card,
                text: text,
                muted: muted,
              ),
              const SizedBox(height: 10),
              _UsageSummaryRow(
                color: red,
                icon: Symbols.event_busy_rounded,
                label: 'Dias sem navegação',
                value: '$noNavigationDays dias',
                trailing: '${elapsedDays == 0 ? 0 : (noNavigationDays * 100 / elapsedDays).round()}%',
                card: card,
                text: text,
                muted: muted,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_shortDate(_selectedDate)} · ${selectedNavigation ? 'Houve navegação' : 'Sem navegação'} · $selectedBlocks anúncios bloqueados',
                      style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _LegendDot(color: red, label: 'Sem navegação', textColor: muted),
                        const SizedBox(width: 16),
                        _LegendDot(color: blue, label: 'Bloqueios', textColor: muted),
                        const SizedBox(width: 16),
                        _LegendDot(color: green, label: 'Navegação', textColor: muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, color: foreground, size: 17),
      ),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(
      color: color.withOpacity(active ? .96 : .18),
      shape: BoxShape.circle,
    ),
  );
}

class _CalendarMetric extends StatelessWidget {
  const _CalendarMetric({required this.label, required this.value, required this.color, required this.labelColor});
  final String label;
  final String value;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: labelColor, fontSize: 10.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
    ],
  );
}

class _VerticalMetricDivider extends StatelessWidget {
  const _VerticalMetricDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    color: color.withOpacity(.18),
  );
}

class _UsageSummaryRow extends StatelessWidget {
  const _UsageSummaryRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
    required this.card,
    required this.text,
    required this.muted,
  });
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String trailing;
  final Color card;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withOpacity(.16), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(width: 8),
        Text(trailing, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, required this.textColor});
  final Color color;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: textColor, fontSize: 10.5, fontWeight: FontWeight.w600)),
  ]);
}