import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../localization.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';
import '../widgets/looply_dialog.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        backgroundColor: pageBg(context),
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        leading: AppBackButton(
          tooltip: appText('back'),
          color: text,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(appText('app_info'), style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info == null ? '…' : '${info.version} (${info.buildNumber})';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: accentColor(context).withOpacity(.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: AppMaterialIcon(AppIcons.browser, color: accentColor(context), size: 38),
                ),
              ),
              const SizedBox(height: 15),
              Text('BrowseIt', textAlign: TextAlign.center,
                  style: TextStyle(color: text, fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('${appText('version')} $version', textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 12.5)),
              const SizedBox(height: 22),
              Text(appText('about_app_text'), textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 13, height: 1.55)),
              const SizedBox(height: 28),
              Material(
                color: settingsCardColor(context),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _AboutRow(
                      icon: AppIcons.shieldCheck,
                      title: appText('privacy_policy'),
                      onTap: () => _showLegal(context, appText('privacy_policy'), appText('about_privacy_text')),
                    ),
                    Divider(height: 1, indent: 54, endIndent: 16, color: lineColor(context)),
                    _AboutRow(
                      icon: AppIcons.info,
                      title: appText('terms_of_use'),
                      onTap: () => _showLegal(context, appText('terms_of_use'), appText('about_terms_text')),
                    ),
                    Divider(height: 1, indent: 54, endIndent: 16, color: lineColor(context)),
                    _AboutRow(
                      icon: AppIcons.bookmarksSimple,
                      title: appText('open_source_licenses'),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'BrowseIt',
                        applicationVersion: version,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text('BrowseIt', textAlign: TextAlign.center,
                  style: TextStyle(color: muted.withOpacity(.65), fontSize: 11)),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showLegal(BuildContext context, String title, String body) {
  return showLooplyDialog<void>(
    context: context,
    title: title,
    content: SelectableText(body),
    actions: <LooplyDialogAction<void>>[
      LooplyDialogAction<void>(label: appText('close'), value: null, isPrimary: true),
    ],
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: AppMaterialIcon(icon, color: mutedText(context), size: 20),
        title: Text(title, style: TextStyle(color: mainText(context), fontSize: 13.5, fontWeight: FontWeight.w600)),
        trailing: AppMaterialIcon(AppIcons.caretRight, color: mutedText(context), size: 17),
      );
}
