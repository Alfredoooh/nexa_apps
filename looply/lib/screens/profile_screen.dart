import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../auth_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Estado local dos switches. Trocar por persistência real
  // (ex: SharedPreferences, backend, etc) quando ligares a lógica.
  bool _saveHistory = false;
  bool _syncBookmarks = true;
  bool _saveAddresses = false;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _SignOutDialog(),
    );
    if (confirmed == true && context.mounted) {
      await authController.signOut();
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(title: const Text('Perfil')),
      body: ValueListenableBuilder<LooplyUser?>(
        valueListenable: authController,
        builder: (context, user, _) {
          if (user == null) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Symbols.login_rounded),
                label: const Text('Iniciar sessão'),
              ),
            );
          }
          final text = mainText(context);
          final muted = mutedText(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: pillColor(context),
                      foregroundImage: user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
                      child: user.photoUrl == null
                          ? Icon(Symbols.person_rounded, size: 40, color: muted)
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: accentColor(context),
                          shape: BoxShape.circle,
                          border: Border.all(color: pageBg(context), width: 3),
                        ),
                        child: const Icon(Symbols.verified_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                user.displayName?.trim().isNotEmpty == true ? user.displayName! : 'Utilizador BrowseIt',
                textAlign: TextAlign.center,
                style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              Text(user.email, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: settingsCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor(context).withOpacity(0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Symbols.verified_user_rounded, color: accentColor(context), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sessão iniciada com ${user.provider == 'google' ? 'Google' : 'email'}',
                        style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _SectionLabel('Atividade'),
              const SizedBox(height: 10),
              _SwitchSettingCard(
                icon: Symbols.history_rounded,
                title: 'Histórico',
                subtitle: _saveHistory
                    ? 'A guardar o histórico na tua conta'
                    : 'O histórico não está a ser guardado',
                value: _saveHistory,
                onChanged: (v) => setState(() => _saveHistory = v),
              ),
              const SizedBox(height: 10),
              _SwitchSettingCard(
                icon: Symbols.bookmark_rounded,
                title: 'Marcadores',
                subtitle: _syncBookmarks
                    ? 'Sincronizados entre dispositivos'
                    : 'Guardados apenas neste dispositivo',
                value: _syncBookmarks,
                onChanged: (v) => setState(() => _syncBookmarks = v),
              ),
              const SizedBox(height: 22),
              _SectionLabel('Conta'),
              const SizedBox(height: 10),
              _SwitchSettingCard(
                icon: Symbols.location_on_rounded,
                title: 'Moradas',
                subtitle: _saveAddresses
                    ? 'Guardadas para preencher formulários'
                    : 'Não guardadas',
                value: _saveAddresses,
                onChanged: (v) => setState(() => _saveAddresses = v),
              ),
              const SizedBox(height: 10),
              _NavSettingCard(
                icon: Symbols.settings_rounded,
                title: 'Configurações do app',
                subtitle: 'Aparência, privacidade e mais',
                onTap: () {
                  // Navegar para o ecrã de configurações do app.
                },
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: BorderSide(color: Colors.red.withOpacity(0.4)),
                  foregroundColor: Colors.red,
                ),
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Symbols.logout_rounded),
                label: const Text('Terminar sessão', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: mutedText(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SwitchSettingCard extends StatelessWidget {
  const _SwitchSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
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
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSettingCard extends StatelessWidget {
  const _NavSettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: muted, fontSize: 11.5)),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Dialog(
      backgroundColor: settingsCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.logout_rounded, color: Colors.red, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              'Terminar sessão?',
              textAlign: TextAlign.center,
              style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Vais precisar de iniciar sessão novamente para aceder à tua conta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Sair', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}