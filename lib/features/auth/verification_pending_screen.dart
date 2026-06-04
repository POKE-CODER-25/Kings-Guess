import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../home/home_screen.dart';
import '../username/username_setup_screen.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/game_text_field.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key, required this.user});

  final User user;

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  final _authService = AuthService();
  final _profileService = UserProfileService();

  bool _isChecking = false;
  bool _isResending = false;
  String? _error;

  Future<void> _continueIfVerified() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      await _authService.reloadCurrentUser();
      final user = _authService.currentUser;
      if (user == null || !user.emailVerified) {
        if (!mounted) return;
        const message = 'Email not verified yet';
        setState(() => _error = message);
        showErrorToast(context, message);
        return;
      }
      final username = await _profileService.usernameFor(user.uid);
      if (!mounted) return;
      showSuccessToast(context, 'Email verified', icon: Icons.verified_rounded);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => username == null || username.isEmpty
              ? UsernameSetupScreen(user: user)
              : HomeScreen(username: username),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = _friendlyVerificationError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _error = null;
    });

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      showSuccessToast(
        context,
        'Verification email sent',
        icon: Icons.mark_email_read_rounded,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = _friendlyVerificationError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email ?? 'your email';

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
                    Container(
                      width: 82,
                      height: 82,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6A0),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFFE5B540),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        size: 44,
                        color: Color(0xFFB83A4B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to $email.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open the link, then return here to continue.',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      GameErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 22),
                    RoyalButton(
                      label: 'I verified, continue',
                      icon: Icons.verified_rounded,
                      isLoading: _isChecking,
                      onPressed: _continueIfVerified,
                    ),
                    const SizedBox(height: 10),
                    RoyalButton(
                      label: 'Resend email',
                      icon: Icons.refresh_rounded,
                      isSecondary: true,
                      isLoading: _isResending,
                      onPressed: _resendEmail,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _authService.signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
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

String _friendlyVerificationError(FirebaseAuthException error) {
  return switch (error.code) {
    'too-many-requests' => 'Try again later before resending',
    'network-request-failed' => 'Check your connection and try again',
    _ => error.message ?? 'Verification failed. Try again',
  };
}
