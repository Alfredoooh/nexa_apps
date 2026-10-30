import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import 'activity_screen.dart';

// Tela de histórico completo — acessível via "Ver tudo" na tela de
// Atividade e via opção "Histórico" no drawer.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() { super.initState(); activityController.addListener(_onChanged); }
  @override
  void dispose() { activityController.removeListener(_onChanged); super.dispose(); }
  void _onChanged() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final entries = activityController.entries;

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('Histórico'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(tooltip: 'Limpar histórico', icon: Icon(Symbols.delete_sweep_rounded, color: text), onPressed: activityController.clear),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Symbols.history_rounded, size: 48, color: muted), const SizedBox(height: 12), Text('Sem histórico', style: TextStyle(color: text, fontWeight: FontWeight.w700))]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final isFirst = index == 0;
                final isLast = index == entries.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
                  child: ActivityTile(
                    entry: entries[index],
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(isFirst ? 22 : 8),
                      bottom: Radius.circular(isLast ? 22 : 8),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
