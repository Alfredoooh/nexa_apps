import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import 'home_screen.dart';

class AllSitesScreen extends StatefulWidget {
  const AllSitesScreen({super.key});

  @override
  State<AllSitesScreen> createState() => _AllSitesScreenState();
}

class _AllSitesScreenState extends State<AllSitesScreen> {
  @override
  void initState() {
    super.initState();
    customSitesController.addListener(_onCustomSitesChanged);
  }

  @override
  void dispose() {
    customSitesController.removeListener(_onCustomSitesChanged);
    super.dispose();
  }

  void _onCustomSitesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openAddSiteDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddCustomSiteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <SiteCategory, List<QuickSite>>{};
    for (final site in allSites) {
      grouped.putIfAbsent(site.category, () => []).add(site);
    }
    for (final site in customSitesController.sites) {
      grouped.putIfAbsent(SiteCategory.personalizados, () => []).add(site);
    }
    final categories = SiteCategory.values
        .where((category) => grouped.containsKey(category))
        .toList(growable: false);
    final text = mainText(context);

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Voltar',
          style: IconButton.styleFrom(
            foregroundColor: text,
            fixedSize: const Size(42, 42),
            shape: const CircleBorder(),
          ),
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Todos os sites'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Adicionar site',
              style: IconButton.styleFrom(
                backgroundColor: pillColor(context),
                foregroundColor: text,
                fixedSize: const Size(42, 42),
                shape: const CircleBorder(),
              ),
              icon: const Icon(Symbols.edit_rounded, size: 20),
              onPressed: _openAddSiteDialog,
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategorySection(
            category: category,
            sites: grouped[category]!,
          );
        },
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

class _AddCustomSiteDialog extends StatefulWidget {
  const _AddCustomSiteDialog();

  @override
  State<_AddCustomSiteDialog> createState() => _AddCustomSiteDialogState();
}

class _AddCustomSiteDialogState extends State<_AddCustomSiteDialog> {
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
      if (mounted) setState(() => _error = 'Não foi possível abrir a galeria.');
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
        headers: const {'User-Agent': 'Mozilla/5.0 (compatible; LooplyBrowser/1.0)'},
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
      setState(() => _error = 'Introduz um endereço HTTP ou HTTPS válido.');
      return;
    }
    if (!_automaticName && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Escreve o nome do site ou ativa o nome automático.');
      return;
    }
    if (!_automaticFavicon && _pickedIcon == null) {
      setState(() => _error = 'Seleciona um ícone ou escolhe o favicon automático.');
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
        SnackBar(content: Text('$name foi adicionado aos teus sites.')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível guardar este site.');
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

    return AlertDialog(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text('Adicionar site', style: TextStyle(color: text, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Link do site',
                  hintText: 'https://exemplo.com',
                  prefixIcon: Icon(Symbols.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _automaticName,
                activeColor: accent,
                title: Text('Carregar nome automaticamente', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('Usa o título da página ou o domínio.', style: TextStyle(color: muted, fontSize: 11)),
                onChanged: (value) => setState(() => _automaticName = value),
              ),
              if (!_automaticName) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Nome do site',
                    prefixIcon: Icon(Symbols.edit_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('Ícone do site', style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 7),
              RadioListTile<bool>(
                value: true,
                groupValue: _automaticFavicon,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
                title: Text('Adquirir favicon automaticamente', style: TextStyle(color: text, fontSize: 12)),
                onChanged: (value) => setState(() => _automaticFavicon = value ?? true),
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: _automaticFavicon,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
                title: Text('Carregar ícone do telemóvel', style: TextStyle(color: text, fontSize: 12)),
                onChanged: (value) => setState(() => _automaticFavicon = value ?? false),
              ),
              if (!_automaticFavicon)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickIcon,
                  icon: const Icon(Symbols.upload_rounded),
                  label: const Text('Selecionar imagem'),
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
                    Text('Ícone selecionado', style: TextStyle(color: muted, fontSize: 12)),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveSite,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Adicionar'),
        ),
      ],
    );
  }
}
