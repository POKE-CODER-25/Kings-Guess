import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/room_consistency_service.dart';
import '../../services/user_profile_service.dart';
import '../game/game_screen.dart';
import '../home/home_screen.dart';
import '../reconnect/reconnect_screen.dart';
import '../rooms/lobby_screen.dart';
import '../username/username_setup_screen.dart';
import 'login_screen.dart';
import 'verification_pending_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final profileService = UserProfileService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCastle();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        if (!authService.canEnterApp(user)) {
          return VerificationPendingScreen(user: user);
        }

        return FutureBuilder(
          future: profileService.profileFor(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCastle();
            }

            final profile = profileSnapshot.data;
            final username = profile?.data()?['username'] as String?;

            if (profile == null || !profile.exists || username == null) {
              return UsernameSetupScreen(user: user);
            }

            return _AuthenticatedEntry(username: username);
          },
        );
      },
    );
  }
}

class _AuthenticatedEntry extends StatefulWidget {
  const _AuthenticatedEntry({required this.username});

  final String username;

  @override
  State<_AuthenticatedEntry> createState() => _AuthenticatedEntryState();
}

class _AuthenticatedEntryState extends State<_AuthenticatedEntry> {
  late final Future<ActiveRoomResolution> _reconnectFuture =
      RoomConsistencyService().reconnectToActiveRoomIfAny();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ActiveRoomResolution>(
      future: _reconnectFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ReconnectScreen();
        }

        final resolution = snapshot.data;
        if (resolution?.target == ActiveRoomTarget.lobby) {
          debugPrint('NAVIGATE: reconnect -> lobby');
          return LobbyScreen(
            roomId: resolution!.roomId!,
            username: widget.username,
          );
        }

        if (resolution?.target == ActiveRoomTarget.game) {
          debugPrint('NAVIGATE: reconnect -> game');
          return GameScreen(roomId: resolution!.roomId!);
        }

        debugPrint('NAVIGATE: auth -> home');
        return HomeScreen(
          username: widget.username,
          initialMessage: resolution?.message,
        );
      },
    );
  }
}

class _LoadingCastle extends StatelessWidget {
  const _LoadingCastle();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
