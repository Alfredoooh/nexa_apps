import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import 'material_symbols.dart';
import 'search_engine_pngs.dart';

void showSearchEnginePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    useSafeArea: true,
    isScrollControlled: true,
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
                    style: TextStyle(
                      color: textForMode(context, mode),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // A pesquisa com IA é um motor seleccionável, mas não substitui
              // nem altera o motor web guardado pelo utilizador.
              ValueListenableBuilder<bool>(
                valueListenable: aiSearchModeEnabled,
                builder: (context, aiEnabled, _) => ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pillForMode(context, mode),
                    ),
                    child: Image.memory(
                      searchEnginePng('AI Search')!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                  title: Text(
                    appText('ai_mode'),
                    style: TextStyle(color: textForMode(context, mode)),
                  ),
                  subtitle: Text(
                    'Pesquisa na tela de inteligência artificial',
                    style: TextStyle(
                      color: mutedForMode(context, mode),
                      fontSize: 12,
                    ),
                  ),
                  trailing: aiEnabled
                      ? AppMaterialIcon(
                          AppIcons.checkCircle,
                          color: accentForMode(context, mode),
                          size: 21,
                        )
                      : const SizedBox.shrink(),
                  onTap: () {
                    aiSearchModeEnabled.value = true;
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
              Divider(height: 1, color: lineColor(context)),
              ...searchEngines.map(
                (engine) => ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pillForMode(context, mode),
                    ),
                    child: Image.memory(
                      searchEnginePng(engine.name) ?? searchEnginePng('Google')!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      cacheWidth: 80,
                      cacheHeight: 80,
                    ),
                  ),
                  title: Text(
                    engine.name,
                    style: TextStyle(color: textForMode(context, mode)),
                  ),
                  trailing: ValueListenableBuilder<SearchEngine>(
                    valueListenable: activeSearchEngine,
                    builder: (_, active, __) => ValueListenableBuilder<bool>(
                      valueListenable: aiSearchModeEnabled,
                      builder: (_, isAiEnabled, __) => !isAiEnabled &&
                              active.name == engine.name
                          ? AppMaterialIcon(
                              AppIcons.checkCircle,
                              color: accentForMode(context, mode),
                              size: 21,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  onTap: () {
                    activeSearchEngine.select(engine);
                    aiSearchModeEnabled.value = false;
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
