import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../localization.dart';
import '../theme.dart';
import '../widgets/svg_icon.dart';

// Tela simples de informações do app, aberta a partir do botão de
// informação na appbar da Settings. Usa o mesmo appbar com fade
// sólido-em-cima / transparente-embaixo das outras telas internas.
class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(20, topInset + 72, 20, 24),
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/images/looply_icon.png', width: 76, height: 76, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'BrowseIt',
                textAlign: TextAlign.center,
                style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data == null
                      ? '...'
                      : '${appText('version')} ${snapshot.data!.version} (${snapshot.data!.buildNumber})';
                  return Text(version, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13));
                },
              ),
              const SizedBox(height: 28),
              Material(
                color: settingsCardColor(context),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    appText('about_app_text'),
                    style: TextStyle(color: text, fontSize: 13.5, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FadeAppBar(
              topInset: topInset,
              leading: _CircleBarButton(
                icon: AppIcons.caretLeft,
                tooltip: appText('back'),
                onTap: () => Navigator.of(context).maybePop(),
              ),
              title: appText('app_info'),
            ),
          ),
        ],
      ),
    );
  }
}

// Appbar flutuante com gradiente: sólido perto do topo da safe area,
// esvaindo para transparente na base da própria barra. Reutilizado
// (copie para um widgets/fade_app_bar.dart se preferir compartilhar).
class _FadeAppBar extends StatelessWidget {
  const _FadeAppBar({required this.topInset, required this.leading, this.title, this.actions});

  final double topInset;
  final Widget leading;
  final String? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    return Container(
      padding: EdgeInsets.only(top: topInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg, bg.withOpacity(0.0)],
          stops: const [0.0, 0.55, 1.0],
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ] else
                const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBarButton extends StatelessWidget {
  const _CircleBarButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: pillColor(context),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: AppSvgIcon(icon, size: 19, color: muted)),
        ),
      ),
    );
  }
}