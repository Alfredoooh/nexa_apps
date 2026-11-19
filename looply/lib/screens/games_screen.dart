import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../localization.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';

const MethodChannel _nativeGameChannel = MethodChannel('looply/native_ui');
const String _bundledGamesCatalog = 'assets/games/games_catalog.json';

class _GameCategory {
  const _GameCategory({required this.id, required this.name, this.description = ''});
  final String id;
  final String name;
  final String description;

  factory _GameCategory.fromJson(Map<String, dynamic> json) => _GameCategory(
        id: json['id']?.toString() ?? 'other',
        name: json['name']?.toString() ?? 'Outros',
        description: json['description']?.toString() ?? '',
      );
}

class _GameEntry {
  const _GameEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.cover,
    required this.fallbackAsset,
    required this.featured,
    required this.launchType,
    this.launchUrl,
    this.htmlSource,
    this.baseUrl,
    this.orientation = 'auto',
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String cover;
  final String fallbackAsset;
  final bool featured;
  final String launchType;
  final String? launchUrl;
  final String? htmlSource;
  final String? baseUrl;
  final String orientation;

  factory _GameEntry.fromJson(Map<String, dynamic> json) {
    final launch = json['launch'] is Map
        ? Map<String, dynamic>.from(json['launch'] as Map)
        : <String, dynamic>{};
    final type = launch['type']?.toString() ?? 'url';
    if (!const {'url', 'source_url', 'html'}.contains(type)) {
      throw FormatException('Tipo de lançamento inválido no jogo ${json['id']}.');
    }
    final html = launch['html']?.toString();
    final url = launch['url']?.toString();
    if (type == 'html' && (html == null || html.isEmpty)) {
      throw FormatException('O jogo ${json['id']} não contém código HTML.');
    }
    if (type != 'html' && (url == null || url.trim().isEmpty)) {
      throw FormatException('O jogo ${json['id']} não contém um link HTTPS.');
    }
    return _GameEntry(
      id: json['id']?.toString() ?? 'game-${json.hashCode}',
      name: json['name']?.toString() ?? 'Jogo',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      cover: json['cover']?.toString() ?? json['icon']?.toString() ?? '',
      fallbackAsset: json['fallbackAsset']?.toString() ?? '',
      featured: json['featured'] == true,
      launchType: type,
      launchUrl: url,
      htmlSource: html,
      baseUrl: launch['baseUrl']?.toString(),
      orientation: json['orientation']?.toString() ?? 'auto',
    );
  }
}

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  List<_GameEntry> _games = const <_GameEntry>[];
  List<_GameCategory> _categories = const <_GameCategory>[];
  String _selectedCategory = 'all';
  Uri? _remoteCatalogUri;
  Uri? _gamesBaseUri;
  String? _catalogError;
  String? _openingGame;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final localText = await rootBundle.loadString(_bundledGamesCatalog);
      final localJson = jsonDecode(localText);
      if (localJson is! Map<String, dynamic>) {
        throw const FormatException('O catálogo local não tem o formato esperado.');
      }
      var selectedJson = localJson;
      Uri? selectedUri;
      Uri? selectedGamesBaseUri;
      final repository = localJson['repository'] is Map
          ? Map<String, dynamic>.from(localJson['repository'] as Map)
          : <String, dynamic>{};
      final catalogUrl = repository['catalogUrl']?.toString() ?? '';
      final configuredRemote = _isConfiguredHttpsUrl(catalogUrl) ? Uri.tryParse(catalogUrl) : null;
      final localGamesBase = Uri.tryParse(repository['gamesBaseUrl']?.toString() ?? '');
      if (localGamesBase != null && localGamesBase.scheme == 'https' && localGamesBase.host.isNotEmpty && !localGamesBase.toString().contains('SEU_')) {
        selectedGamesBaseUri = localGamesBase;
      }
      if (configuredRemote != null) {
        try {
          final response = await http.get(configuredRemote).timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            final remoteJson = jsonDecode(utf8.decode(response.bodyBytes));
            if (remoteJson is Map<String, dynamic> && remoteJson['games'] is List) {
              selectedJson = remoteJson;
              selectedUri = configuredRemote;
              final remoteRepository = remoteJson['repository'] is Map
                  ? Map<String, dynamic>.from(remoteJson['repository'] as Map)
                  : <String, dynamic>{};
              final remoteGamesBase = Uri.tryParse(remoteRepository['gamesBaseUrl']?.toString() ?? '');
              if (remoteGamesBase != null && remoteGamesBase.scheme == 'https' && remoteGamesBase.host.isNotEmpty) {
                selectedGamesBaseUri = remoteGamesBase;
              }
            }
          }
        } catch (_) {
          // Um catálogo remoto indisponível não deve bloquear os jogos locais.
        }
      }

      final categories = (selectedJson['categories'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _GameCategory.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      final games = (selectedJson['games'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _GameEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _games = games;
        _remoteCatalogUri = selectedUri;
        _gamesBaseUri = selectedGamesBaseUri;
        _loading = false;
        _catalogError = games.isEmpty ? 'O catálogo não contém jogos.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _catalogError = 'Não foi possível ler o catálogo: $error';
      });
    }
  }

  bool _isConfiguredHttpsUrl(String value) =>
      value.startsWith('https://') &&
      !value.contains('SEU_USUARIO') &&
      !value.contains('SEU_REPOSITORIO') &&
      Uri.tryParse(value)?.host.isNotEmpty == true;

  Uri? _resolveCatalogAsset(String path) {
    if (_remoteCatalogUri == null || path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.scheme == 'https' && uri.host.isNotEmpty ? uri : null;
    return _remoteCatalogUri!.resolve(path);
  }

  Uri? _resolveLaunchUrl(_GameEntry game) {
    final value = game.launchUrl?.trim() ?? '';
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      return parsed.scheme == 'https' && parsed.host.isNotEmpty ? parsed : null;
    }

    final baseString = game.baseUrl;
    final base = baseString == null || baseString.isEmpty ? _gamesBaseUri : Uri.tryParse(baseString);
    if (base != null && base.scheme == 'https' && base.host.isNotEmpty) return base.resolve(value);
    return null;
  }

  Future<void> _openGame(_GameEntry game) async {
    if (_openingGame != null) return;
    final launchUrl = _resolveLaunchUrl(game);
    if (game.launchType != 'html' && launchUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O link deste jogo não é um endereço HTTPS válido.')),
      );
      return;
    }
    setState(() => _openingGame = game.id);
    try {
      await _nativeGameChannel.invokeMethod<bool>('openGame', <String, Object?>{
        'launchType': game.launchType,
        'url': launchUrl?.toString(),
        'html': game.htmlSource,
        'baseUrl': game.baseUrl,
        'title': game.name,
        'orientation': game.orientation,
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? appText('game_open_failed'))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appText('game_open_failed'))),
      );
    } finally {
      if (mounted) setState(() => _openingGame = null);
    }
  }

  List<_GameEntry> get _visibleGames => _selectedCategory == 'all'
      ? _games
      : _games.where((game) => game.category == _selectedCategory).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    final featured = _visibleGames.where((game) => game.featured).toList(growable: false);
    final allFeatured = featured.isEmpty ? _visibleGames : featured;

    final bg = pageBg(context);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: Text(appText('games'), style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.2))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(child: Text('Jogos rápidos para jogar diretamente no BrowseIt.',
                            style: TextStyle(color: muted, fontSize: 13.5, height: 1.35))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(999)),
                            child: Text('${_visibleGames.length}', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 42,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: <Widget>[
                            _CategoryChip(label: 'Todos', selected: _selectedCategory == 'all', onTap: () => setState(() => _selectedCategory = 'all')),
                            for (final category in _categories)
                              _CategoryChip(
                                label: category.name,
                                selected: _selectedCategory == category.id,
                                onTap: () => setState(() => _selectedCategory = category.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (allFeatured.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 13),
                      sliver: SliverToBoxAdapter(
                        child: Text('Em destaque', style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 262,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: allFeatured.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) => _FeaturedGameCard(
                            game: allFeatured[index],
                            imageUri: _resolveCatalogAsset(allFeatured[index].cover),
                            opening: _openingGame == allFeatured[index].id,
                            onTap: () => _openGame(allFeatured[index]),
                          ),
                        ),
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text('Todos os jogos', style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w800))),
                          Text('${_visibleGames.length}', style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  if (_catalogError != null && _games.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppMaterialIcon(AppIcons.warningCircle, color: muted, size: 32),
                              const SizedBox(height: 12),
                              Text(_catalogError!, textAlign: TextAlign.center, style: TextStyle(color: muted)),
                              const SizedBox(height: 12),
                              TextButton(onPressed: () { setState(() => _loading = true); _loadCatalog(); }, child: const Text('Tentar novamente')),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_visibleGames.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text('Não existem jogos nesta categoria.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 12,
                          childAspectRatio: .91,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final game = _visibleGames[index];
                            return _GameGridCard(
                              game: game,
                              imageUri: _resolveCatalogAsset(game.cover),
                              opening: _openingGame == game.id,
                              onTap: () => _openGame(game),
                            );
                          },
                          childCount: _visibleGames.length,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    sliver: SliverToBoxAdapter(
                      child: Text('Os jogos são carregados na WebView nativa do BrowseIt.', textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 11.5, height: 1.35)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          labelStyle: TextStyle(color: selected ? Theme.of(context).colorScheme.onPrimary : mainText(context), fontWeight: FontWeight.w600, fontSize: 12.5),
          selectedColor: accentColor(context),
          backgroundColor: pillColor(context),
          side: BorderSide(color: selected ? accentColor(context) : lineColor(context)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}

class _FeaturedGameCard extends StatelessWidget {
  const _FeaturedGameCard({required this.game, required this.imageUri, required this.opening, required this.onTap});
  final _GameEntry game;
  final Uri? imageUri;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return SizedBox(
      width: 318,
      child: Material(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: opening ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _GameCover(game: game, remoteUri: imageUri)),
              SizedBox(
                height: 76,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
                  child: Row(
                    children: [
                      Expanded(child: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 10),
                      _PlayPill(opening: opening, onTap: onTap),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameGridCard extends StatelessWidget {
  const _GameGridCard({required this.game, required this.imageUri, required this.opening, required this.onTap});
  final _GameEntry game;
  final Uri? imageUri;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: opening ? null : onTap,
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: SizedBox.expand(child: _GameCover(game: game, remoteUri: imageUri)),
              ),
            ),
            const SizedBox(height: 8),
            Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(game.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11.5, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _GameCover extends StatelessWidget {
  const _GameCover({required this.game, required this.remoteUri});
  final _GameEntry game;
  final Uri? remoteUri;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      game.fallbackAsset,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _GameCoverFallback(game: game),
    );
    if (remoteUri == null) return fallback;
    return Image.network(
      remoteUri.toString(),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _GameCoverFallback extends StatelessWidget {
  const _GameCoverFallback({required this.game});
  final _GameEntry game;

  @override
  Widget build(BuildContext context) => Container(
        color: pillColor(context),
        alignment: Alignment.center,
        child: AppMaterialIcon(AppIcons.sportsEsports, size: 38, color: accentColor(context)),
      );
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.opening, required this.onTap});
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: accentColor(context),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: opening ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 42,
            width: 104,
            child: Center(
              child: opening
                  ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Jogar', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
}
