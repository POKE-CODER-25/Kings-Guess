import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';

class GameSectionTitle extends StatelessWidget {
  const GameSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [GameColors.brightGold, GameColors.oldGold],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GameColors.parchmentLight, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55351A10),
                  blurRadius: 0,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 19, color: GameColors.woodDark),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GameColors.woodDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GameColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
