import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/royal_nav.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/game_badge.dart';
import 'lobby_screen.dart';
import 'room_service.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key, required this.username});

  final String username;

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _roomService = RoomService();

  int _selectedRounds = 6;
  bool _isLoading = false;
  String? _error;

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final room = await _roomService.createRoom(
        username: widget.username,
        selectedRounds: _selectedRounds,
      );

      if (!mounted) return;
      showSuccessToast(
        context,
        'Room created',
        icon: Icons.add_home_work_rounded,
      );
      Navigator.of(context).pushReplacement(
        royalRoute(LobbyScreen(roomId: room.roomId, username: widget.username)),
      );
    } on RoomException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      showErrorToast(context, error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = _friendlyFirestoreError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Could not create room. Try again';
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  44,
            ),
            child: Center(
              child: RoyalCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.castle_rounded,
                      size: 62,
                      color: Color(0xFFB83A4B),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open a Private Court',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Host chooses how many rounds the royal court will play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var rounds = 6; rounds <= 10; rounds++)
                          _RoundToken(
                            rounds: rounds,
                            selected: _selectedRounds == rounds,
                            onTap: _isLoading
                                ? null
                                : () =>
                                      setState(() => _selectedRounds = rounds),
                          ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    RoyalButton(
                      label: 'Create Court',
                      icon: Icons.castle_rounded,
                      isLoading: _isLoading,
                      onPressed: _createRoom,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundToken extends StatelessWidget {
  const _RoundToken({
    required this.rounds,
    required this.selected,
    required this.onTap,
  });

  final int rounds;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFE6A0) : const Color(0xFFFFFAEC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE5B540)
                  : const Color(0xFFE7C879),
              width: selected ? 3 : 2,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x55E5B540),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                '$rounds',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFB83A4B),
                ),
              ),
              const GameBadge(label: 'Rounds'),
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyFirestoreError(FirebaseException error) {
  return switch (error.code) {
    'permission-denied' => 'Room access denied. Check Firestore rules',
    'unavailable' => 'Network error. Check your connection',
    _ => error.message ?? 'Firestore error. Try again',
  };
}
