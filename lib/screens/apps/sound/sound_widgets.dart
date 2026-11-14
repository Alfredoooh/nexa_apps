import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/widgets.dart';
import 'sound_models.dart';


const Color kSoundPillSolidColor = Color(0xFF1C1C1E);

// ─────────────────────────────────────────────────────────────
// BOTÃO VOLTAR REUTILIZÁVEL
// ─────────────────────────────────────────────────────────────

class ScreenBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback? onTap;
  const ScreenBackButton({super.key, required this.s, this.onTap});
  @override
  State<ScreenBackButton> createState() => _ScreenBackButtonState();
}

class _ScreenBackButtonState extends State<ScreenBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap ?? () => Navigator.of(context).pop(),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: AppIcon('back', size: 20, color: widget.s.onSurface),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÃO CIRCULAR GENÉRICO
// ─────────────────────────────────────────────────────────────

class CircularIconButton extends StatefulWidget {
  final AppColorScheme s;
  final double size;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;
  const CircularIconButton({
    super.key,
    required this.s,
    required this.size,
    required this.onTap,
    required this.child,
    this.background,
  });

  @override
  State<CircularIconButton> createState() => _CircularIconButtonState();
}

class _CircularIconButtonState extends State<CircularIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.background ?? widget.s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: widget.s.cardShadow,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PILL FLUTUANTE (mini player)
// ─────────────────────────────────────────────────────────────

class FloatingPlayerBar extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack? currentTrack;
  final PlaybackStatus status;
  final VoidCallback onTogglePlay;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFullPlayer;

  const FloatingPlayerBar({
    super.key,
    required this.s,
    required this.currentTrack,
    required this.status,
    required this.onTogglePlay,
    required this.onOpenFavorites,
    required this.onOpenSearch,
    required this.onOpenFullPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircularIconButton(
            s: s,
            size: 56,
            onTap: onOpenFavorites,
            child: AppIcon('bookmark', color: s.onSurface, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axis: Axis.horizontal,
                  child: child,
                ),
              ),
              child: currentTrack == null
                  ? PlayerSkeletonPill(key: const ValueKey('skeleton'), s: s)
                  : GestureDetector(
                      key: ValueKey(currentTrack!.videoId),
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpenFullPlayer,
                      child: PlayerPill(
                        s: s,
                        track: currentTrack!,
                        status: status,
                        onTogglePlay: onTogglePlay,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          CircularIconButton(
            s: s,
            size: 56,
            onTap: onOpenSearch,
            child: AppIcon('search', color: s.onSurface, size: 22),
          ),
        ],
      ),
    );
  }
}

class PlayerPill extends StatelessWidget {
  final AppColorScheme s;
  final SoundTrack track;
  final PlaybackStatus status;
  final VoidCallback onTogglePlay;
  const PlayerPill({
    super.key,
    required this.s,
    required this.track,
    required this.status,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    final cover = Color(int.parse(track.coverColorHex.replaceFirst('#', '0xFF')));
    final isBuffering = status == PlaybackStatus.buffering;
    final isPlaying = status == PlaybackStatus.playing;
    final isError = status == PlaybackStatus.error;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: kSoundPillSolidColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40,
              height: 40,
              child: track.thumbnailUrl != null
                  ? Image.network(
                      track.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: cover),
                    )
                  : ColoredBox(
                      color: cover,
                      child: const Icon(RoundedSymbols.musicNote, color: Colors.white, size: 18),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isError ? 'Erro ao reproduzir' : track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isError
                        ? const Color(0xFFFF6B6B)
                        : Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTogglePlay,
            child: SizedBox(
              width: 36,
              height: 36,
              child: isBuffering
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : isError
                      ? const Icon(RoundedSymbols.refresh, color: Colors.white, size: 20)
                      : AppIcon(
                          isPlaying ? 'pause' : 'play',
                          color: Colors.white,
                          size: 20,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSkeletonPill extends StatefulWidget {
  final AppColorScheme s;
  const PlayerSkeletonPill({super.key, required this.s});
  @override
  State<PlayerSkeletonPill> createState() => _PlayerSkeletonPillState();
}

class _PlayerSkeletonPillState extends State<PlayerSkeletonPill>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final blockOpacity = 0.18 + 0.10 * _controller.value;
        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: kSoundPillSolidColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(blockOpacity),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 11,
                      width: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(blockOpacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 9,
                      width: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(blockOpacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(blockOpacity),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SEEK BAR
// ─────────────────────────────────────────────────────────────

class SeekBar extends StatelessWidget {
  final double progress;
  final ValueChanged<double> onSeek;
  final Color activeColor;
  final Color inactiveColor;
  const SeekBar({
    super.key,
    required this.progress,
    required this.onSeek,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x2EFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        onTapUp: (d) => onSeek((d.localPosition.dx / width).clamp(0.0, 1.0)),
        onHorizontalDragUpdate: (d) =>
            onSeek((d.localPosition.dx / width).clamp(0.0, 1.0)),
        child: SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: inactiveColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}