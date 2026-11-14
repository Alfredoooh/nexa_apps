import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';
import 'sound_models.dart';


class SoundSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final Future<void> Function(SoundTrack) onPlay;
  final SoundTrack? currentTrack;
  final PlaybackStatus status;

  const SoundSearchScreen({
    super.key,
    this.initialQuery,
    required this.onPlay,
    required this.currentTrack,
    required this.status,
  });

  @override
  State<SoundSearchScreen> createState() => _SoundSearchScreenState();
}

class _SoundSearchScreenState extends State<SoundSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final YoutubeExplode _yt = YoutubeExplode();

  String _query = '';
  List<SoundTrack> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _ctrl.text = widget.initialQuery!;
      _query = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _yt.close();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final searchResults = await _yt.search.search(query);
      final tracks = <SoundTrack>[];
      for (final video in searchResults) {
        tracks.add(SoundTrack(
          title: video.title,
          artist: video.author,
          coverColorHex: '#2e8bc9',
          thumbnailUrl: video.thumbnails.mediumResUrl,
          videoId: video.id.value,
        ));
        if (tracks.length >= 25) break;
      }
      if (!mounted) return;
      setState(() {
        _results = tracks;
        _loading = false;
        _error = tracks.isEmpty ? 'Sem resultados para "$query"' : null;
      });
    } catch (e) {
      debugPrint('Erro na pesquisa: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível pesquisar agora. Tente de novo.';
      });
    }
  }

  /// Toca imediatamente ao tocar num resultado — pedido explícito de
  /// "começar tocando o áudio de tudo que é pesquisado".
  void _onTapResult(SoundTrack track) {
    widget.onPlay(track);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: s.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildBody(s),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: keyboardInset > 0
                    ? keyboardInset + 8
                    : MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: s.cardBackground,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: s.cardShadow,
                      ),
                      child: Row(children: [
                        AppIcon('search', color: s.onSurfaceVariant, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            onChanged: _onChanged,
                            onSubmitted: _performSearch,
                            style: TextStyle(fontSize: 15, color: s.onSurface),
                            cursorColor: s.primary,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Pesquisar músicas...',
                              hintStyle: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _ctrl.clear();
                                _query = '';
                                _results = [];
                                _error = null;
                              });
                            },
                            child: AppIcon('close', color: s.onSurfaceVariant, size: 14),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.cardBackground,
                        shape: BoxShape.circle,
                        boxShadow: s.cardShadow,
                      ),
                      child: AppIcon('close', color: s.onSurfaceVariant, size: 16),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorScheme s) {
    if (_query.isEmpty) {
      return _InitialSearchPrompt(key: const ValueKey('initial'), s: s);
    }
    if (_loading) {
      return _SearchResultsSkeleton(key: const ValueKey('loading'), s: s);
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('results'),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (_, i) {
        final track = _results[i];
        final isCurrent = widget.currentTrack == track;
        return _SearchResultTile(
          s: s,
          track: track,
          isCurrent: isCurrent,
          status: isCurrent ? widget.status : PlaybackStatus.idle,
          onTap: () => _onTapResult(track),
        );
      },
    );
  }
}

class _SearchResultsSkeleton extends StatefulWidget {
  final AppColorScheme s;
  const _SearchResultsSkeleton({super.key, required this.s});
  @override
  State<_SearchResultsSkeleton> createState() => _SearchResultsSkeletonState();
}

class _SearchResultsSkeletonState extends State<_SearchResultsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final opacity = 0.35 + 0.25 * _controller.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: s.hover.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 160,
                        decoration: BoxDecoration(
                          color: s.hover.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 11,
                        width: 100,
                        decoration: BoxDecoration(
                          color: s.hover.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

class _InitialSearchPrompt extends StatelessWidget {
  final AppColorScheme s;
  const _InitialSearchPrompt({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.65,
              child: AppIcon('search', color: s.onSurfaceVariant, size: 52),
            ),
            const SizedBox(height: 18),
            Text(
              'Pesquise músicas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Digite para encontrar faixas e artistas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final bool isCurrent;
  final PlaybackStatus status;
  final VoidCallback onTap;
  const _SearchResultTile({
    required this.s,
    required this.track,
    required this.isCurrent,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    final isBuffering = status == PlaybackStatus.buffering;
    final isPlaying = status == PlaybackStatus.playing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        color: isCurrent ? s.primary.withOpacity(0.06) : Colors.transparent,
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  track.thumbnailUrl != null
                      ? Image.network(
                          track.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(color: cover),
                        )
                      : ColoredBox(
                          color: cover,
                          child: const Icon(RoundedSymbols.musicNote, color: Colors.white, size: 22),
                        ),
                  if (isCurrent)
                    Container(
                      color: Colors.black.withOpacity(0.35),
                      alignment: Alignment.center,
                      child: isBuffering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isPlaying ? RoundedSymbols.pause : RoundedSymbols.playArrow,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? s.primary : s.onSurface)),
                const SizedBox(height: 3),
                Text('Música • ${track.artist}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AppIcon('more', size: 18, color: s.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }
}