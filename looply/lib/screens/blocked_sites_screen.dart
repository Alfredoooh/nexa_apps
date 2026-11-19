import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../security/browser_security_service.dart';
import '../theme.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/material_symbols.dart';
import 'activity_screen.dart' show SiteFaviconAvatar;

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
      title: appText('add_blocked_site'),
      icon: AppIcons.shield,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appText('blocked_site_domain_help'),
              style: TextStyle(color: mutedText(context), fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: appText('blocked_site_domain_hint')),
          ),
        ],
      ),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('block'), value: true, isPrimary: true),
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
        SnackBar(content: Text(appText('invalid_domain'))) ,
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${appText('block_site_failed')} $error')),
      );
    }
  }

  Future<void> _removeSite(String host) async {
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('remove_block_title'),
      icon: AppIcons.shield,
      content: Text(appText('remove_block_description').replaceAll('{site}', host)),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('remove'), value: true, isPrimary: true),
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
        leading: AppBackButton(tooltip: appText('back'), color: text),
        title: Text(appText('blocked_sites'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          _loading
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
                            Text(appText('blocked_sites_empty'), style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text(appText('blocked_sites_empty_description'), textAlign: TextAlign.center,
                                style: TextStyle(color: muted, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _sites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final host = _sites[index];
                        return Material(
                          color: settingsCardColor(context),
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: SiteFaviconAvatar(url: host, size: 38),
                            title: Text(host, style: TextStyle(color: text, fontWeight: FontWeight.w600)),
                            subtitle: Text(appText('blocked_site_subtitle'), style: TextStyle(color: muted, fontSize: 12)),
                            trailing: IconButton(
                              tooltip: appText('remove_block'),
                              onPressed: () => _removeSite(host),
                              icon: AppMaterialIcon(AppIcons.trash, color: muted),
                            ),
                          ),
                        );
                      },
                    ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton(
              heroTag: 'looply-blocked-sites-add-fab',
              tooltip: appText('add_blocked_site'),
              backgroundColor: looplyPrimary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              onPressed: _addSite,
              child: const AppMaterialIcon(AppIcons.plus, size: 24, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}