import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_text_styles.dart';
import 'game_panel.dart';

class GameEmptyState extends StatelessWidget {
  const GameEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      variant: GamePanelVariant.dense,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: GameColors.ruby),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GameTextStyles.sectionTitle,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GameTextStyles.body,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
