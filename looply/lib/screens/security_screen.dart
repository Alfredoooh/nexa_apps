import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../security/browser_security_service.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';
import '../widgets/m3_switch.dart';
import 'blocked_sites_screen.dart';

/// Browser security is protected by the Android device credential / biometrics.
/// No app-specific PIN or password is created.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _checking = true;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticateEntry());
    BrowserSecurityService.restore();
  }

  Future<void> _authenticateEntry() async {
    final available = await BrowserSecurityService.canAuthenticateDevice();
    if (!mounted) return;
    if (!available) {
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure primeiro um bloqueio de ecrã no Android para usar esta área.')),
      );
      Navigator.of(context).maybePop();
      return;
    }
    final verified = await BrowserSecurityService.authenticateDevice(
      reason: 'Autenticar para abrir a segurança do Looply',
    );
    if (!mounted) return;
    setState(() { _authorized = verified; _checking = false; });
    if (!verified) Navigator.of(context).maybePop();
  }

  Future<void> _openBlockedSites() async {
    // This route is already inside the authenticated Security screen. Do not
    // show a second system prompt for the same visit.
    if (!_authorized || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute<void>(builder: (_) => const BlockedSitesScreen()),
    );
  }

  Future<void> _togglePasswordSaving(bool enabled) async {
    if (enabled) {
      final verified = await BrowserSecurityService.authenticateDevice(
        reason: 'Confirmar para ativar a gestão de palavras-passe',
      );
      if (!verified) return;
    }
    await BrowserSecurityService.setPasswordSavingEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: AppBackButton(tooltip: appText('back'), color: text),
        title: Text(appText('security_title'), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _checking
            ? Center(child: CircularProgressIndicator(color: accentColor(context), strokeWidth: 2.2))
          : !_authorized
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    Container(
                      decoration: BoxDecoration(color: settingsCardColor(context), borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        children: [
                          _SecurityTile(
                            icon: AppIcons.shieldCheck,
                            label: 'Proteção do dispositivo',
                            subtitle: 'Usa o PIN, padrão, palavra-passe ou biometria configurada no Android.',
                            showChevron: false,
                          ),
                          Divider(height: 1, indent: 58, endIndent: 14, color: lineColor(context)),
                          _SecurityTile(
                            icon: AppIcons.shield,
                            label: appText('blocked_sites'),
                            subtitle: appText('blocked_sites_description'),
                            onTap: _openBlockedSites,
                          ),
                          Divider(height: 1, indent: 58, endIndent: 14, color: lineColor(context)),
                          ValueListenableBuilder<bool>(
                            valueListenable: BrowserSecurityService.passwordSavingEnabled,
                            builder: (context, enabled, _) => _SecurityTile(
                              icon: AppIcons.lockSimple,
                              label: appText('save_passwords'),
                              subtitle: appText('save_passwords_description'),
                              trailing: M3ExpressiveSwitch(value: enabled, onChanged: _togglePasswordSaving),
                              showChevron: false,
                              onTap: () => _togglePasswordSaving(!enabled),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('A autenticação é sempre confirmada pelo próprio Android. O Looply não guarda outro PIN.',
                        style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon, required this.label, this.subtitle, this.trailing,
    this.showChevron = true, this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        canRequestFocus: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 52 : 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                  alignment: Alignment.center, child: AppMaterialIcon(icon, color: text, size: 19)),
                const SizedBox(width: 10),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 11.5, height: 1.2))],
                  ])),
                if (trailing != null) trailing!,
                if (showChevron) ...[const SizedBox(width: 6), AppMaterialIcon(AppIcons.caretRight, color: muted, size: 18)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
