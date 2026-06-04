import 'package:flutter/material.dart';

import '../config/polish_config.dart';
import '../core/theme/game_colors.dart';
import '../core/theme/game_gradients.dart';
import '../core/theme/game_shadows.dart';
import '../core/theme/game_spacing.dart';

enum GamePanelVariant { compact, dense, hero }

class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.variant = GamePanelVariant.compact,
    this.goldBorder = true,
  });

  final Widget child;
  final GamePanelVariant variant;
  final bool goldBorder;

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
    }

    final padding = switch (variant) {
      GamePanelVariant.dense => const EdgeInsets.all(14),
      GamePanelVariant.compact => const EdgeInsets.all(22),
      GamePanelVariant.hero => const EdgeInsets.all(28),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GameSpacing.radiusXl),
        gradient: const LinearGradient(
          colors: [GameColors.brightGold, GameColors.oldGold],
        ),
        boxShadow: GameShadows.panel,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GameSpacing.radiusLg),
          gradient: GameGradients.parchment,
          border: Border.all(
            color: goldBorder ? GameColors.parchmentDeep : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GameSpacing.radiusLg),
                    gradient: const RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.15,
                      colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
