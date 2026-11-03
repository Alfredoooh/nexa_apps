import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../auth_service.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: pillColor(context),
                  foregroundImage: user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
                  child: user.photoUrl == null
                      ? Icon(Symbols.person_rounded, size: 38, color: muted)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName?.trim().isNotEmpty == true ? user.displayName! : 'Utilizador BrowseIt',
                textAlign: TextAlign.center,
                style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(user.email, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: settingsCardColor(context), borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    Icon(Symbols.verified_user_rounded, color: accentColor(context), size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Sessão iniciada com ${user.provider == 'google' ? 'Google' : 'email'}.', style: TextStyle(color: text, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () async {
                  await authController.signOut();
                  if (context.mounted) Navigator.of(context).maybePop();
                },
                icon: const Icon(Symbols.logout_rounded),
                label: const Text('Terminar sessão'),
              ),
            ],
          );
        },
      ),
    );
  }
}
