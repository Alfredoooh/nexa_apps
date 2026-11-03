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

  static const Color _usedTone = Color(0xFF49A97A);
  static const Color _unusedTone = Color(0xFFD8757D);

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final stats = AdBlockStats.instance;
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final monthNames = const <String>[
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    const weekdayLabels = <String>['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: const Text('Calendário de bloqueios'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Symbols.arrow_left_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: stats,
        builder: (context, _) {
          final totalMonth = List<int>.generate(
            daysInMonth,
            (index) => stats.countForDate(DateTime(_month.year, _month.month, index + 1)),
          ).fold<int>(0, (sum, value) => sum + value);
          final usedDays = List<bool>.generate(
            daysInMonth,
            (index) {
              final date = DateTime(_month.year, _month.month, index + 1);
              final dateOnly = DateTime(date.year, date.month, date.day);
              return !dateOnly.isAfter(todayOnly) && stats.wasUsedOn(date);
            },
          ).where((used) => used).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
                decoration: BoxDecoration(
                  color: settingsCardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: lineColor(context).withOpacity(dark ? .72 : .85)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(dark ? .15 : .09),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Symbols.shield_rounded, color: accent, size: 21),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${monthNames[_month.month - 1]} ${_month.year}',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$usedDays ${usedDays == 1 ? 'dia de utilização' : 'dias de utilização'}',
                                style: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        _MonthArrowButton(
                          tooltip: 'Mês anterior',
                          icon: Symbols.arrow_left_rounded,
                          onPressed: () => _changeMonth(-1),
                        ),
                        const SizedBox(width: 6),
                        _MonthArrowButton(
                          tooltip: 'Mês seguinte',
                          icon: Symbols.arrow_right_rounded,
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 23),
                    Row(
                      children: weekdayLabels
                          .map(
                            (day) => Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    color: muted.withOpacity(.82),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .45,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalCells,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 5,
                        childAspectRatio: .80,
                      ),
                      itemBuilder: (context, index) {
                        final dayNumber = index - leading + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox.shrink();
                        }

                        final date = DateTime(_month.year, _month.month, dayNumber);
                        final dateOnly = DateTime(date.year, date.month, date.day);
                        final isFuture = dateOnly.isAfter(todayOnly);
                        final isToday = dateOnly == todayOnly;
                        final count = stats.countForDate(date);
                        final wasUsed = !isFuture && stats.wasUsedOn(date);
                        final tone = wasUsed ? _usedTone : _unusedTone;
                        final fillOpacity = dark ? (wasUsed ? .16 : .105) : (wasUsed ? .105 : .075);
                        final borderOpacity = dark ? .28 : .20;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isFuture
                                ? pillColor(context).withOpacity(dark ? .34 : .60)
                                : tone.withOpacity(fillOpacity),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: isToday
                                  ? accent.withOpacity(.85)
                                  : isFuture
                                      ? lineColor(context).withOpacity(.48)
                                      : tone.withOpacity(borderOpacity),
                              width: isToday ? 1.35 : .8,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  color: isFuture
                                      ? muted.withOpacity(.40)
                                      : wasUsed
                                          ? _usedTone
                                          : _unusedTone.withOpacity(.94),
                                  fontSize: 12,
                                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (count > 0 && !isFuture)
                                Text(
                                  count > 999 ? '999+' : '$count',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: _usedTone.withOpacity(.96),
                                    fontSize: 8,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              else
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFuture
                                        ? muted.withOpacity(.20)
                                        : tone.withOpacity(.72),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 17),
                    Wrap(
                      spacing: 14,
                      runSpacing: 9,
                      children: [
                        _CalendarLegend(color: _usedTone, label: 'Usado'),
                        _CalendarLegend(color: _unusedTone, label: 'Sem uso'),
                        _CalendarLegend(color: muted.withOpacity(.55), label: 'Futuro'),
                      ],
                    ),
                    const SizedBox(height: 17),
                    Container(height: 1, color: lineColor(context).withOpacity(.72)),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Anúncios bloqueados neste mês',
                            style: TextStyle(color: muted, fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          totalMonth.toString(),
                          style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  'Verde indica dias em que o Looply foi utilizado. Vermelho suave assinala dias sem utilização. O número dentro de cada data mostra os anúncios bloqueados.',
                  style: TextStyle(color: muted, fontSize: 11.5, height: 1.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  const _MonthArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pillColor(context),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 19, color: mainText(context)),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(.78),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: mutedText(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
