import 'package:flutter/material.dart';

import '../core/theme/game_colors.dart';

class GameDivider extends StatelessWidget {
  const GameDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _DividerLine()),
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: GameColors.oldGold,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: GameColors.parchmentLight),
          ),
        ),
        const Expanded(child: _DividerLine()),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [
            Color(0x00D99A2B),
            GameColors.oldGold,
            GameColors.brightGold,
            Color(0x00D99A2B),
          ],
        ),
      ),
    );
  }
}
