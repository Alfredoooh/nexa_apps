// ══════════════════════════════════════════════════════════════
// FILE: lib/apps/sound.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';
import '../../../core/navigation/app_page_route.dart';
import '../all_apps_screen.dart';
import 'sound_models.dart';
import 'sound_widgets.dart';
import 'sound_player_full.dart';
import 'sound_search_screen.dart';


class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});
  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> with ThemeReactive<SoundScreen> {
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _player = AudioPlayer();

  List<SoundSection> _sections = [];
  bool _loadingFeed = true;
  String? _feedError;
  String _activeCategoryId = kSoundCategories.first.id;

  SoundTrack? _currentTrack;
  PlaybackStatus _status = PlaybackStatus.idle;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    soundTabController.addListener(_onPendingSearch);
    _fetchFeed();

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final processing = state.processingState;
      PlaybackStatus next;
      if (processing == ProcessingState.loading ||
          processing == ProcessingState.buffering) {
        next = PlaybackStatus.buffering;
      } else if (processing == ProcessingState.completed) {
        next = PlaybackStatus.paused;
      } else if (state.playing) {
        next = PlaybackStatus.playing;
      } else {
        next = _status == PlaybackStatus.error ? PlaybackStatus.error : PlaybackStatus.paused;
      }
      if (next != _status) {
        setState(() => _status = next);
      }
    });
    _positionSub = _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _totalDuration = dur);
    });
  }

  @override
  void dispose() {
    soundTabController.removeListener(_onPendingSearch);
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _yt.close();
    super.dispose();
  }

  void _onPendingSearch() {
    final query = soundTabController.pendingSearch;
    if (query != null) {
      soundTabController.consumePendingSearch();
      Navigator.of(context).push(
        AppPageRoute(
          builder: (_) => SoundSearchScreen(
            initialQuery: query,
            onPlay: _playTrack,
            currentTrack: _currentTrack,
            status: _status,
          ),
        ),
      );
    }
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _loadingFeed = true;
      _feedError = null;
    });

    try {
      final sections = <SoundSection>[];
      for (final category in kSoundCategories) {
        final searchResults = await _yt.search.search(category.seedQuery);
        final tracks = <SoundTrack>[];
        for (final video in searchResults) {
          tracks.add(SoundTrack(
            title: video.title,
            artist: video.author,
            coverColorHex: _colorForSeed(video.id.value),
            thumbnailUrl: video.thumbnails.mediumResUrl,
            videoId: video.id.value,
          ));
          if (tracks.length >= 12) break;
        }
        sections.add(SoundSection(title: category.label, tracks: tracks));
      }

      if (!mounted) return;
      final hasAny = sections.any((s) => s.tracks.isNotEmpty);
      setState(() {
        _sections = sections;
        _loadingFeed = false;
        _feedError = hasAny ? null : 'Nenhuma música encontrada agora.';
      });
    } catch (e) {
      debugPrint('Erro ao buscar feed: $e');
      if (!mounted) return;
      setState(() {
        _loadingFeed = false;
        _feedError = 'Não foi possível carregar o feed.';
      });
    }
  }

  String _colorForSeed(String seed) {
    const palette = [
      '#2e8bc9',
      '#c9622e',
      '#7a4fd1',
      '#2ec9a0',
      '#d13f6a',
      '#c9a72e',
    ];
    final idx = seed.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;
    return palette[idx];
  }

  Future<void> _playTrack(SoundTrack track) async {
    setState(() {
      _currentTrack = track;
      _status = PlaybackStatus.buffering;
      _position = Duration.zero;
      _totalDuration = Duration.zero;
    });

    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(track.videoId)
          .timeout(const Duration(seconds: 15));

      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) {
        throw Exception('Sem stream de áudio disponível para esta faixa');
      }
      final streamInfo = audioStreams.withHighestBitrate();

      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(streamInfo.url.toString())),
      );
      await _player.play();

      if (!mounted) return;
      setState(() => _status = PlaybackStatus.playing);
    } catch (e) {
      debugPrint('Erro ao tocar "${track.title}": $e');
      if (!mounted) return;
      setState(() => _status = PlaybackStatus.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível tocar "${track.title}".')),
      );
    }
  }

  void _togglePlay(SoundTrack track) {
    if (_currentTrack == track) {
      _onGlobalTogglePlay();
    } else {
      _playTrack(track);
    }
  }

  void _onGlobalTogglePlay() {
    if (_currentTrack == null) return;
    if (_status == PlaybackStatus.error) {
      _playTrack(_currentTrack!);
      return;
    }
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _openApps() {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const AllAppsScreen()),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => SoundSearchScreen(
          onPlay: _playTrack,
          currentTrack: _currentTrack,
          status: _status,
        ),
      ),
    );
  }

  void _openFullPlayer() {
    if (_currentTrack == null) return;
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => FullPlayerScreen(
          track: _currentTrack!,
          player: _player,
          status: _status,
          position: _position,
          totalDuration: _totalDuration,
          onTogglePlay: _onGlobalTogglePlay,
        ),
      ),
    );
  }

  void _onCategoryTap(SoundCategory category) {
    setState(() => _activeCategoryId = category.id);
    final index = kSoundCategories.indexWhere((c) => c.id == category.id);
    if (index >= 0 && index < _sections.length && _sections[index].tracks.isNotEmpty) {
      _sectionKeys[index].currentContext?.let((ctx) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  final List<GlobalKey> _sectionKeys =
      List.generate(kSoundCategories.length, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: s.statusBarStyle,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Stack(children: [
              _buildFeed(s),
              _SoundAppBar(s: s, onOpenApps: _openApps),
              FloatingPlayerBar(
                s: s,
                currentTrack: _currentTrack,
                status: _status,
                onTogglePlay: _onGlobalTogglePlay,
                onOpenFavorites: () {},
                onOpenSearch: _openSearch,
                onOpenFullPlayer: _openFullPlayer,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(AppColorScheme s) {
    if (_loadingFeed) {
      return _FeedSkeleton(s: s);
    }
    if (_feedError != null && _sections.every((sec) => sec.tracks.isEmpty)) {
      return _FeedErrorState(s: s, message: _feedError!, onRetry: _fetchFeed);
    }
    return RefreshIndicator(
      onRefresh: _fetchFeed,
      color: s.primary,
      backgroundColor: s.cardBackground,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CategoryChips(
              s: s,
              activeId: _activeCategoryId,
              onTap: _onCategoryTap,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 128),
            sliver: SliverList.builder(
              itemCount: _sections.length,
              itemBuilder: (_, i) {
                final section = _sections[i];
                if (section.tracks.isEmpty) return const SizedBox.shrink();
                return _FeedSectionRow(
                  key: _sectionKeys[i],
                  s: s,
                  section: section,
                  currentTrack: _currentTrack,
                  status: _status,
                  onTap: _togglePlay,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ─────────────────────────────────────────────────────────────
// CHIPS DE CATEGORIA
// ─────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final AppColorScheme s;
  final String activeId;
  final ValueChanged<SoundCategory> onTap;
  const _CategoryChips({required this.s, required this.activeId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 88, 16, 6),
        itemCount: kSoundCategories.length,
        itemBuilder: (_, i) {
          final category = kSoundCategories[i];
          final active = category.id == activeId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? s.primary : s.cardBackground,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active ? null : s.cardShadowSoft,
                ),
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: active ? s.onPrimary : s.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEÇÃO HORIZONTAL DO FEED
// ─────────────────────────────────────────────────────────────

class _FeedSectionRow extends StatelessWidget {
  final AppColorScheme s;
  final SoundSection section;
  final SoundTrack? currentTrack;
  final PlaybackStatus status;
  final ValueChanged<SoundTrack> onTap;

  const _FeedSectionRow({
    super.key,
    required this.s,
    required this.section,
    required this.currentTrack,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text(
            section.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: s.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.tracks.length,
            itemBuilder: (_, i) {
              final track = section.tracks[i];
              final isCurrent = currentTrack == track;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _AlbumCard(
                  s: s,
                  track: track,
                  isCurrent: isCurrent,
                  status: isCurrent ? status : PlaybackStatus.idle,
                  onTap: () => onTap(track),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlbumCard extends StatefulWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final bool isCurrent;
  final PlaybackStatus status;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.s,
    required this.track,
    required this.isCurrent,
    required this.status,
    required this.onTap,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _pressed = false;

  static const double _size = 148;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final track = widget.track;
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    final isBuffering = widget.status == PlaybackStatus.buffering;
    final isPlaying = widget.status == PlaybackStatus.playing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: _size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _size,
                height: _size,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cover,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: s.cardShadowSoft,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (track.thumbnailUrl != null)
                      Image.network(
                        track.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(RoundedSymbols.musicNote, color: Colors.white, size: 40),
                      )
                    else
                      const Center(
                        child: Icon(RoundedSymbols.musicNote, color: Colors.white, size: 40),
                      ),
                    AnimatedOpacity(
                      opacity: widget.isCurrent ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        alignment: Alignment.center,
                        child: isBuffering
                            ? const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                isPlaying ? RoundedSymbols.pauseCircle : RoundedSymbols.playCircle,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: s.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKELETON LOADER DO FEED
// ─────────────────────────────────────────────────────────────

class _FeedSkeleton extends StatefulWidget {
  final AppColorScheme s;
  const _FeedSkeleton({required this.s});
  @override
  State<_FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<_FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
      padding: const EdgeInsets.fromLTRB(0, 88, 0, 128),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (_, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Container(
                  height: 17,
                  width: 160,
                  decoration: BoxDecoration(
                    color: s.hover.withOpacity(0.35 + 0.25 * _controller.value),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 196,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (_, __) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) {
                        final opacity = 0.35 + 0.25 * _controller.value;
                        return SizedBox(
                          width: 148,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 148,
                                height: 148,
                                decoration: BoxDecoration(
                                  color: s.hover.withOpacity(opacity),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 11,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: s.hover.withOpacity(opacity),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 9,
                                width: 70,
                                decoration: BoxDecoration(
                                  color: s.hover.withOpacity(opacity),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ESTADO DE ERRO DO FEED — botão "Recarregar" em texto, explícito
// ─────────────────────────────────────────────────────────────

class _FeedErrorState extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  final VoidCallback onRetry;
  const _FeedErrorState({required this.s, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(RoundedSymbols.cloudOff, color: s.onSurfaceVariant, size: 40),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Recarregar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: s.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// APPBAR
// ─────────────────────────────────────────────────────────────

class _SoundAppBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onOpenApps;
  const _SoundAppBar({required this.s, required this.onOpenApps});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.pageBackground, s.pageBackground.withOpacity(0.0)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sound',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: s.onSurface,
              ),
            ),
            CircularIconButton(
              s: s,
              size: 40,
              onTap: onOpenApps,
              child: Image.asset(
                'assets/icons/png/apps.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}