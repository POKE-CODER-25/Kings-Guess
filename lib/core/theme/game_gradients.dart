import 'package:flutter/material.dart';

import 'game_colors.dart';

class GameGradients {
  const GameGradients._();

  static const palace = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFD66F), Color(0xFFFFF3CA), Color(0xFFE59A55)],
  );

  static const nightCourt = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [GameColors.royalBlueDark, GameColors.royalBlue, Color(0xFF5D356B)],
  );

  static const table = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5A32), GameColors.wood, GameColors.woodDark],
  );

  static const parchment = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      GameColors.parchmentLight,
      GameColors.parchment,
      Color(0xFFFFE3A4),
    ],
  );

  static const goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GameColors.brightGold, GameColors.palaceGold, GameColors.oldGold],
  );

  static const blueButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3F63B8), GameColors.royalBlue, GameColors.royalBlueDark],
  );

  static const redButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE76670), GameColors.ruby, GameColors.rubyDark],
  );

  static const greenButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF52C77C), GameColors.emerald, GameColors.emeraldDark],
  );
}
