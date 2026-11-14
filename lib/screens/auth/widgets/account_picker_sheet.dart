// ══════════════════════════════════════════════════════════════
// FILE: lib/features/auth/widgets/account_picker_sheet.dart
// Bottom sheet com as contas guardadas neste dispositivo.
// Modal Material real (showModalBottomSheet padrão), tiles sem
// container, avatar com fallback para assets/icons/png/avatar.png,
// "Usar outra conta" como botão em texto.
// ══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../services/local_accounts_service.dart';

import '../../../widgets/widgets.dart';
/// Mostra o bottom sheet de contas guardadas.
/// Devolve a [LocalAccount] escolhida, ou `null` se o utilizador
/// tocou em "Usar outra conta" / fechou o sheet.
Future<LocalAccount?> showAccountPickerSheet({
  required BuildContext context,
  required List<LocalAccount> accounts,
}) {
  final s = AppTheme.of(context);
  return showModalBottomSheet<LocalAccount?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: s.pageBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AccountPickerSheet(accounts: accounts),
  );
}

class _AccountPickerSheet extends StatelessWidget {
  final List<LocalAccount> accounts;
  const _AccountPickerSheet({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: s.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contas neste dispositivo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: s.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolhe uma conta para continuar.',
                  style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accounts.length,
            itemBuilder: (context, i) => _AccountTile(account: accounts[i]),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                foregroundColor: s.onSurface,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              child: const Text(
                'Usar outra conta',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final LocalAccount account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final a = account;
    final hasAvatar = a.avatar != null && a.avatar!.isNotEmpty;

    return ListTile(
      onTap: () => Navigator.of(context).pop(a),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: s.cardBackground,
        backgroundImage: hasAvatar
            ? NetworkImage(a.avatar!)
            : const AssetImage('assets/icons/png/avatar.png')
                as ImageProvider,
      ),
      title: Text(
        a.name,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: s.onSurface),
      ),
      subtitle: Text(
        a.identifier,
        style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
      ),
      trailing: Icon(RoundedSymbols.chevronRight,
          size: 20, color: s.onSurfaceVariant),
    );
  }
}