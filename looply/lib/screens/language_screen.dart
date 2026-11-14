import 'package:material_ui/material_ui.dart';
import 'package:m3e_buttons/m3e_buttons.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';

import '../localization.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: M3EButton(
            tooltip: appText('back'),
            onPressed: () => Navigator.of(context).maybePop(),
            style: M3EButtonStyle.tonal,
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            decoration: M3EButtonDecoration.styleFrom(
              backgroundColor: pillColor(context),
              foregroundColor: text,
              minimumSize: const Size(42, 42),
              fixedSize: const Size(42, 42),
              padding: EdgeInsets.zero,
              borderRadius: 21,
              pressedRadius: 15,
              motion: M3EMotion.expressiveSpatialDefault,
              haptic: M3EHapticFeedback.light,
            ),
            child: AppMaterialIcon(AppIcons.arrowLeft, color: text, size: 20),
          ),
        ),
        title: Text(appText('select_language')),
        backgroundColor: pageBg(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ValueListenableBuilder<AppLanguage>(
        valueListenable: appLanguageController,
        builder: (context, selected, _) => ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            M3ESegmentedColumn(
              color: settingsCardColor(context),
              outerRadius: 22,
              innerRadius: 8,
              gap: 3,
              padding: EdgeInsets.zero,
              onTap: (index) {
                appLanguageController.select(supportedAppLanguages[index]);
                Navigator.of(context).maybePop();
              },
              children: [
                for (final language in supportedAppLanguages)
                  M3EListItem(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: pillColor(context),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AppMaterialIcon(AppIcons.globe, color: text, size: 19),
                    ),
                    headline: Text(
                      language.nativeName,
                      style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    supportingText: Text(
                      language.name,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    trailing: language.code == selected.code
                        ? AppMaterialIcon(AppIcons.checkCircle, color: accentColor(context))
                        : AppMaterialIcon(AppIcons.circle, color: muted),
                    minHeight: 72,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
