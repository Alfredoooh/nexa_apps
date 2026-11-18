import 'package:material_ui/material_ui.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';

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

  Future<bool> _verifyExistingCredential() async {
    final oldMode = await BrowserSecurityService.credentialMode();
    final oldController = TextEditingController();
    var obscure = true;

    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pageBg(context),
      showDragHandle: true,
      builder: (sheetContext) => LooplyModalSystemBar(
        child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppMaterialIcon(AppIcons.shieldCheck, color: mainText(context), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        appText('verify_existing_protection'),
                        style: TextStyle(color: mainText(context), fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: oldController,
                  autofocus: true,
                  obscureText: obscure,
                  keyboardType: oldMode == 'pin' ? TextInputType.number : TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.of(context, rootNavigator: true).pop(true),
                  decoration: InputDecoration(
                    labelText: oldMode == 'pin' ? appText('current_pin') : appText('current_password'),
                    suffixIcon: IconButton(
                      onPressed: () => setSheetState(() => obscure = !obscure),
                      icon: AppMaterialIcon(obscure ? AppIcons.eye : AppIcons.eyeSlash),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                      child: Text(appText('cancel')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                      child: Text(appText('continue')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );

    final oldSecret = oldController.text;
    oldController.dispose();
    if (verified != true || !mounted) return false;
    final isValid = await BrowserSecurityService.verifyCredential(oldSecret);
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText('protection_incorrect'))),
        );
      }
      return false;
    }
    return true;
  }

  Future<bool> _configureCredential() async {
    if (_credentialConfigured || await BrowserSecurityService.hasCredential()) {
      final verified = await _verifyExistingCredential();
      if (!verified || !mounted) return false;
    }

    final modeController = ValueNotifier<String>('pin');
    final secretController = TextEditingController();
    final confirmController = TextEditingController();
    var visible = false;

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pageBg(context),
      showDragHandle: true,
      builder: (sheetContext) => LooplyModalSystemBar(
        child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppMaterialIcon(AppIcons.shieldCheck, color: mainText(context), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          appText('configure_protection'),
                          style: TextStyle(color: mainText(context), fontSize: 19, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    appText('choose_protection_help'),
                    style: TextStyle(color: mutedText(context), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 14),
                  ValueListenableBuilder<String>(
                    valueListenable: modeController,
                    builder: (context, mode, _) => TextField(
                      controller: secretController,
                      autofocus: true,
                      obscureText: !visible,
                      keyboardType: mode == 'pin' ? TextInputType.number : TextInputType.visiblePassword,
                      textInputAction: TextInputAction.next,
                      maxLength: mode == 'pin' ? 12 : 64,
                      decoration: InputDecoration(
                        labelText: mode == 'pin' ? appText('pin_format_hint') : appText('password_format_hint'),
                        counterText: '',
                        suffixIcon: IconButton(
                          onPressed: () => setSheetState(() => visible = !visible),
                          icon: AppMaterialIcon(visible ? AppIcons.eyeSlash : AppIcons.eye),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(labelText: appText('confirm_protection')),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
                        child: Text(appText('cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                        child: Text(appText('save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
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
        SnackBar(content: Text(appText('protection_invalid'))),
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
          SnackBar(content: Text(appText('protection_saved'))),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ExcludeFocus(
              child: M3ESegmentedColumn(
                color: settingsCardColor(context),
                outerRadius: 22,
                innerRadius: 8,
                gap: 2,
                padding: EdgeInsets.zero,
                children: [
                  _SecurityTile(
                    icon: AppIcons.shieldCheck,
                    label: appText('security_credential_title'),
                    subtitle: _loading
                        ? appText('security_verifying')
                        : _credentialConfigured
                            ? appText('protection_configured')
                            : appText('protection_not_configured'),
                    onTap: _configureCredential,
                  ),
                  _SecurityTile(
                    icon: AppIcons.shield,
                    label: appText('blocked_sites'),
                    subtitle: appText('blocked_sites_description'),
                    onTap: _openBlockedSites,
                  ),
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

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.onTap,
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
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.focused)) return Colors.transparent;
          return null;
        }),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 52 : 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)),
                  alignment: Alignment.center,
                  child: AppMaterialIcon(icon, color: text, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: text, fontSize: 14, height: 1.15, fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.5, height: 1.1),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(fit: FlexFit.loose, child: Align(alignment: Alignment.centerRight, child: trailing!)),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  AppMaterialIcon(AppIcons.caretRight, color: muted, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}