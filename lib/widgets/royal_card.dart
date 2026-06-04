import 'package:flutter/material.dart';

import 'game_panel.dart';

class RoyalCard extends StatelessWidget {
  const RoyalCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GamePanel(child: child);
  }
}
