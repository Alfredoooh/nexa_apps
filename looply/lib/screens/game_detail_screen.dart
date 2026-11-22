import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/catalog_api.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';

const MethodChannel _nativeGameChannel = MethodChannel('looply/native_ui');

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({super.key, required this.game});
  final CatalogGame game;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  InstalledGame? _installed;
  bool _checkingInstall = true;
  bool _downloading = false;
  bool _opening = false;
  double _downloadProgress = 0;
  String? _error;

  CatalogGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    try {
      final installed = await BrowseItCatalogApi.instance.findInstalledGame(game);
      if (!mounted) return;
      setState(() { _installed = installed; _checkingInstall = false; });
    } catch (_) {
      if (mounted) setState(() => _checkingInstall = false);
    }
  }

  Future<void> _download() async {
    if (_downloading || game.offlineFiles.isEmpty) return;
    setState(() { _downloading = true; _downloadProgress = 0; _error = null; });
    try {
      final installed = await BrowseItCatalogApi.instance.downloadGame(
        game,
        onProgress: (value) { if (mounted) setState(() => _downloadProgress = value); },
      );
      if (!mounted) return;
      setState(() { _installed = installed; _downloading = false; _downloadProgress = 1; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${game.name} foi guardado para jogar offline.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() { _downloading = false; _error = error.toString(); });
    }
  }

  Future<void> _playOnline() async {
    final url = game.onlineUrl;
    if (url.isEmpty) {
      _showMessage('Este jogo ainda não tem uma versão online publicada.');
      return;
    }
    await _openNativeGame(<String, Object?>{
      'launchType': 'url',
      'url': url,
      'title': game.name,
      'orientation': game.orientation,
      'offline': false,
    });
    activityController.log(ActivityKind.game, game.name, url);
  }

  Future<void> _playOffline() async {
    final installed = _installed;
    if (installed == null) return;
    try {
      final htmlFile = File(installed.entryPath);
      if (!await htmlFile.exists()) throw FileSystemException('O ficheiro principal do jogo não existe.');
      final html = await htmlFile.readAsString();
      await _openNativeGame(<String, Object?>{
        'launchType': 'html',
        'html': html,
        'baseUrl': installed.baseUrl,
        'title': game.name,
        'orientation': game.orientation,
        'offline': true,
      });
      activityController.log(ActivityKind.game, game.name, 'offline://${game.id}');
    } catch (error) {
      _showMessage('Não foi possível iniciar o jogo offline: $error');
    }
  }

  Future<void> _openNativeGame(Map<String, Object?> arguments) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await _nativeGameChannel.invokeMethod<bool>('openGame', arguments);
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Não foi possível abrir o jogo.');
    } on MissingPluginException {
      _showMessage('O módulo nativo de jogos não está disponível nesta versão.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final bg = pageBg(context);
    final iconUrl = BrowseItCatalogApi.instance.resolveRemote(game.icon.isNotEmpty ? game.icon : game.cover);
    final coverUrl = BrowseItCatalogApi.instance.resolveRemote(game.cover.isNotEmpty ? game.cover : game.icon);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const AppMaterialIcon(AppIcons.arrowLeft)),
        actions: [
          IconButton(onPressed: () => _showMessage('A lista de desejos estará disponível numa atualização futura.'), icon: const AppMaterialIcon(AppIcons.bookmarkSimple)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') _checkInstalled();
              if (value == 'share') _showMessage('Partilha de jogos estará disponível numa atualização futura.');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Partilhar')),
              PopupMenuItem(value: 'refresh', child: Text('Verificar instalação')),
            ],
            icon: const AppMaterialIcon(AppIcons.dotsThreeVertical),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(top: false, bottom: true, child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            sliver: SliverToBoxAdapter(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(22), child: SizedBox(width: 104, height: 104, child: _DetailImage(uri: iconUrl?.toString()))),
                const SizedBox(width: 18),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(game.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 23, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -.35)),
                  if (game.developer.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(game.developer, style: TextStyle(color: accentColor(context), fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                  if (game.premium) ...[
                    const SizedBox(height: 5),
                    Text('Conteúdo premium', style: TextStyle(color: muted, fontSize: 13)),
                  ],
                ])),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 28, 22, 20), child: _GameFacts(game: game))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (game.offlineFiles.isNotEmpty || _installed != null)
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _downloading || _checkingInstall
                          ? null
                          : (_installed == null ? _download : _playOffline),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor(context),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: _downloading
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 11),
                              Text('A descarregar ${(_downloadProgress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ])
                          : _checkingInstall
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_installed == null ? 'Baixar para jogar offline' : 'Jogar offline', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  )
                else if (game.onlineUrl.isNotEmpty)
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _opening ? null : _playOnline,
                      icon: const AppMaterialIcon(AppIcons.playCircle, size: 21),
                      label: const Text('Jogar online', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(backgroundColor: accentColor(context), foregroundColor: Colors.white, shape: const StadiumBorder()),
                    ),
                  ),
                if (_downloading) ...[
                  const SizedBox(height: 10),
                  ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: _downloadProgress == 0 ? null : _downloadProgress, minHeight: 4, backgroundColor: pillColor(context), color: accentColor(context))),
                ],
                if ((_installed != null || game.offlineFiles.isNotEmpty) && game.onlineUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 52, child: OutlinedButton.icon(
                    onPressed: _opening ? null : _playOnline,
                    icon: const AppMaterialIcon(AppIcons.playCircle, size: 21),
                    label: const Text('Jogar online', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(shape: const StadiumBorder(), side: BorderSide(color: lineColor(context))),
                  )),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
                ],
              ]),
            ),
          ),
          if (game.screenshots.isNotEmpty) ...[
            SliverPadding(padding: const EdgeInsets.fromLTRB(22, 30, 22, 12), sliver: SliverToBoxAdapter(child: Text('Pré-visualizações', style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w700)))),
            SliverToBoxAdapter(
              child: SizedBox(height: 202, child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: game.screenshots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final uri = BrowseItCatalogApi.instance.resolveRemote(game.screenshots[index]);
                  return ClipRRect(borderRadius: BorderRadius.circular(17), child: AspectRatio(aspectRatio: 16 / 9, child: _DetailImage(uri: uri?.toString(), fit: BoxFit.cover)));
                },
              )),
            ),
          ] else if (coverUrl != null) ...[
            SliverPadding(padding: const EdgeInsets.fromLTRB(22, 30, 22, 0), sliver: SliverToBoxAdapter(child: ClipRRect(borderRadius: BorderRadius.circular(22), child: AspectRatio(aspectRatio: 16 / 9, child: _DetailImage(uri: coverUrl.toString()))))),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 36),
            sliver: SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Acerca deste jogo', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(height: 11),
                Text(game.longDescription.isNotEmpty ? game.longDescription : game.description, style: TextStyle(color: muted, fontSize: 15, height: 1.55)),
                if (game.features.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('Destaques', style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final feature in game.features) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [AppMaterialIcon(AppIcons.checkCircle, size: 19, color: accentColor(context)), const SizedBox(width: 9), Expanded(child: Text(feature, style: TextStyle(color: muted, fontSize: 14, height: 1.35)))])),
                ],
              ]),
            ),
          ),
        ],
      )),
    );
  }
}

class _GameFacts extends StatelessWidget {
  const _GameFacts({required this.game});
  final CatalogGame game;
  @override
  Widget build(BuildContext context) {
    final facts = <Widget>[];
    if (game.rating > 0) facts.add(_FactColumn(value: game.rating.toStringAsFixed(1), label: 'Avaliação', icon: AppIcons.star));
    if (game.ratingsCount > 0) facts.add(_FactColumn(value: _formatCount(game.ratingsCount), label: 'Avaliações'));
    if (game.ageRating.isNotEmpty) facts.add(_FactColumn(value: game.ageRating, label: 'Classificação'));
    if (formatCatalogSize(game.sizeBytes).isNotEmpty) facts.add(_FactColumn(value: formatCatalogSize(game.sizeBytes), label: 'Tamanho'));
    if (facts.isEmpty) return const SizedBox.shrink();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < facts.length; i++) ...[
        if (i > 0) Container(width: 1, height: 39, margin: const EdgeInsets.symmetric(horizontal: 13), color: lineColor(context)),
        Expanded(child: facts[i]),
      ],
    ]);
  }
}

class _FactColumn extends StatelessWidget {
  const _FactColumn({required this.value, required this.label, this.icon});
  final String value;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(color: mainText(context), fontSize: 17, fontWeight: FontWeight.w700)),
          if (icon != null) ...[const SizedBox(width: 2), AppMaterialIcon(icon!, size: 17, color: accentColor(context), fill: 1)],
        ]),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
      ]);
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({this.uri, this.fit = BoxFit.cover});
  final String? uri;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: pillColor(context), alignment: Alignment.center, child: AppMaterialIcon(AppIcons.sportsEsports, size: 36, color: accentColor(context)));
    if (uri == null || uri!.isEmpty) return fallback;
    return Image.network(uri!, fit: fit, errorBuilder: (_, __, ___) => fallback);
  }
}

String _formatCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)} M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)} mil';
  return count.toString();
}
