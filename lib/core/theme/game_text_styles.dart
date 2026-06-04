import 'package:flutter/material.dart';

import 'game_colors.dart';

class GameTextStyles {
  const GameTextStyles._();

  static const giantTitle = TextStyle(
    fontSize: 38,
    height: 1.02,
    fontWeight: FontWeight.w900,
    color: GameColors.woodDark,
  );

  static const screenTitle = TextStyle(
    fontSize: 28,
    height: 1.08,
    fontWeight: FontWeight.w900,
    color: GameColors.woodDark,
  );

  static const sectionTitle = TextStyle(
    fontSize: 20,
    height: 1.15,
    fontWeight: FontWeight.w900,
    color: GameColors.woodDark,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.28,
    fontWeight: FontWeight.w600,
    color: GameColors.ink,
  );

  static const smallLabel = TextStyle(
    fontSize: 13,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: GameColors.mutedInk,
  );

  static const scoreNumber = TextStyle(
    fontSize: 28,
    height: 1,
    fontWeight: FontWeight.w900,
    color: GameColors.palaceGold,
  );

  static const timer = TextStyle(
    fontSize: 24,
    height: 1,
    fontWeight: FontWeight.w900,
    color: GameColors.royalBlueDark,
  );

  static const danger = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: GameColors.ruby,
  );
}
