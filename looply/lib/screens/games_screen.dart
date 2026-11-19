import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../localization.dart';
import '../services/catalog_api.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';
import 'game_detail_screen.dart';

const String _brokenConsoleAnimation = 'assets/animations/game_console_broken.json';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  CatalogSnapshot? _catalog;
  String? _error;
  String _selectedCategory = 'all';
  bool _premiumOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog({bool force = false}) async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await BrowseItCatalogApi.instance.fetchCatalog(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        _catalog = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<CatalogGame> get _visibleGames {
    final source = _catalog?.games ?? const <CatalogGame>[];
    return source.where((game) {
      if (_selectedCategory != 'all' && game.category != _selectedCategory) return false;
      if (_premiumOnly && !game.premium) return false;
      return true;
    }).toList(growable: false);
  }

  void _openDetails(CatalogGame game) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => GameDetailScreen(game: game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final bg = pageBg(context);
    final games = _visibleGames;
    final offlineGames = games.where((game) => game.downloadUrl.isNotEmpty).toList(growable: false);
    final onlineGames = games.where((game) => game.downloadUrl.isEmpty).toList(growable: false);
    final catalogIsEmpty = (_catalog?.games.isEmpty ?? true);
    final categories = _catalog?.categories ?? const <CatalogCategory>[];
    final events = _catalog?.events ?? const <CatalogEvent>[];

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
        actions: [
          IconButton(
            tooltip: 'Atualizar catálogo',
            onPressed: _loading ? null : () => _loadCatalog(force: true),
            icon: AppMaterialIcon(AppIcons.arrowClockwise, color: muted),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading && _catalog == null
            ? Center(child: CircularProgressIndicator(color: accentColor(context), strokeWidth: 2.2))
            : _error != null && _catalog == null
                ? _CatalogErrorState(message: _error!, onRetry: () => _loadCatalog(force: true))
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _GameFilterRail(
                          categories: categories,
                          selectedCategory: _selectedCategory,
                          premiumOnly: _premiumOnly,
                          onCategoryChanged: (id) => setState(() { _selectedCategory = id; _premiumOnly = false; }),
                          onPremiumChanged: (value) => setState(() { _premiumOnly = value; _selectedCategory = 'all'; }),
                        ),
                      ),
                      if (games.isEmpty && catalogIsEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _GamesEmptyState(
                            onRetry: () => _loadCatalog(force: true),
                            apiMissing: !BrowseItCatalogApi.instance.isConfigured,
                          ),
                        )
                      else if (games.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'Não existem jogos nesta categoria.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: mutedText(context), fontSize: 14),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        if (offlineGames.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 25, 18, 13),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Expanded(child: Text('Jogos offline', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.35))),
                                  _SectionArrowButton(onTap: () => _loadCatalog(force: true)),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            sliver: SliverList.builder(
                              itemCount: offlineGames.length,
                              itemBuilder: (context, index) => Padding(
                                padding: EdgeInsets.only(bottom: index == offlineGames.length - 1 ? 0 : 18),
                                child: _OfflineGameRow(
                                  game: offlineGames[index],
                                  onTap: () => _openDetails(offlineGames[index]),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (onlineGames.isNotEmpty) ...[
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(20, offlineGames.isEmpty ? 25 : 8, 18, 13),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Expanded(child: Text('Jogos online', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.35))),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            sliver: SliverList.builder(
                              itemCount: onlineGames.length,
                              itemBuilder: (context, index) => Padding(
                                padding: EdgeInsets.only(bottom: index == onlineGames.length - 1 ? 0 : 18),
                                child: _OfflineGameRow(
                                  game: onlineGames[index],
                                  onTap: () => _openDetails(onlineGames[index]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (events.isNotEmpty && !_premiumOnly && _selectedCategory == 'all') ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 18, 14),
                          sliver: SliverToBoxAdapter(
                            child: Text('Eventos a decorrer agora', style: TextStyle(color: text, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.35)),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 330,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final game = _catalog!.games.where((item) => item.id == event.gameId).firstOrNull;
                                if (game == null) return const SizedBox.shrink();
                                return _GameEventCard(event: event, game: game, onTap: () => _openDetails(game));
                              },
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
      ),
    );
  }
}

class _GameFilterRail extends StatelessWidget {
  const _GameFilterRail({
    required this.categories,
    required this.selectedCategory,
    required this.premiumOnly,
    required this.onCategoryChanged,
    required this.onPremiumChanged,
  });
  final List<CatalogCategory> categories;
  final String selectedCategory;
  final bool premiumOnly;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onPremiumChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _GameFilterChip(
            icon: AppIcons.sportsEsports,
            label: 'Todos',
            selected: selectedCategory == 'all' && !premiumOnly,
            onTap: () { onCategoryChanged('all'); onPremiumChanged(false); },
          ),
          for (final category in categories)
            _GameFilterChip(
              icon: AppIcons.squaresFour,
              label: category.name,
              selected: selectedCategory == category.id,
              onTap: () => onCategoryChanged(category.id),
            ),
          _GameFilterChip(
            icon: AppIcons.sealCheck,
            label: 'Premium',
            selected: premiumOnly,
            onTap: () => onPremiumChanged(!premiumOnly),
          ),
        ],
      ),
    );
  }
}

class _GameFilterChip extends StatelessWidget {
  const _GameFilterChip({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor(context);
    final text = mainText(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? accent.withOpacity(.13) : pillColor(context),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppMaterialIcon(icon, size: 20, color: selected ? accent : text),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: selected ? accent : text, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SectionArrowButton extends StatelessWidget {
  const _SectionArrowButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: pillColor(context),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Center(child: AppMaterialIcon(AppIcons.arrowRight, size: 22, color: mainText(context)))),
        ),
      );
}

class _OfflineGameRow extends StatelessWidget {
  const _OfflineGameRow({required this.game, required this.onTap});
  final CatalogGame game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    final text = mainText(context);
    final iconUri = BrowseItCatalogApi.instance.resolveRemote(game.icon.isNotEmpty ? game.icon : game.cover);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(width: 88, height: 88, child: _RemoteGameImage(uri: iconUri?.toString(), fit: BoxFit.cover)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 1),
              Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(game.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 14, height: 1.3)),
              const SizedBox(height: 8),
              Wrap(spacing: 13, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (game.rating > 0) _MetaBadge(text: game.rating.toStringAsFixed(1), icon: AppIcons.star, iconColor: const Color(0xFF1A73E8)),
                if (formatCatalogSize(game.sizeBytes).isNotEmpty) Text(formatCatalogSize(game.sizeBytes), style: TextStyle(color: muted, fontSize: 13)),
                if (game.premium) _MetaBadge(text: 'Premium', icon: AppIcons.sealCheck, iconColor: accentColor(context)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.text, required this.icon, required this.iconColor});
  final String text;
  final IconData icon;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: TextStyle(color: mutedText(context), fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          AppMaterialIcon(icon, size: 16, color: iconColor, fill: 1),
        ]),
      );
}

class _RemoteGameImage extends StatelessWidget {
  const _RemoteGameImage({this.uri, this.fit = BoxFit.cover});
  final String? uri;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final accent = accentColor(context);
    final placeholder = Container(
      color: pillColor(context),
      alignment: Alignment.center,
      child: AppMaterialIcon(AppIcons.sportsEsports, size: 34, color: accent),
    );
    if (uri == null || uri!.isEmpty) return placeholder;
    return Image.network(uri!, fit: fit, filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class _GameEventCard extends StatelessWidget {
  const _GameEventCard({required this.event, required this.game, required this.onTap});
  final CatalogEvent event;
  final CatalogGame game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final banner = BrowseItCatalogApi.instance.resolveRemote(event.banner);
    final icon = BrowseItCatalogApi.instance.resolveRemote(game.icon.isNotEmpty ? game.icon : game.cover);
    return SizedBox(
      width: 342,
      child: Material(
        color: settingsCardColor(context),
        borderRadius: BorderRadius.circular(27),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              _RemoteGameImage(uri: banner?.toString()),
              Align(alignment: Alignment.bottomCenter, child: Container(height: 76, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(.82)])))),
              Positioned(left: 16, right: 16, bottom: 15, child: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
            ])),
            SizedBox(height: 80, child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 12, 10), child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(13), child: SizedBox(width: 52, height: 52, child: _RemoteGameImage(uri: icon?.toString()))),
              const SizedBox(width: 11),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(event.subtitle.isEmpty ? game.developer : event.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12)),
              ])),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: accentColor(context), borderRadius: BorderRadius.circular(999)), child: const Text('Ver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            ]))),
          ]),
        ),
      ),
    );
  }
}

class _GamesEmptyState extends StatelessWidget {
  const _GamesEmptyState({required this.onRetry, required this.apiMissing});
  final VoidCallback onRetry;
  final bool apiMissing;
  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 206, child: Lottie.asset(_brokenConsoleAnimation, repeat: true, fit: BoxFit.contain)),
        const SizedBox(height: 5),
        Text('Ainda não há jogos', textAlign: TextAlign.center, style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          apiMissing
              ? 'Liga o catálogo Render no build Android. Quando adicionares jogos ao repositório, eles aparecerão automaticamente aqui.'
              : 'O catálogo está vazio neste momento. Os jogos publicados no repositório aparecerão aqui automaticamente.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13.5, height: 1.45),
        ),
        const SizedBox(height: 15),
        TextButton.icon(onPressed: onRetry, icon: const AppMaterialIcon(AppIcons.arrowClockwise, size: 19), label: const Text('Atualizar')),
      ]),
    );
  }
}

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppMaterialIcon(AppIcons.wifiSlash, size: 42, color: mutedText(context)),
            const SizedBox(height: 12),
            Text('Não foi possível ligar ao catálogo', textAlign: TextAlign.center, style: TextStyle(color: mainText(context), fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: mutedText(context), fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ]),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
