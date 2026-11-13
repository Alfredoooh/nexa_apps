import 'package:flutter/material.dart';
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
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: pageBg(context),
      body: Stack(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? '…'
                  : '${info.version} (${info.buildNumber})';
              return ListView(
                padding: EdgeInsets.fromLTRB(18, topInset + 76, 18, 30),
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/looply_icon.png',
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'BrowseIt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: text,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${appText('version')} $version',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 26),
                  _SectionHeading(title: appText('app_info')),
                  const SizedBox(height: 9),
                  _InfoCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        appText('about_app_text'),
                        style: TextStyle(color: text, fontSize: 13.5, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeading(title: appText('general')),
                  const SizedBox(height: 9),
                  _InfoCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FeatureChip(icon: AppIcons.browser, label: appText('tabs')),
                          _FeatureChip(icon: AppIcons.clockCounterClockwise, label: appText('history')),
                          _FeatureChip(icon: AppIcons.downloadSimple, label: appText('downloads')),
                          _FeatureChip(icon: AppIcons.bookmarkSimple, label: appText('bookmarks')),
                          _FeatureChip(icon: AppIcons.magnifyingGlass, label: appText('search')),
                          _FeatureChip(icon: AppIcons.shield, label: appText('ad_blocker')),
                          _FeatureChip(icon: AppIcons.palette, label: appText('theme')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeading(title: appText('navigation_security')),
                  const SizedBox(height: 9),
                  _InfoCard(
                    child: Column(
                      children: [
                        _AboutActionRow(
                          icon: AppIcons.shieldCheck,
                          label: appText('privacy_policy'),
                          subtitle: appText('privacy_policy_subtitle'),
                          onTap: () => _showLegalText(
                            context, appText('privacy_policy'), appText('about_privacy_text'),
                          ),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: lineColor(context)),
                        _AboutActionRow(
                          icon: AppIcons.info,
                          label: appText('terms_of_use'),
                          subtitle: appText('terms_of_use_subtitle'),
                          onTap: () => _showLegalText(
                            context, appText('terms_of_use'), appText('about_terms_text'),
                          ),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: lineColor(context)),
                        _AboutActionRow(
                          icon: AppIcons.bookmarksSimple,
                          label: appText('open_source_licenses'),
                          subtitle: appText('open_source_licenses_subtitle'),
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'BrowseIt',
                            applicationVersion: version,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'BrowseIt',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted.withOpacity(.7), fontSize: 11),
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FadeAppBar(
              topInset: topInset,
              leading: AppBackButton(
                tooltip: appText('back'),
                color: text,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: appText('app_info'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showLegalText(BuildContext context, String title, String body) {
  return showLooplyDialog<void>(
    context: context,
    title: title,
    content: SelectableText(body),
    actions: <LooplyDialogAction<void>>[
      LooplyDialogAction<void>(label: appText('close'), value: null, isPrimary: true),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(
          title,
          style: TextStyle(color: mainText(context), fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(21),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: pillColor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMaterialIcon(icon, color: mutedText(context), size: 16),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: mainText(context), fontSize: 11.5)),
          ],
        ),
      );
}

class _AboutActionRow extends StatelessWidget {
  const _AboutActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              AppMaterialIcon(icon, color: mutedText(context), size: 20),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: mainText(context), fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
                  ],
                ),
              ),
              AppMaterialIcon(AppIcons.caretRight, color: mutedText(context), size: 18),
            ],
          ),
        ),
      );
}

class _FadeAppBar extends StatelessWidget {
  const _FadeAppBar({required this.topInset, required this.leading, this.title});
  final double topInset;
  final Widget leading;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg, bg.withOpacity(0)],
          stops: const [0, .55, 1],
        ),
      ),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              leading,
              if (title != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: mainText(context), fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
