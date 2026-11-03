import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';

class AdBlockCalendarScreen extends StatefulWidget {
  const AdBlockCalendarScreen({super.key});

  @override
  State<AdBlockCalendarScreen> createState() => _AdBlockCalendarScreenState();
}

class _AdBlockCalendarScreenState extends State<AdBlockCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  static const Color _calendarSurface = Color(0xFF070809);
  static const Color _rowSurface = Color(0xFF191B1E);
  static const Color _red = Color(0xFFFF6B61);
  static const Color _blue = Color(0xFF45B9F4);
  static const Color _green = Color(0xFF7DDA91);

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
    final pageMuted = mutedText(context);
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
    const weekdays = <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: const Text('Calendário de bloqueios'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Symbols.arrow_left),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
                padding: const EdgeInsets.fromLTRB(25, 23, 25, 22),
                decoration: BoxDecoration(
                  color: _calendarSurface,
                  borderRadius: BorderRadius.circular(42),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Monthly usage',
                            style: TextStyle(
                              color: Color(0xFFF2F2F3),
                              fontSize: 22,
                              height: 1.1,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        Material(
                          color: const Color(0xFF17191C),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _changeMonth(1),
                            child: const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(Symbols.arrow_forward_rounded, color: Color(0xFFD7D9DC), size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 29),
                    Row(
                      children: weekdays.map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: Color(0xFF777A7F),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalCells,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 11,
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
                                duration: const Duration(milliseconds: 150),
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFF292C30) : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: isFuture
                                        ? const Color(0xFF55585D)
                                        : inMonth
                                            ? const Color(0xFFF0F1F2)
                                            : const Color(0xFF66696D),
                                    fontSize: 14,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _StatusDot(color: _red, active: noNavigation),
                                  const SizedBox(width: 3),
                                  _StatusDot(color: _blue, active: blocked),
                                  const SizedBox(width: 3),
                                  _StatusDot(color: _green, active: navigated),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 29),
                    Row(
                      children: [
                        Expanded(child: _CalendarMetric(label: 'Dias ativos', value: '$activeDays')),
                        _VerticalMetricDivider(),
                        Expanded(child: _CalendarMetric(label: 'Dias sem uso', value: '$noNavigationDays')),
                        _VerticalMetricDivider(),
                        Expanded(child: _CalendarMetric(label: 'Bloqueios', value: '$totalBlocked')),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _UsageSummaryRow(
                      color: _green,
                      icon: Symbols.language_rounded,
                      label: 'Dias com navegação',
                      value: '$activeDays / $elapsedDays dias',
                      trailing: '${elapsedDays == 0 ? 0 : (activeDays * 100 / elapsedDays).round()}%',
                    ),
                    const SizedBox(height: 10),
                    _UsageSummaryRow(
                      color: _blue,
                      icon: Symbols.shield_rounded,
                      label: 'Anúncios bloqueados',
                      value: '$totalBlocked neste mês',
                      trailing: '$daysWithBlocks dias',
                    ),
                    const SizedBox(height: 10),
                    _UsageSummaryRow(
                      color: _red,
                      icon: Symbols.event_busy_rounded,
                      label: 'Dias sem navegação',
                      value: '$noNavigationDays dias',
                      trailing: '${elapsedDays == 0 ? 0 : (noNavigationDays * 100 / elapsedDays).round()}%',
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 13),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFF26282C), width: .8)),
                      ),
                      child: Text(
                        '${_shortDate(_selectedDate)} · ${selectedNavigation ? 'Houve navegação' : 'Sem navegação'} · $selectedBlocks anúncios bloqueados',
                        style: const TextStyle(color: Color(0xFF85888D), fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _LegendDot(color: _red, label: 'Sem navegação'),
                  const SizedBox(width: 16),
                  _LegendDot(color: _blue, label: 'Anúncios bloqueados'),
                  const SizedBox(width: 16),
                  _LegendDot(color: _green, label: 'Navegação'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${monthNames[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.end,
                style: TextStyle(color: pageMuted.withOpacity(.7), fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }
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
      color: color.withOpacity(active ? .96 : .20),
      shape: BoxShape.circle,
    ),
  );
}

class _CalendarMetric extends StatelessWidget {
  const _CalendarMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF777A7F), fontSize: 10.5)),
      const SizedBox(height: 5),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF0F1F2), fontSize: 14, fontWeight: FontWeight.w500)),
    ],
  );
}

class _VerticalMetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 44,
    color: const Color(0xFF292B2F),
    margin: const EdgeInsets.symmetric(horizontal: 5),
  );
}

class _UsageSummaryRow extends StatelessWidget {
  const _UsageSummaryRow({required this.color, required this.icon, required this.label, required this.value, required this.trailing});
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(color: _AdBlockCalendarScreenState._rowSurface, borderRadius: BorderRadius.circular(32)),
    child: Row(
      children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFF101113), size: 21)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF909399), fontSize: 12)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE5E6E8), fontSize: 14, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(width: 8),
        Text(trailing, style: const TextStyle(color: Color(0xFF9A9DA2), fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF888B90), fontSize: 9.5))),
    ]),
  );
}
