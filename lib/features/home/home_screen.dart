import 'package:flutter/material.dart';

import '../../core/theme/game_colors.dart';
import '../../config/polish_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/game_badge.dart';
import '../../widgets/game_divider.dart';
import '../../widgets/game_header.dart';
import '../../widgets/game_section_title.dart';
import '../../widgets/royal_nav.dart';
import '../rooms/create_room_screen.dart';
import '../rooms/join_room_screen.dart';
import 'how_to_play_screen.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.username, this.initialMessage});

  final String username;
  final String? initialMessage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _shownInitialMessage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shownInitialMessage || widget.initialMessage == null) return;
    _shownInitialMessage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint(
        'AUTO TOAST DISABLED: home route event: ${widget.initialMessage}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final username = widget.username;

    return Scaffold(
      body: RoyalBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  tooltip: 'Logout',
                  onPressed: authService.signOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
              const SizedBox(height: 8),
              RoyalCard(
                child: Column(
                  children: [
                    GameHeader(
                      title: "King's Guess",
                      subtitle: 'A royal hidden-role party game',
                      icon: Icons.castle_rounded,
                      trailing: GameBadge(
                        label: '@$username',
                        icon: Icons.person_rounded,
                        color: GameColors.ruby,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _FloatingRoyalCard(),
                    const SizedBox(height: 20),
                    const GameDivider(),
                    const SizedBox(height: 24),
                    RoyalButton(
                      label: 'Create Court',
                      icon: Icons.add_home_work_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          royalRoute(CreateRoomScreen(username: username)),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    RoyalButton(
                      label: 'Join Court',
                      icon: Icons.group_add_rounded,
                      isSecondary: true,
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).push(royalRoute(JoinRoomScreen(username: username)));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              RoyalCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(
                      context,
                    ).push(royalRoute(const HowToPlayScreen()));
                  },
                  child: const Row(
                    children: [
                      Expanded(
                        child: GameSectionTitle(
                          title: 'How To Play',
                          subtitle: 'Learn the court roles and turns',
                          icon: Icons.menu_book_rounded,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RoyalCard(
                child: const Row(
                  children: [
                    Expanded(
                      child: GameSectionTitle(
                        title: 'Settings',
                        subtitle: 'Coming soon',
                        icon: Icons.settings_rounded,
                      ),
                    ),
                    GameBadge(label: 'DEV'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingRoyalCard extends StatefulWidget {
  const _FloatingRoyalCard();

  @override
  State<_FloatingRoyalCard> createState() => _FloatingRoyalCardState();
}

class _FloatingRoyalCardState extends State<_FloatingRoyalCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (disablePolishForDebug) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (disablePolishForDebug) {
      return Container(
        width: 132,
        height: 112,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [GameColors.candle, GameColors.palaceGold],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: GameColors.palaceGold.withValues(alpha: 0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            const BoxShadow(
              color: Color(0x55351A10),
              blurRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.workspace_premium_rounded,
          size: 58,
          color: GameColors.ruby,
        ),
      );
    }

    final controller = _controller!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -6 * controller.value),
          child: Container(
            width: 132,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [GameColors.candle, GameColors.palaceGold],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: GameColors.palaceGold.withValues(alpha: 0.42),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 58,
              color: GameColors.ruby,
            ),
          ),
        );
      },
    );
  }
}
