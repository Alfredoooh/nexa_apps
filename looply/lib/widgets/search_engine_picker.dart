import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';

void showSearchEnginePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    useSafeArea: true,
    builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => Material(
        color: panelForMode(context, mode),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: mutedForMode(context, mode).withOpacity(.45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    appText('search_engine'),
                    style: TextStyle(color: textForMode(context, mode), fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              ...searchEngines.map((engine) => ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: pillForMode(context, mode)),
                      child: Image.network(
                        engine.faviconUrl, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Symbols.public_rounded, color: mutedForMode(context, mode), size: 18),
                      ),
                    ),
                    title: Text(engine.name, style: TextStyle(color: textForMode(context, mode))),
                    trailing: ValueListenableBuilder<SearchEngine>(
                      valueListenable: activeSearchEngine,
                      builder: (_, active, __) => active.name == engine.name
                          ? Icon(Symbols.check_circle_rounded, color: accentForMode(context, mode), fill: 1)
                          : const SizedBox.shrink(),
                    ),
                    onTap: () {
                      activeSearchEngine.select(engine);
                      Navigator.of(sheetContext).pop();
                    },
                  )),
            ],
          ),
        ),
      ),
    ),
  );
}
