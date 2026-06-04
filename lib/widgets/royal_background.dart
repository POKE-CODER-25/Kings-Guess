import 'package:flutter/material.dart';

import 'game_screen_background.dart';

class RoyalBackground extends StatelessWidget {
  const RoyalBackground({
    super.key,
    required this.child,
    this.type = GameScreenType.home,
  });

  final Widget child;
  final GameScreenType type;

  @override
  Widget build(BuildContext context) {
    return GameScreenBackground(type: type, child: child);
  }
}
