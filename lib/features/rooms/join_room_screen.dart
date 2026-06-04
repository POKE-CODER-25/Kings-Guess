import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/royal_nav.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/game_text_field.dart';
import 'lobby_screen.dart';
import 'room_service.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, required this.username});

  final String username;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _roomService = RoomService();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _roomIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;

    final roomId = _roomIdController.text.trim().toUpperCase();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _roomService.joinRoom(
        roomId: roomId,
        password: _passwordController.text,
        username: widget.username,
      );

      if (!mounted) return;
      showSuccessToast(context, 'Room joined', icon: Icons.group_add_rounded);
      Navigator.of(context).pushReplacement(
        royalRoute(LobbyScreen(roomId: roomId, username: widget.username)),
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
      const message = 'Could not join room. Try again';
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_add_rounded,
                        size: 58,
                        color: Color(0xFFB83A4B),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter a Secret Court',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use the court code and royal key from your host.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 22),
                      GameTextField(
                        controller: _roomIdController,
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        label: 'Court ID',
                        icon: Icons.meeting_room_rounded,
                        validator: _validateRoomId,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: 14),
                      GameTextField(
                        controller: _passwordController,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        label: '4-digit key',
                        icon: Icons.lock_rounded,
                        validator: _validatePassword,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _joinRoom(),
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
                        label: 'Join Court',
                        icon: Icons.login_rounded,
                        isLoading: _isLoading,
                        onPressed: _joinRoom,
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
      ),
    );
  }
}

String? _validateRoomId(String? value) {
  final roomId = value?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(roomId)) {
    return 'Enter the 6-character room ID';
  }
  return null;
}

String? _validatePassword(String? value) {
  final password = value?.trim() ?? '';
  if (!RegExp(r'^\d{4}$').hasMatch(password)) {
    return 'Enter the 4-digit password';
  }
  return null;
}

String _friendlyFirestoreError(FirebaseException error) {
  return switch (error.code) {
    'permission-denied' => 'Room access denied. Check Firestore rules',
    'unavailable' => 'Network error. Check your connection',
    _ => error.message ?? 'Firestore error. Try again',
  };
}
