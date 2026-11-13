import 'package:flutter/material.dart';

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
        leading: IconButton(
          tooltip: appText('back'),
          onPressed: () => Navigator.of(context).maybePop(),
          style: IconButton.styleFrom(
            foregroundColor: text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          icon: AppMaterialIcon(AppIcons.arrowLeft, color: text),
        ),
        title: Text(appText('select_language')),
        backgroundColor: pageBg(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ValueListenableBuilder<AppLanguage>(
        valueListenable: appLanguageController,
        builder: (context, selected, _) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          itemCount: supportedAppLanguages.length,
          itemBuilder: (context, index) {
            final language = supportedAppLanguages[index];
            final isSelected = language.code == selected.code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: settingsCardColor(context),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(index == 0 ? 21 : 8),
                  bottom: Radius.circular(index == supportedAppLanguages.length - 1 ? 21 : 8),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () {
                    appLanguageController.select(language);
                    Navigator.of(context).maybePop();
                  },
                  title: Text(language.nativeName, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                  subtitle: Text(language.name, style: TextStyle(color: muted, fontSize: 12)),
                  trailing: isSelected
                      ? AppMaterialIcon(AppIcons.checkCircle, color: accentColor(context))
                      : AppMaterialIcon(AppIcons.circle, color: muted),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
