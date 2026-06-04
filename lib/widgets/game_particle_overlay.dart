import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/polish_config.dart';

enum GameParticleStyle { dust, embers, sparkles, fog, confetti }

enum GameMood { normal, myTurn, correct, wrong, lowTimer, endGameVote }

class GameParticleOverlay extends StatefulWidget {
  const GameParticleOverlay({
    super.key,
    required this.style,
    this.intensity = 1,
    this.color,
    this.duration = const Duration(seconds: 7),
  });

  final GameParticleStyle style;
  final double intensity;
  final Color? color;
  final Duration duration;

  @override
  State<GameParticleOverlay> createState() => _GameParticleOverlayState();
}

class _GameParticleOverlayState extends State<GameParticleOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (disablePolishForDebug) return;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant GameParticleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (disablePolishForDebug) return;
    if (oldWidget.duration != widget.duration) {
      _controller?.duration = widget.duration;
      _controller?.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) return const SizedBox.shrink();
    final controller = _controller!;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CustomPaint(
            size: MediaQuery.sizeOf(context),
            painter: _ParticlePainter(
              progress: controller.value,
              style: widget.style,
              intensity: widget.intensity.clamp(0.0, 2.0),
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class GameMoodOverlay extends StatelessWidget {
  const GameMoodOverlay({super.key, required this.mood, this.enabled = true});

  final GameMood mood;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) return const SizedBox.shrink();
    if (!enabled) return const SizedBox.shrink();
    final config = _moodConfig(mood);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          child: Stack(
            key: ValueKey(mood),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: config.tint.withValues(alpha: config.tintAlpha),
                ),
                child: const SizedBox.expand(),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: config.center,
                    radius: config.radius,
                    colors: [
                      config.spotlight.withValues(alpha: config.spotlightAlpha),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              if (config.particleStyle != null)
                GameParticleOverlay(
                  style: config.particleStyle!,
                  intensity: config.particleIntensity,
                  duration: config.particleDuration,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.progress,
    required this.style,
    required this.intensity,
    required this.color,
  });

  final double progress;
  final GameParticleStyle style;
  final double intensity;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final count =
        (switch (style) {
                  GameParticleStyle.dust => 22,
                  GameParticleStyle.embers => 12,
                  GameParticleStyle.sparkles => 14,
                  GameParticleStyle.fog => 6,
                  GameParticleStyle.confetti => 22,
                } *
                intensity)
            .round();

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final seed = i * 41.0 + 13;
      final unitX = ((seed * 17) % 997) / 997;
      final unitY = ((seed * 29) % 991) / 991;
      final phase = (progress + (i * 0.037)) % 1.0;
      final x = unitX * size.width + math.sin(progress * math.pi * 2 + i) * 14;
      final y = switch (style) {
        GameParticleStyle.embers => size.height - phase * size.height,
        GameParticleStyle.confetti => phase * size.height,
        _ => (unitY * size.height + phase * 56) % size.height,
      };
      final alpha = switch (style) {
        GameParticleStyle.fog => 0.07,
        GameParticleStyle.confetti => 0.7,
        GameParticleStyle.sparkles =>
          (math.sin((progress * 2 + unitX) * math.pi) * 0.35 + 0.45),
        _ => 0.25,
      };
      paint.color = _particleColor(i).withValues(alpha: alpha);

      if (style == GameParticleStyle.confetti) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(progress * math.pi * 2 + i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 8, height: 13),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.restore();
      } else if (style == GameParticleStyle.fog) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
        canvas.drawCircle(Offset(x, y), 28 + (i % 3) * 14, paint);
        paint.maskFilter = null;
      } else {
        canvas.drawCircle(Offset(x, y), _radiusFor(i), paint);
      }
    }
  }

  Color _particleColor(int index) {
    if (color != null) return color!;
    return switch (style) {
      GameParticleStyle.dust => const Color(0xFFFFE6A0),
      GameParticleStyle.embers => const Color(0xFFFFA53B),
      GameParticleStyle.sparkles =>
        index.isEven ? const Color(0xFFFFF4D9) : const Color(0xFFE5B540),
      GameParticleStyle.fog => const Color(0xFFD8D0FF),
      GameParticleStyle.confetti => [
        const Color(0xFFE5B540),
        const Color(0xFFB83A4B),
        const Color(0xFF2E8B57),
        const Color(0xFF365D91),
      ][index % 4],
    };
  }

  double _radiusFor(int index) {
    return switch (style) {
      GameParticleStyle.sparkles => 1.8 + (index % 2),
      GameParticleStyle.embers => 2.2 + (index % 3),
      _ => 1.4 + (index % 3),
    };
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.style != style ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color;
  }
}

class _MoodConfig {
  const _MoodConfig({
    required this.tint,
    required this.tintAlpha,
    required this.spotlight,
    required this.spotlightAlpha,
    required this.center,
    required this.radius,
    this.particleStyle,
    this.particleIntensity = 1,
    this.particleDuration = const Duration(seconds: 7),
  });

  final Color tint;
  final double tintAlpha;
  final Color spotlight;
  final double spotlightAlpha;
  final Alignment center;
  final double radius;
  final GameParticleStyle? particleStyle;
  final double particleIntensity;
  final Duration particleDuration;
}

_MoodConfig _moodConfig(GameMood mood) {
  return switch (mood) {
    GameMood.normal => const _MoodConfig(
      tint: Color(0xFF000000),
      tintAlpha: 0,
      spotlight: Color(0xFFFFE6A0),
      spotlightAlpha: 0.08,
      center: Alignment.topCenter,
      radius: 1.1,
      particleStyle: GameParticleStyle.dust,
      particleIntensity: 0.75,
    ),
    GameMood.myTurn => const _MoodConfig(
      tint: Color(0xFFE5B540),
      tintAlpha: 0.05,
      spotlight: Color(0xFFFFF4D9),
      spotlightAlpha: 0.24,
      center: Alignment.center,
      radius: 0.82,
      particleStyle: GameParticleStyle.sparkles,
      particleIntensity: 1,
      particleDuration: Duration(seconds: 5),
    ),
    GameMood.correct => const _MoodConfig(
      tint: Color(0xFFE5B540),
      tintAlpha: 0.10,
      spotlight: Color(0xFFFFE6A0),
      spotlightAlpha: 0.34,
      center: Alignment.center,
      radius: 0.72,
      particleStyle: GameParticleStyle.sparkles,
      particleIntensity: 1.2,
      particleDuration: Duration(seconds: 4),
    ),
    GameMood.wrong => const _MoodConfig(
      tint: Color(0xFFB83A4B),
      tintAlpha: 0.14,
      spotlight: Color(0xFFB83A4B),
      spotlightAlpha: 0.22,
      center: Alignment.center,
      radius: 0.9,
      particleStyle: GameParticleStyle.fog,
      particleIntensity: 0.9,
      particleDuration: Duration(seconds: 8),
    ),
    GameMood.lowTimer => const _MoodConfig(
      tint: Color(0xFFB83A4B),
      tintAlpha: 0.06,
      spotlight: Color(0xFFFFA53B),
      spotlightAlpha: 0.18,
      center: Alignment.center,
      radius: 0.88,
      particleStyle: GameParticleStyle.embers,
      particleIntensity: 0.8,
      particleDuration: Duration(seconds: 4),
    ),
    GameMood.endGameVote => const _MoodConfig(
      tint: Color(0xFF161222),
      tintAlpha: 0.22,
      spotlight: Color(0xFFB83A4B),
      spotlightAlpha: 0.18,
      center: Alignment.topCenter,
      radius: 1.0,
      particleStyle: GameParticleStyle.fog,
      particleIntensity: 1,
      particleDuration: Duration(seconds: 9),
    ),
  };
}
