import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';
import 'sound_models.dart';
import 'sound_widgets.dart';
import 'dominant_color.dart';


class FullPlayerScreen extends StatefulWidget {
  final SoundTrack track;
  final AudioPlayer player;
  final PlaybackStatus status;
  final Duration position;
  final Duration totalDuration;
  final VoidCallback onTogglePlay;

  const FullPlayerScreen({
    super.key,
    required this.track,
    required this.player,
    required this.status,
    required this.position,
    required this.totalDuration,
    required this.onTogglePlay,
  });

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

enum _LyricsState { loading, found, notFound, error }

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  _LyricsState _lyricsState = _LyricsState.loading;
  String? _plainLyrics;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  PlaybackStatus _status = PlaybackStatus.idle;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  Color _dominantColor = kSoundPillSolidColor;
  bool _colorReady = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _position = widget.position;
    _totalDuration = widget.totalDuration;

    _playerStateSub = widget.player.playerStateStream.listen((state) {
      if (!mounted) return;
      final processing = state.processingState;
      PlaybackStatus next;
      if (processing == ProcessingState.loading ||
          processing == ProcessingState.buffering) {
        next = PlaybackStatus.buffering;
      } else if (state.playing) {
        next = PlaybackStatus.playing;
      } else {
        next = PlaybackStatus.paused;
      }
      if (next != _status) setState(() => _status = next);
    });
    _positionSub = widget.player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = widget.player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _totalDuration = dur);
    });

    _fetchLyrics();
    _extractDominantColor();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  Future<void> _extractDominantColor() async {
    final url = widget.track.thumbnailUrl;
    final fallback = Color(
      int.parse(widget.track.coverColorHex.replaceFirst('#', '0xFF')),
    );
    if (url == null) {
      if (mounted) setState(() {
        _dominantColor = fallback;
        _colorReady = true;
      });
      return;
    }
    final color = await DominantColorExtractor.extract(
      context,
      url,
      fallback: fallback,
    );
    if (mounted) {
      setState(() {
        _dominantColor = color;
        _colorReady = true;
      });
    }
  }

  // LRCLib: API pública, sem chave. Não testada em runtime real neste
  // ambiente — trate como não validada até correres num dispositivo real.
  Future<void> _fetchLyrics() async {
    setState(() => _lyricsState = _LyricsState.loading);
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {
        'track_name': widget.track.title,
        'artist_name': widget.track.artist,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        if (mounted) setState(() => _lyricsState = _LyricsState.error);
        return;
      }

      final List<dynamic> results = jsonDecode(response.body);
      if (results.isEmpty) {
        if (mounted) setState(() => _lyricsState = _LyricsState.notFound);
        return;
      }

      final first = results.first as Map<String, dynamic>;
      final plain = first['plainLyrics'] as String?;

      if (plain == null || plain.trim().isEmpty) {
        if (mounted) setState(() => _lyricsState = _LyricsState.notFound);
        return;
      }

      if (mounted) {
        setState(() {
          _plainLyrics = plain;
          _lyricsState = _LyricsState.found;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar letra: $e');
      if (mounted) setState(() => _lyricsState = _LyricsState.error);
    }
  }

  void _seekTo(double fraction) {
    if (_totalDuration == Duration.zero) return;
    widget.player.seek(_totalDuration * fraction);
  }

  String _formatDuration(Duration d) {
    final sign = d.isNegative ? '-' : '';
    final abs = d.abs();
    final minutes = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = abs.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$sign$minutes:$seconds';
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              widget.track.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    final bgColor = _colorReady ? _dominantColor : cover;
    final isPlaying = _status == PlaybackStatus.playing;
    final isBuffering = _status == PlaybackStatus.buffering;
    final isError = _status == PlaybackStatus.error;

    final progress = _totalDuration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0);
    final remaining = _totalDuration - _position;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(bgColor, Colors.black, 0.15)!,
            Color.lerp(bgColor, Colors.black, 0.55)!,
          ],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              // Drag handle, alinhado com o topo real de um bottom sheet.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Cabeçalho: nome do álbum/artista à esquerda (estilo referência),
              // sem botão de voltar sobreposto — o gesto de arrastar/tap fora
              // fecha o player, como no player de referência.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        track.artist.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: cover,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.45),
                                  blurRadius: 34,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: track.thumbnailUrl != null
                                ? Image.network(
                                    track.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        RoundedSymbols.musicNote, color: Colors.white, size: 60),
                                  )
                                : const Center(
                                    child: Icon(RoundedSymbols.musicNote,
                                        color: Colors.white, size: 60),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _showOptionsSheet,
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                child: AppIcon('more', size: 20, color: Colors.white.withOpacity(0.85)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SeekBar(progress: progress, onSeek: _seekTo),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.white.withOpacity(0.55)),
                                ),
                                Text(
                                  '-${_formatDuration(remaining)}',
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.white.withOpacity(0.55)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Não foi possível reproduzir esta faixa. Toque para tentar de novo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.6)),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.3,
                            child: AppIcon('skip_previous', size: 32, color: Colors.white),
                          ),
                          const SizedBox(width: 32),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onTogglePlay,
                            child: Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: isBuffering
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.black,
                                      ),
                                    )
                                  : isError
                                      ? const Icon(RoundedSymbols.refresh, size: 26, color: Colors.black)
                                      : AppIcon(
                                          isPlaying ? 'pause' : 'play',
                                          size: 28,
                                          color: Colors.black,
                                        ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          Opacity(
                            opacity: 0.3,
                            child: AppIcon('skip_next', size: 32, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _BottomBarIcon(icon: 'lyrics', filled: true),
                            _BottomBarIcon(icon: 'airplay'),
                            _BottomBarIcon(icon: 'queue'),
                            _BottomBarIcon(icon: 'shuffle'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _LyricsPanel(state: _lyricsState, lyrics: _plainLyrics),
                      const SizedBox(height: 20),
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

// Ícone da barra inferior. `icon` usa nomes do outline set — ver lista
// de ícones a adicionar na resposta em texto.
class _BottomBarIcon extends StatelessWidget {
  final String icon;
  final bool filled;
  const _BottomBarIcon({required this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: AppIcon(
          icon,
          size: 20,
          color: filled ? Colors.white : Colors.white.withOpacity(0.55),
        ),
      ),
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  final _LyricsState state;
  final String? lyrics;
  const _LyricsPanel({required this.state, required this.lyrics});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _LyricsState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        );
      case _LyricsState.notFound:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Letra não encontrada para esta faixa.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
        );
      case _LyricsState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Não foi possível carregar a letra agora.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
          ),
        );
      case _LyricsState.found:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            lyrics ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.8,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }
}