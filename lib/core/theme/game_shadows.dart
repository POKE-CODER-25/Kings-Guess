import 'package:flutter/material.dart';

import 'game_colors.dart';

class GameShadows {
  const GameShadows._();

  static const panel = [
    BoxShadow(color: GameColors.shadow, blurRadius: 24, offset: Offset(0, 12)),
  ];

  static const button = [
    BoxShadow(color: Color(0x80351A10), blurRadius: 0, offset: Offset(0, 5)),
    BoxShadow(color: Color(0x332B160D), blurRadius: 14, offset: Offset(0, 9)),
  ];

  static const buttonPressed = [
    BoxShadow(color: Color(0x66351A10), blurRadius: 0, offset: Offset(0, 2)),
  ];

  static const glowGold = [
    BoxShadow(color: Color(0x99F4B83F), blurRadius: 22, spreadRadius: 1),
  ];
}
