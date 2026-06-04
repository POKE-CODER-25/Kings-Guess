import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_gradients.dart';

enum GameScreenType { auth, home, lobby, game, result }

class GameScreenBackground extends StatelessWidget {
  const GameScreenBackground({
    super.key,
    required this.child,
    this.type = GameScreenType.home,
  });

  final Widget child;
  final GameScreenType type;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: _gradientFor(type)),
          child: const SizedBox.expand(),
        ),
        const _DecorativeCourtShapes(),
        const _FloatingDust(),
        SafeArea(child: child),
      ],
    );
  }
}

Gradient _gradientFor(GameScreenType type) {
  return switch (type) {
    GameScreenType.auth => GameGradients.palace,
    GameScreenType.home => GameGradients.palace,
    GameScreenType.lobby => GameGradients.palace,
    GameScreenType.game => GameGradients.table,
    GameScreenType.result => GameGradients.nightCourt,
  };
}

class _DecorativeCourtShapes extends StatelessWidget {
  const _DecorativeCourtShapes();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 28,
          left: 20,
          child: Icon(
            Icons.castle_rounded,
            size: 96,
            color: GameColors.woodDark.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          right: -40,
          top: 90,
          child: _GlowCircle(
            size: 150,
            color: GameColors.candle.withValues(alpha: 0.28),
          ),
        ),
        Positioned(
          left: -55,
          bottom: 30,
          child: _GlowCircle(
            size: 170,
            color: GameColors.ruby.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          right: 24,
          bottom: 18,
          child: Icon(
            Icons.shield_rounded,
            size: 130,
            color: GameColors.royalBlueDark.withValues(alpha: 0.09),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _FloatingDust extends StatefulWidget {
  const _FloatingDust();

  @override
  State<_FloatingDust> createState() => _FloatingDustState();
}

class _FloatingDustState extends State<_FloatingDust>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: size,
            painter: _DustPainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  const _DustPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = GameColors.candle.withValues(alpha: 0.28);
    for (var i = 0; i < 16; i++) {
      final seed = i * 37.0;
      final x = ((seed * 11) % size.width) + math.sin(progress * 6.28 + i) * 9;
      final y = ((seed * 17 + progress * 48) % size.height);
      canvas.drawCircle(Offset(x, y), 1.5 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
