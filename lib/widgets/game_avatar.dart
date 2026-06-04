import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';

class GameAvatar extends StatelessWidget {
  const GameAvatar({
    super.key,
    required this.label,
    this.icon = Icons.person_rounded,
    this.isHost = false,
    this.isOnline = true,
  });

  final String label;
  final IconData icon;
  final bool isHost;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [GameColors.candle, GameColors.palaceGold],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: GameColors.parchmentLight, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332B160D),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            isHost ? Icons.workspace_premium_rounded : icon,
            color: GameColors.ruby,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isOnline ? GameColors.emerald : GameColors.disabled,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
