import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/catalog_api.dart';
import '../shell/browser_navigation.dart';
import '../theme.dart';
import 'material_symbols.dart';

final GlobalKey<NavigatorState> browseItNavigatorKey = GlobalKey<NavigatorState>();

/// Botão flutuante global: colocado no builder do MaterialApp, por cima do
/// Navigator, para continuar acessível em todas as telas e rotas da aplicação.
class GlobalSitesFloatingButton extends StatefulWidget {
  const GlobalSitesFloatingButton({super.key});

  @override
  State<GlobalSitesFloatingButton> createState() => _GlobalSitesFloatingButtonState();
}

class _GlobalSitesFloatingButtonState extends State<GlobalSitesFloatingButton> {
  static const double _buttonSize = 58;
  static const String _positionKey = 'browseit_global_sites_fab_position_v1';
  Offset? _position;
  bool _modalOpen = false;
  bool _dragging = false;
  Size? _areaSize;

  @override
  void initState() {
    super.initState();
    _restorePosition();
  }

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble('${_positionKey}_x');
      final y = prefs.getDouble('${_positionKey}_y');
      if (!mounted || x == null || y == null) return;
      setState(() => _position = Offset(x, y));
    } catch (_) {}
  }

  Future<void> _savePosition() async {
    final position = _position;
    if (position == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_positionKey}_x', position.dx);
      await prefs.setDouble('${_positionKey}_y', position.dy);
    } catch (_) {}
  }

  Offset _clampPosition(Offset value, Size size) => Offset(
        value.dx.clamp(8.0, (size.width - _buttonSize - 8).clamp(8.0, double.infinity)).toDouble(),
        value.dy.clamp(8.0, (size.height - _buttonSize - 8).clamp(8.0, double.infinity)).toDouble(),
      );

  void _openSites() async {
    if (_modalOpen || _dragging) return;
    final navContext = browseItNavigatorKey.currentContext;
    if (navContext == null) return;
    setState(() => _modalOpen = true);
    try {
      await showGeneralDialog<void>(
        context: navContext,
        barrierDismissible: true,
        barrierLabel: 'Fechar sites',
        barrierColor: Colors.black.withOpacity(.28),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => const _QuickSitesDialog(),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween<double>(begin: .94, end: 1).animate(curved), child: child),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _modalOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_modalOpen) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: _modalOpen,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            _areaSize = size;
            final fallback = Offset(
              (size.width - _buttonSize - 18).clamp(8.0, double.infinity).toDouble(),
              (size.height - _buttonSize - 104).clamp(8.0, double.infinity).toDouble(),
            );
            final current = _clampPosition(_position ?? fallback, size);
            if (_position == null || current != _position) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_modalOpen) setState(() => _position = current);
              });
            }
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: current.dx,
                  top: current.dy,
                  width: _buttonSize,
                  height: _buttonSize,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) { setState(() => _dragging = true); },
                    onPanUpdate: (details) {
                      setState(() {
                        _position = _clampPosition(current + details.delta, size);
                      });
                    },
                    onPanEnd: (_) {
                      final area = _areaSize;
                      final position = _position ?? current;
                      if (area != null) {
                        final snappedX = position.dx + (_buttonSize / 2) < area.width / 2
                            ? 8.0
                            : area.width - _buttonSize - 8.0;
                        setState(() {
                          _dragging = false;
                          _position = _clampPosition(Offset(snappedX, position.dy), area);
                        });
                      } else {
                        setState(() => _dragging = false);
                      }
                      _savePosition();
                    },
                    onTap: _openSites,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      scale: _dragging ? 1.08 : 1,
                      child: _QuickSitesFabVisual(dragging: _dragging),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickSitesFabVisual extends StatelessWidget {
  const _QuickSitesFabVisual({required this.dragging});
  final bool dragging;
  @override
  Widget build(BuildContext context) {
    final accent = accentColor(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xDD20252D) : const Color(0xEAFDFEFF),
            border: Border.all(color: accent.withOpacity(.48), width: 1.2),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(dragging ? .28 : .18), blurRadius: dragging ? 24 : 18, spreadRadius: 1, offset: const Offset(0, 5)),
              BoxShadow(color: Colors.black.withOpacity(dark ? .28 : .10), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Center(child: AppMaterialIcon(AppIcons.globe, size: 26, color: accent, weight: 500)),
        ),
      ),
    );
  }
}

class _QuickSitesDialog extends StatefulWidget {
  const _QuickSitesDialog();
  @override
  State<_QuickSitesDialog> createState() => _QuickSitesDialogState();
}

class _QuickSitesDialogState extends State<_QuickSitesDialog> {
  List<CatalogSite> _sites = const <CatalogSite>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites({bool force = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await BrowseItCatalogApi.instance.fetchCatalog(forceRefresh: force);
      if (!mounted) return;
      setState(() { _sites = result.sites; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Dialog(
      backgroundColor: popupSurfaceColor(context),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: MediaQuery.sizeOf(context).height * .68, minHeight: 310),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 17, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: accentColor(context).withOpacity(.12), shape: BoxShape.circle), child: Center(child: AppMaterialIcon(AppIcons.globe, color: accentColor(context), size: 22))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sites BrowseIt', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Os teus atalhos num só lugar', style: TextStyle(color: muted, fontSize: 12.5)),
              ])),
              IconButton(onPressed: () => _loadSites(force: true), tooltip: 'Atualizar', icon: AppMaterialIcon(AppIcons.arrowClockwise, color: muted, size: 21)),
              IconButton(onPressed: () => Navigator.of(context).pop(), tooltip: 'Fechar', icon: AppMaterialIcon(AppIcons.x, color: muted, size: 21)),
            ]),
            const SizedBox(height: 15),
            Divider(height: 1, color: lineColor(context)),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accentColor(context), strokeWidth: 2))
                  : _sites.isNotEmpty
                      ? ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _sites.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 7),
                          itemBuilder: (context, index) => _QuickSiteTile(site: _sites[index]),
                        )
                      : Center(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 68, height: 68, decoration: BoxDecoration(color: pillColor(context), shape: BoxShape.circle), child: Center(child: AppMaterialIcon(AppIcons.globe, size: 31, color: muted))),
                            const SizedBox(height: 14),
                            Text('Os teus sites aparecerão aqui', textAlign: TextAlign.center, style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(_error ?? 'A lista está vazia por enquanto. Os atalhos serão publicados no catálogo BrowseIt.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12.5, height: 1.4)),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              TextButton(onPressed: () => _loadSites(force: true), child: const Text('Tentar novamente')),
                            ],
                          ]),
                        )),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QuickSiteTile extends StatelessWidget {
  const _QuickSiteTile({required this.site});
  final CatalogSite site;
  @override
  Widget build(BuildContext context) {
    final logo = BrowseItCatalogApi.instance.resolveRemote(site.logo);
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => openOrbitTab(context, site.url, title: site.name),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 42, height: 42, child: logo == null
                ? Container(color: pillColor(context), child: Center(child: AppMaterialIcon(AppIcons.globe, color: accentColor(context))))
                : Image.network(logo.toString(), fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(color: pillColor(context), child: Center(child: AppMaterialIcon(AppIcons.globe, color: accentColor(context))))))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(site.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mainText(context), fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(site.description.isNotEmpty ? site.description : site.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mutedText(context), fontSize: 11.5)),
            ])),
            const SizedBox(width: 8),
            AppMaterialIcon(AppIcons.openInNew, color: mutedText(context), size: 19),
          ]),
        ),
      ),
    );
  }
}
