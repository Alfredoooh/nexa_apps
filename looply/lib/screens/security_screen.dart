import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../security/browser_security_service.dart';
import '../theme.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/m3_switch.dart';
import '../widgets/material_symbols.dart';
import 'blocked_sites_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _credentialConfigured = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    BrowserSecurityService.restore();
    _refreshCredentialState();
  }

  Future<void> _refreshCredentialState() async {
    final configured = await BrowserSecurityService.hasCredential();
    if (!mounted) return;
    setState(() {
      _credentialConfigured = configured;
      _loading = false;
    });
  }

  Future<bool> _configureCredential() async {
    if (_credentialConfigured || await BrowserSecurityService.hasCredential()) {
      final oldMode = await BrowserSecurityService.credentialMode();
      final oldController = TextEditingController();
      final verified = await showLooplyDialog<bool>(
        context: context,
        title: appText('verify_existing_protection'),
        icon: AppIcons.shieldCheck,
        content: TextField(
          controller: oldController,
          autofocus: true,
          obscureText: true,
          keyboardType: oldMode == 'pin' ? TextInputType.number : TextInputType.visiblePassword,
          decoration: InputDecoration(labelText: oldMode == 'pin' ? appText('current_pin') : appText('current_password')),
        ),
        actions: <LooplyDialogAction<bool>>[
          LooplyDialogAction<bool>(label: appText('cancel'), value: false),
          LooplyDialogAction<bool>(label: appText('continue'), value: true, isPrimary: true),
        ],
      );
      final oldSecret = oldController.text;
      oldController.dispose();
      if (verified != true || !mounted) return false;
      final isValid = await BrowserSecurityService.verifyCredential(oldSecret);
      if (!isValid) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText('protection_incorrect'))) ,
        );
        return false;
      }
    }

    final modeController = ValueNotifier<String>('pin');
    final secretController = TextEditingController();
    final confirmController = TextEditingController();
    var visible = false;

    final accepted = await showLooplyDialog<bool>(
      context: context,
      title: appText('configure_protection'),
      icon: AppIcons.shieldCheck,
      content: StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appText('choose_protection_help'),
                style: TextStyle(color: mutedText(dialogContext), fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            ValueListenableBuilder<String>(
              valueListenable: modeController,
              builder: (context, mode, _) => SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(value: 'pin', label: Text(appText('pin'))),
                  ButtonSegment<String>(value: 'password', label: Text(appText('password'))),
                ],
                selected: <String>{mode},
                onSelectionChanged: (selection) {
                  modeController.value = selection.first;
                  secretController.clear();
                  confirmController.clear();
                },
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: modeController,
              builder: (context, mode, _) => TextField(
                controller: secretController,
                obscureText: !visible,
                keyboardType: mode == 'pin' ? TextInputType.number : TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                maxLength: mode == 'pin' ? 12 : 64,
                decoration: InputDecoration(
                  labelText: mode == 'pin' ? appText('pin_format_hint') : appText('password_format_hint'),
                  counterText: '',
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => visible = !visible),
                    icon: AppMaterialIcon(visible ? AppIcons.eyeSlash : AppIcons.eye),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: appText('confirm_protection')),
            ),
          ],
        ),
      ),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('save'), value: true, isPrimary: true),
      ],
    );

    if (accepted != true || !mounted) {
      modeController.dispose();
      secretController.dispose();
      confirmController.dispose();
      return false;
    }

    final mode = modeController.value;
    final secret = secretController.text;
    final confirmed = confirmController.text;
    final valid = mode == 'pin'
        ? RegExp(r'^\d{4,12}$').hasMatch(secret)
        : secret.length >= 8 && secret.length <= 64;

    if (!valid || secret != confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText('protection_invalid'))) ,
      );
      modeController.dispose();
      secretController.dispose();
      confirmController.dispose();
      return false;
    }

    try {
      await BrowserSecurityService.setCredential(mode: mode, secret: secret);
      await _refreshCredentialState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText('protection_saved'))) ,
        );
      }
      modeController.dispose();
      secretController.dispose();
      confirmController.dispose();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appText('protection_save_failed')} $error')),
        );
      }
      modeController.dispose();
      secretController.dispose();
      confirmController.dispose();
      return false;
    }
  }

  Future<void> _openBlockedSites() async {
    final configured = _credentialConfigured || await BrowserSecurityService.hasCredential();
    if (!mounted) return;
    if (!configured) {
      final saved = await _configureCredential();
      if (!saved || !mounted) return;
    }
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BlockedSitesScreen()),
    );
  }

  Future<void> _togglePasswordSaving(bool enabled) async {
    if (enabled && !_credentialConfigured) {
      final saved = await _configureCredential();
      if (!saved || !mounted) return;
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
        title: Text(appText('security_title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Material(
            color: settingsCardColor(context),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: AppMaterialIcon(AppIcons.shieldCheck, color: accentColor(context)),
              title: Text(appText('security_credential_title'), style: TextStyle(color: text, fontWeight: FontWeight.w600)),
              subtitle: Text(_loading ? appText('security_verifying') : _credentialConfigured ? appText('protection_configured') : appText('protection_not_configured'),
                  style: TextStyle(color: muted, fontSize: 12)),
              trailing: AppMaterialIcon(AppIcons.caretRight, color: muted),
              onTap: _configureCredential,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: settingsCardColor(context),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: AppMaterialIcon(AppIcons.shield, color: accentColor(context)),
              title: Text(appText('blocked_sites'), style: TextStyle(color: text, fontWeight: FontWeight.w600)),
              subtitle: Text(appText('blocked_sites_description'), style: TextStyle(color: muted, fontSize: 12)),
              trailing: AppMaterialIcon(AppIcons.caretRight, color: muted),
              onTap: _openBlockedSites,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: BrowserSecurityService.passwordSavingEnabled,
            builder: (context, enabled, _) => Material(
              color: settingsCardColor(context),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: AppMaterialIcon(AppIcons.lockSimple, color: accentColor(context)),
                title: Text(appText('save_passwords'), style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                subtitle: Text(appText('save_passwords_description'), style: TextStyle(color: muted, fontSize: 12)),
                trailing: M3ExpressiveSwitch(value: enabled, onChanged: _togglePasswordSaving),
                onTap: () => _togglePasswordSaving(!enabled),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(appText('security_disclaimer'),
                style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
