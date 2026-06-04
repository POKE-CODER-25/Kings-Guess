import 'package:flutter/material.dart';

import '../config/polish_config.dart';
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
    if (disablePolishForDebug) {
      return SafeArea(child: child);
    }
    return GameScreenBackground(type: type, child: child);
  }
}
