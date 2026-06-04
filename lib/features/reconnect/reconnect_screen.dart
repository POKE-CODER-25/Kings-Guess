import 'package:flutter/material.dart';

import '../../widgets/royal_background.dart';
import '../../widgets/royal_card.dart';

class ReconnectScreen extends StatelessWidget {
  const ReconnectScreen({super.key, this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackground(
        child: Center(
          child: RoyalCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  'Reconnecting to your game...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (roomId != null) ...[
                  const SizedBox(height: 8),
                  Text('Room $roomId', textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
