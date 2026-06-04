import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';
import '../core/theme/game_text_styles.dart';

class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.castle_rounded,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: GameColors.candle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GameColors.palaceGold, width: 2),
          ),
          child: Icon(icon, color: GameColors.ruby, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GameTextStyles.screenTitle),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GameTextStyles.smallLabel,
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
