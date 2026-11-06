import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../localization.dart';
import '../auth_service.dart';
import '../theme.dart';
import '../widgets/m3_switch.dart';
import '../widgets/looply_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Cada toggle, quando ativo, passa a guardar o respetivo dado na conta
  // da pessoa autenticada. Estado local por agora — troca por persistência
  // real (backend/SharedPreferences) quando ligares a lógica de cada um.
  bool _saveHistory = false;
  bool _syncBookmarks = true;
  bool _saveAddresses = false;
  bool _syncAppSettings = false;

  // Confirmação desenhada em Flutter; não usa AlertDialog nativo.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('sign_out'),
      icon: Symbols.logout_rounded,
      content: Text(appText('sign_out_confirm')),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('sign_out'), value: true, isDestructive: true),
      ],
    );
    if (confirmed == true && context.mounted) {
      await authController.signOut();
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: ValueListenableBuilder<LooplyUser?>(
        valueListenable: authController,
        builder: (context, user, _) {
          if (user == null) {
            return Stack(
              children: [
                Center(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Symbols.login_rounded),
                    label: Text(appText('sign_in')),
                  ),
                ),
                Positioned(top: 0, left: 0, right: 0, child: _ProfileFadeAppBar(topInset: topInset)),
              ],
            );
          }
          final text = mainText(context);
          final muted = mutedText(context);
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(20, topInset + 76, 20, 110),
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: pillColor(context),
                          foregroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : const AssetImage('images/avatar.png') as ImageProvider,
                          child: null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: accentColor(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 3),
                            ),
                            child: const Icon(Symbols.verified_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    user.displayName?.trim().isNotEmpty == true ? user.displayName! : appText('user_browseit'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(user.email, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 24),
                  Material(
                    color: settingsCardColor(context),
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Symbols.verified_user_rounded, color: accentColor(context), size: 19),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              appText('signed_in_with').replaceAll('{provider}', user.provider == 'google' ? 'Google' : 'email'),
                              style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Secção única — sem categorias separadas (Atividade/Conta/etc).
                  // Mesma geometria agrupada dos cards da Settings: primeiro
                  // card mais curvo em cima, últimos mais curvo embaixo,
                  // intermédios discretos.
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProfileToggleTile(
                          icon: Symbols.history_rounded,
                          title: appText('history'),
                          subtitle: _saveHistory
                              ? appText('save_history_account')
                              : appText('history_not_saved'),
                          value: _saveHistory,
                          onChanged: (v) => setState(() => _saveHistory = v),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22), bottom: Radius.circular(8)),
                        ),
                        const SizedBox(height: 2),
                        _ProfileToggleTile(
                          icon: Symbols.bookmark_rounded,
                          title: appText('bookmarks'),
                          subtitle: _syncBookmarks
                              ? appText('synced_across_devices')
                              : appText('device_only'),
                          value: _syncBookmarks,
                          onChanged: (v) => setState(() => _syncBookmarks = v),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 2),
                        _ProfileToggleTile(
                          icon: Symbols.location_on_rounded,
                          title: appText('addresses'),
                          subtitle: _saveAddresses
                              ? appText('addresses_saved')
                              : appText('not_saved'),
                          value: _saveAddresses,
                          onChanged: (v) => setState(() => _saveAddresses = v),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 2),
                        _ProfileToggleTile(
                          icon: Symbols.settings_rounded,
                          title: appText('settings'),
                          subtitle: _syncAppSettings
                              ? appText('synced_across_devices')
                              : appText('device_only'),
                          value: _syncAppSettings,
                          onChanged: (v) => setState(() => _syncAppSettings = v),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(22)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(top: 0, left: 0, right: 0, child: _ProfileFadeAppBar(topInset: topInset)),
              Positioned(bottom: 0, left: 0, right: 0, child: _ProfileFadeBottomBar(onSignOut: () => _confirmSignOut(context))),
            ],
          );
        },
      ),
    );
  }
}

// Appbar flutuante da Profile: um botão circular de voltar, título
// central, e o mesmo gradiente sólido-no-topo / transparente-na-base.
class _ProfileFadeAppBar extends StatelessWidget {
  const _ProfileFadeAppBar({required this.topInset});
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
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
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: appText('back'),
                child: Material(
                  color: pillColor(context),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: muted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appText('profile'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 42), // balanceia o botão de voltar, título fica centrado
            ],
          ),
        ),
      ),
    );
  }
}

// Bottombar flutuante com terminar sessão: invertido do appbar — topo
// transparente, esvaindo para sólido na base, onde o botão assenta.
class _ProfileFadeBottomBar extends StatelessWidget {
  const _ProfileFadeBottomBar({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withOpacity(0.0), bg, bg],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
            backgroundColor: Colors.red.shade400.withOpacity(0.9),
            foregroundColor: Colors.white,
          ),
          onPressed: onSignOut,
          icon: const Icon(Symbols.logout_rounded),
          label: Text(appText('sign_out'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// Mesmo estilo de card da Settings (settingsCardColor, mesmas curvas
// agrupadas), mas sem badge circular atrás do ícone, e com o
// M3ExpressiveSwitch real da Settings em vez de Switch.adaptive.
class _ProfileToggleTile extends StatelessWidget {
  const _ProfileToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.borderRadius,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Material(
      color: settingsCardColor(context),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                M3ExpressiveSwitch(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}