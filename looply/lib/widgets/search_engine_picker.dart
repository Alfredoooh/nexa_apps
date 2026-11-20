import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import 'material_symbols.dart';
import 'search_engine_pngs.dart';
import 'looply_dialog.dart';

void showSearchEnginePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => LooplyModalSystemBar(
      child: LooplyFloatingModalFrame(
        child: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        final surface = panelForMode(context, mode);
        final text = textForMode(context, mode);
        final muted = mutedForMode(context, mode);
        final accent = accentForMode(context, mode);
        Widget engineLogo(String name) => Image.asset(
              searchEngineAsset(name),
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => AppMaterialIcon(AppIcons.compass, color: muted, size: 24),
            );

        return Material(
          color: surface,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(28),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .82,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: muted.withOpacity(.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          appText('search_engine'),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    // A pesquisa com IA é uma opção de pesquisa independente
                    // do motor web guardado nas definições.
                    ValueListenableBuilder<bool>(
                      valueListenable: aiSearchModeEnabled,
                      builder: (context, aiEnabled, _) => ListTile(
                        minLeadingWidth: 42,
                        leading: Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pillForMode(context, mode),
                          ),
                          child: Center(child: engineLogo('AI Search')),
                        ),
                        title: Text(
                          appText('ai_mode'),
                          style: TextStyle(color: text, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          appText('ai_search_description'),
                          style: TextStyle(color: muted, fontSize: 12, height: 1.3),
                        ),
                        trailing: aiEnabled
                            ? AppMaterialIcon(AppIcons.checkCircle, color: accent, size: 24)
                            : const SizedBox(width: 24),
                        onTap: () {
                          aiSearchModeEnabled.value = true;
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                    Divider(height: 1, color: lineColor(context)),
                    for (final engine in searchEngines)
                      ListTile(
                        minLeadingWidth: 42,
                        leading: Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pillForMode(context, mode),
                          ),
                          child: Center(
                            child: engineLogo(engine.name),
                          ),
                        ),
                        title: Text(
                          engine.name,
                          style: TextStyle(color: text, fontWeight: FontWeight.w500),
                        ),
                        trailing: ValueListenableBuilder<SearchEngine>(
                          valueListenable: activeSearchEngine,
                          builder: (_, active, __) => ValueListenableBuilder<bool>(
                            valueListenable: aiSearchModeEnabled,
                            builder: (_, isAiEnabled, __) => !isAiEnabled && active.name == engine.name
                                ? AppMaterialIcon(AppIcons.checkCircle, color: accent, size: 24)
                                : const SizedBox(width: 24),
                          ),
                        ),
                        onTap: () {
                          activeSearchEngine.select(engine);
                          aiSearchModeEnabled.value = false;
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      ),
    ),
    ),
  );
}