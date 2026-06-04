import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_text_styles.dart';

class GameLoadingOverlay extends StatelessWidget {
  const GameLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = 'Loading...',
  });

  final bool isLoading;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: GameColors.woodDark.withValues(alpha: 0.28),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: GameColors.parchmentLight,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: GameColors.palaceGold, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: GameColors.ruby,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 12),
                      Text(message, style: GameTextStyles.sectionTitle),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
