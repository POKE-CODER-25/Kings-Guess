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
    GameScreenType.game => GameGradients.nightCourt,
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
          top: 230,
          left: 32,
          child: _GlowCircle(
            size: 72,
            color: GameColors.brightGold.withValues(alpha: 0.18),
          ),
        ),
        Positioned(
          right: 88,
          top: 28,
          child: _GlowCircle(
            size: 54,
            color: GameColors.parchmentLight.withValues(alpha: 0.22),
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
