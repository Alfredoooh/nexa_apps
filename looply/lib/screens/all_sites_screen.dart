import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import 'home_screen.dart';
import '../widgets/svg_icon.dart';

class AllSitesScreen extends StatefulWidget {
  const AllSitesScreen({super.key});

  @override
  State<AllSitesScreen> createState() => _AllSitesScreenState();
}

class _AllSitesScreenState extends State<AllSitesScreen> {
  static const Duration _minimumLoaderDuration = Duration(seconds: 3);

  late Map<SiteCategory, List<QuickSite>> _groupedSites;
  late List<SiteCategory> _categories;
  bool _showInitialLoader = true;

  @override
  void initState() {
    super.initState();
    _prepareSites();
    customSitesController.addListener(_onCustomSitesChanged);
    _hideLoaderAfterMinimumDuration();
  }

  @override
  void dispose() {
    customSitesController.removeListener(_onCustomSitesChanged);
    super.dispose();
  }

  void _prepareSites() {
    final grouped = <SiteCategory, List<QuickSite>>{};
    for (final site in allSites) {
      grouped.putIfAbsent(site.category, () => <QuickSite>[]).add(site);
    }
    for (final site in customSitesController.sites) {
      grouped.putIfAbsent(SiteCategory.personalizados, () => <QuickSite>[]).add(site);
    }

    _groupedSites = grouped;
    _categories = SiteCategory.values
        .where((category) => grouped.containsKey(category))
        .toList(growable: false);
  }

  Future<void> _hideLoaderAfterMinimumDuration() async {
    final minimumDelay = Future<void>.delayed(_minimumLoaderDuration);
    final preparedIcons = _precacheSiteIcons().timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    await Future.wait<void>([minimumDelay, preparedIcons]);
    if (!mounted) return;
    setState(() => _showInitialLoader = false);
  }

  Future<void> _precacheSiteIcons() async {
    final providers = <ImageProvider<Object>>[];
    final seen = <String>{};
    for (final site in _groupedSites.values.expand((sites) => sites)) {
      try {
        if (site.iconBase64 != null && site.iconBase64!.isNotEmpty) {
          final key = 'memory:${site.iconBase64.hashCode}';
          if (seen.add(key)) providers.add(MemoryImage(base64Decode(site.iconBase64!)));
        } else if (site.assetPath != null && site.assetPath!.isNotEmpty) {
          final key = 'asset:${site.assetPath}';
          if (seen.add(key)) providers.add(AssetImage(site.assetPath!));
        } else if (site.faviconUrl != null && site.faviconUrl!.isNotEmpty) {
          final key = 'network:${site.faviconUrl}';
          if (seen.add(key)) providers.add(NetworkImage(site.faviconUrl!));
        }
      } catch (_) {
        // Um ícone inválido usa o fallback do tile; não bloqueia a abertura.
      }
    }
    await Future.wait<void>(
      providers.map((provider) => precacheImage(provider, context).catchError((_) {})),
    );
  }

  void _onCustomSitesChanged() {
    if (!mounted) return;
    setState(_prepareSites);
  }

  Future<void> _openAddSiteModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: const _AddCustomSiteSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: appText('back'),
          style: IconButton.styleFrom(
            foregroundColor: text,
            fixedSize: const Size(42, 42),
            shape: const CircleBorder(),
          ),
          icon: const AppSvgIcon(AppIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(appText('all_sites')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: appText('add_site'),
              color: text,
              icon: const AppSvgIcon(AppIcons.pencilSimple, size: 22),
              onPressed: _openAddSiteModal,
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showInitialLoader
            ? Center(
                key: const ValueKey<String>('all-sites-m3e-loader'),
                child: ExpressiveLoadingIndicator(
                  color: accentColor(context),
                  constraints: const BoxConstraints.tightFor(
                    width: 56,
                    height: 56,
                  ),
                  semanticsLabel: appText('loading_sites'),
                ),
              )
            : ListView.separated(
                key: const ValueKey<String>('all-sites-content'),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _CategorySection(
                    category: category,
                    sites: _groupedSites[category]!,
                  );
                },
              ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.sites});
  final SiteCategory category;
  final List<QuickSite> sites;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            siteCategoryLabel(category),
            style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            color: pillColor(context),
            borderRadius: BorderRadius.circular(22),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sites.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 2,
              mainAxisSpacing: 8,
              mainAxisExtent: 68,
            ),
            itemBuilder: (context, index) => Center(
              child: QuickSiteTile(site: sites[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddCustomSiteSheet extends StatefulWidget {
  const _AddCustomSiteSheet();

  @override
  State<_AddCustomSiteSheet> createState() => _AddCustomSiteSheetState();
}

class _AddCustomSiteSheetState extends State<_AddCustomSiteSheet> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _automaticName = true;
  bool _automaticFavicon = true;
  bool _saving = false;
  Uint8List? _pickedIcon;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 88,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedIcon = bytes;
        _automaticFavicon = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = appText('gallery_open_failed'));
    }
  }

  Uri? _normaliseUri() {
    var input = _urlController.text.trim();
    if (input.isEmpty) return null;
    if (!input.contains('://')) input = 'https://$input';
    final uri = Uri.tryParse(input);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  Future<String> _discoverName(Uri uri) async {
    try {
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'Mozilla/5.0 (compatible; BrowseIt/1.0)'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final html = utf8.decode(response.bodyBytes, allowMalformed: true);
        final title = RegExp(
          r'<title[^>]*>(.*?)</title>',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(html)?.group(1);
        if (title != null) {
          final cleaned = _decodeBasicHtml(title.replaceAll(RegExp(r'<[^>]*>'), ' '));
          if (cleaned.isNotEmpty) return cleaned;
        }
      }
    } catch (_) {
      // A extração do título é opcional; o domínio serve de alternativa.
    }

    final parts = uri.host.replaceFirst(RegExp(r'^www\.'), '').split('.');
    final index = parts.length >= 3 && parts[parts.length - 2].length <= 3
        ? parts.length - 3
        : parts.length - 2;
    final hostName = parts[index.clamp(0, parts.length - 1).toInt()];
    if (hostName.isEmpty) return uri.host;
    return hostName[0].toUpperCase() + hostName.substring(1);
  }

  String _decodeBasicHtml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _saveSite() async {
    final uri = _normaliseUri();
    if (uri == null) {
      setState(() => _error = appText('valid_http_url'));
      return;
    }
    if (!_automaticName && _nameController.text.trim().isEmpty) {
      setState(() => _error = appText('site_name_required'));
      return;
    }
    if (!_automaticFavicon && _pickedIcon == null) {
      setState(() => _error = appText('site_icon_required'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _automaticName
          ? await _discoverName(uri)
          : _nameController.text.trim();
      final host = uri.host;
      final site = QuickSite(
        name: name,
        url: uri.toString(),
        category: SiteCategory.personalizados,
        iconBase64: _automaticFavicon ? null : base64Encode(_pickedIcon!),
        faviconUrl: _automaticFavicon
            ? 'https://www.google.com/s2/favicons?domain=${Uri.encodeComponent(host)}&sz=128'
            : null,
      );
      await customSitesController.add(site);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText('add_site_success').replaceAll('{name}', name))),
      );
    } catch (_) {
      if (mounted) setState(() => _error = appText('save_site_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final panel = pillColor(context);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: muted.withOpacity(.45), borderRadius: BorderRadius.circular(99)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(appText('add_site'), style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: appText('site_url'),
                  hintText: 'https://exemplo.com',
                  prefixIcon: AppSvgIcon(AppIcons.link),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _automaticName,
                activeColor: accent,
                title: Text(appText('auto_site_name'), style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(appText('auto_site_name_help'), style: TextStyle(color: muted, fontSize: 11)),
                onChanged: (value) => setState(() => _automaticName = value),
              ),
              if (!_automaticName) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: appText('site_name'),
                    prefixIcon: AppSvgIcon(AppIcons.pencilSimple),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(appText('site_icon'), style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 7),
              RadioListTile<bool>(
                value: true,
                groupValue: _automaticFavicon,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
                title: Text(appText('auto_favicon'), style: TextStyle(color: text, fontSize: 12)),
                onChanged: (value) => setState(() => _automaticFavicon = value ?? true),
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: _automaticFavicon,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
                title: Text(appText('upload_site_icon'), style: TextStyle(color: text, fontSize: 12)),
                onChanged: (value) => setState(() => _automaticFavicon = value ?? false),
              ),
              if (!_automaticFavicon)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickIcon,
                  icon: const AppSvgIcon(AppIcons.uploadSimple),
                  label: Text(appText('select_image')),
                ),
              if (_pickedIcon != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_pickedIcon!, width: 48, height: 48, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 9),
                    Text(appText('selected_icon'), style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(appText('cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _saveSite,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(appText('add')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
