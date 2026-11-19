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
  final TextEditingController _searchController = TextEditingController();
  List<String> _sites = <String>[];
  String _query = '';
  bool _loading = true;

  List<String> get _filteredSites {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _sites;
    return _sites.where((site) => site.toLowerCase().contains(query)).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSites();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() => _query = _searchController.text);
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
          Text(
            appText('blocked_site_domain_help'),
            style: TextStyle(color: mutedText(context), fontSize: 13, height: 1.4),
          ),
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
        SnackBar(content: Text(appText('invalid_domain'))),
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

  Widget _buildSearchField(BuildContext context) {
    final muted = mutedText(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: pillColor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          AppMaterialIcon(AppIcons.magnifyingGlass, color: muted, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: mainText(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: appText('search_hint'),
                hintStyle: TextStyle(color: muted, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              tooltip: appText('clear'),
              visualDensity: VisualDensity.compact,
              onPressed: _searchController.clear,
              icon: AppMaterialIcon(AppIcons.x, color: muted, size: 19),
            ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(BuildContext context, String host, int index, int count) {
    final text = mainText(context);
    final muted = mutedText(context);
    final isFirst = index == 0;
    final isLast = index == count - 1;
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isFirst ? 20 : 8),
        bottom: Radius.circular(isLast ? 20 : 8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _removeSite(host),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              // O URL completo é essencial: a cache só consegue resolver
              // favicons para endereços http(s), não para o host isolado.
              SiteFaviconAvatar(url: 'https://$host', size: 44),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appText('blocked_site_subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: appText('remove_block'),
                onPressed: () => _removeSite(host),
                icon: AppMaterialIcon(AppIcons.trash, color: muted, size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool noMatches}) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMaterialIcon(
              noMatches ? AppIcons.magnifyingGlass : AppIcons.shieldCheck,
              color: muted,
              size: 44,
            ),
            const SizedBox(height: 13),
            Text(
              noMatches ? appText('no_results') : appText('blocked_sites_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              noMatches ? appText('search_hint') : appText('blocked_sites_empty_description'),
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final muted = mutedText(context);
    final filtered = _filteredSites;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(tooltip: appText('back'), color: text),
        title: Text(
          appText('blocked_sites'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'looply-blocked-sites-add-fab',
        tooltip: appText('add_blocked_site'),
        backgroundColor: looplyPrimary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        onPressed: _addSite,
        child: const AppMaterialIcon(AppIcons.plus, size: 24, color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_sites.length} ${appText('blocked_sites').toLowerCase()}',
                          style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: pillColor(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppMaterialIcon(AppIcons.shieldCheck, color: muted, size: 16),
                            const SizedBox(width: 5),
                            Text(appText('block'), style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSearchField(context),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accentColor(context), strokeWidth: 2.2))
                  : filtered.isEmpty
                      ? _buildEmptyState(context, noMatches: _sites.isNotEmpty && _query.isNotEmpty)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 3),
                          itemBuilder: (context, index) => _buildSiteCard(context, filtered[index], index, filtered.length),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
