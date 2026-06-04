import 'package:flutter/material.dart';

import '../config/polish_config.dart';
import 'game_panel.dart';

class RoyalCard extends StatelessWidget {
  const RoyalCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
    }
    return GamePanel(child: child);
  }
}
