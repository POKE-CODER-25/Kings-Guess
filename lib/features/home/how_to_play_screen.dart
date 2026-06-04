import 'package:flutter/material.dart';

import '../../widgets/royal_background.dart';
import '../../widgets/royal_card.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              RoyalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 56,
                            color: Color(0xFFB83A4B),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How To Play',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _RuleLine(
                      icon: Icons.style_rounded,
                      title: 'Hidden roles',
                      text: 'Each player sees only their own royal role.',
                    ),
                    const _RuleLine(
                      icon: Icons.check_circle_rounded,
                      title: 'Correct guess',
                      text:
                          'Find the target role to score points and finish the round as a spectator.',
                    ),
                    const _RuleLine(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Wrong guess',
                      text:
                          'A wrong guess swaps roles with the chosen player, and they become the guesser.',
                    ),
                    const _RuleLine(
                      icon: Icons.groups_rounded,
                      title: 'Royal Court',
                      text:
                          'Completed players watch the rest of the round from the spectator list.',
                    ),
                    const _RuleLine(
                      icon: Icons.emoji_events_rounded,
                      title: 'Scoring',
                      text:
                          'Higher royal roles score more. Final rankings use total score.',
                    ),
                    const _RuleLine(
                      icon: Icons.wifi_off_rounded,
                      title: 'AFK and reconnect',
                      text:
                          'Disconnected players have 2 minutes to return before removal.',
                    ),
                    const _RuleLine(
                      icon: Icons.how_to_vote_rounded,
                      title: 'End game voting',
                      text:
                          'Any active player can request an early end. Everyone active must accept.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFB83A4B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
