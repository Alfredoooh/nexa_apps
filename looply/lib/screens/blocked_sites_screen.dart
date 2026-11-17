import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../security/browser_security_service.dart';
import '../theme.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/material_symbols.dart';

class BlockedSitesScreen extends StatefulWidget {
  const BlockedSitesScreen({super.key});

  @override
  State<BlockedSitesScreen> createState() => _BlockedSitesScreenState();
}

class _BlockedSitesScreenState extends State<BlockedSitesScreen> {
  List<String> _sites = <String>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    final sites = await BrowserSecurityService.blockedSites();
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _loading = false;
    });
  }

  Future<void> _addSite() async {
    final controller = TextEditingController();
    final accepted = await showLooplyDialog<bool>(
      context: context,
      title: 'Bloquear site',
      icon: AppIcons.shield,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Introduz o domínio, por exemplo exemplo.com. O bloqueio também se aplica aos subdomínios.',
              style: TextStyle(color: mutedText(context), fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'exemplo.com'),
          ),
        ],
      ),
      actions: const <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: 'Cancelar', value: false),
        LooplyDialogAction<bool>(label: 'Bloquear', value: true, isPrimary: true),
      ],
    );
    final value = controller.text.trim();
    controller.dispose();
    if (accepted != true || !mounted) return;

    try {
      await BrowserSecurityService.addBlockedSite(value);
      await _loadSites();
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduz um domínio válido, sem caminhos ou parâmetros.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível bloquear o site: $error')),
      );
    }
  }

  Future<void> _removeSite(String host) async {
    final mode = await BrowserSecurityService.credentialMode();
    final credentialController = TextEditingController();
    final requested = await showLooplyDialog<bool>(
      context: context,
      title: 'Confirmar remoção',
      icon: AppIcons.shieldCheck,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirma a tua proteção para remover permanentemente o bloqueio de $host.',
              style: TextStyle(color: mutedText(context), fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: credentialController,
            autofocus: true,
            obscureText: true,
            keyboardType: mode == 'pin' ? TextInputType.number : TextInputType.visiblePassword,
            decoration: InputDecoration(labelText: mode == 'pin' ? 'PIN' : 'Palavra-passe'),
          ),
        ],
      ),
      actions: const <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: 'Cancelar', value: false),
        LooplyDialogAction<bool>(label: 'Continuar', value: true, isPrimary: true),
      ],
    );
    final secret = credentialController.text;
    credentialController.dispose();
    if (requested != true || !mounted) return;

    final verified = await BrowserSecurityService.verifyCredential(secret);
    if (!verified) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN ou palavra-passe incorretos.')),
      );
      return;
    }

    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: 'Remover bloqueio?',
      icon: AppIcons.shield,
      content: Text('O domínio $host voltará a poder ser aberto.'),
      actions: const <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: 'Cancelar', value: false),
        LooplyDialogAction<bool>(label: 'Remover', value: true, isPrimary: true),
      ],
    );
    if (confirmed != true || !mounted) return;
    await BrowserSecurityService.removeBlockedSite(host);
    await _loadSites();
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
        leadingWidth: 104,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBackButton(tooltip: appText('back'), color: text, buttonSize: 48),
            IconButton(
              tooltip: 'Adicionar site bloqueado',
              onPressed: _addSite,
              icon: AppMaterialIcon(AppIcons.plus, color: accentColor(context), size: 24),
            ),
          ],
        ),
        title: Text('Sites bloqueados', style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sites.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppMaterialIcon(AppIcons.shieldCheck, color: muted, size: 42),
                        const SizedBox(height: 12),
                        Text('Nenhum site bloqueado', style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Usa o botão + no topo para adicionar um domínio.', textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _sites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final host = _sites[index];
                    return Material(
                      color: settingsCardColor(context),
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: AppMaterialIcon(AppIcons.shield, color: accentColor(context)),
                        title: Text(host, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                        subtitle: Text('Bloqueado neste dispositivo', style: TextStyle(color: muted, fontSize: 12)),
                        trailing: IconButton(
                          tooltip: 'Remover bloqueio',
                          onPressed: () => _removeSite(host),
                          icon: AppMaterialIcon(AppIcons.trash, color: muted),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
