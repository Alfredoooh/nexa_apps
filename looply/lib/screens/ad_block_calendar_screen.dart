import 'package:flutter/cupertino.dart';
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

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final stats = AdBlockStats.instance;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - 1; // Semana começa na segunda-feira.
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final monthNames = const <String>[
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    final totalMonth = List<int>.generate(
      daysInMonth,
      (index) => stats.countForDate(DateTime(_month.year, _month.month, index + 1)),
    ).fold<int>(0, (sum, value) => sum + value);
    const weekdayLabels = <String>['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        title: const Text('Calendário de bloqueios'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Symbols.shield_rounded, color: accent, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${monthNames[_month.month - 1]} ${_month.year}',
                        style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mês anterior',
                      onPressed: () => _changeMonth(-1),
                      icon: Icon(Symbols.chevron_left_rounded, color: text),
                    ),
                    IconButton(
                      tooltip: 'Mês seguinte',
                      onPressed: () => _changeMonth(1),
                      icon: Icon(Symbols.chevron_right_rounded, color: text),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: weekdayLabels
                      .map((day) => Expanded(child: Center(child: Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)))))
                      .toList(),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: stats,
                  builder: (context, _) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: totalCells,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 5,
                      childAspectRatio: .78,
                    ),
                    itemBuilder: (context, index) {
                      final dayNumber = index - leading + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
                      final date = DateTime(_month.year, _month.month, dayNumber);
                      final isFuture = DateTime(date.year, date.month, date.day)
                          .isAfter(DateTime(today.year, today.month, today.day));
                      final count = stats.countForDate(date);
                      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                      final hasCount = count > 0;
                      return Container(
                        decoration: BoxDecoration(
                          color: hasCount
                              ? accent.withOpacity(isFuture ? .06 : .17)
                              : pillColor(context).withOpacity(isFuture ? .30 : .66),
                          borderRadius: BorderRadius.circular(11),
                          border: isToday ? Border.all(color: accent, width: 1.4) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isFuture ? muted.withOpacity(.35) : text,
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (hasCount && !isFuture)
                              Text(
                                '$count',
                                style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w800),
                              )
                            else
                              const SizedBox(height: 11),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: Text('Total neste mês', style: TextStyle(color: muted, fontSize: 12))),
                    Text('$totalMonth', style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Os dias futuros permanecem inativos. Os números mostram anúncios bloqueados em cada dia.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
