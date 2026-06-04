import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../home/home_screen.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/game_text_field.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key, required this.user});

  final User user;

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  static final _usernameRegex = RegExp(r'^[a-z_]{1,15}$');

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _profileService = UserProfileService();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _error;
  String _liveUsername = '';

  @override
  void initState() {
    super.initState();
    _openHomeIfUsernameExists();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _openHomeIfUsernameExists() async {
    try {
      final username = await _profileService.usernameFor(widget.user.uid);
      if (!mounted || username == null || username.isEmpty) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Username lookup FirebaseException: ${error.code} - ${error.message}',
      );
    } catch (error) {
      debugPrint('Username lookup error: $error');
    }
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final savedUsername = await _profileService.createProfileWithUsername(
        user: widget.user,
        username: _usernameController.text.trim(),
      );

      var username = savedUsername;
      try {
        final profile = await _profileService.reloadProfileFor(widget.user.uid);
        username = profile.data()?['username'] as String? ?? savedUsername;
      } on FirebaseException catch (error) {
        debugPrint(
          'Username reload FirebaseException: ${error.code} - ${error.message}',
        );
      } catch (error) {
        debugPrint('Username reload error: $error');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(username: username)),
      );
    } on UsernameTakenException {
      setState(() => _error = 'username already taken');
    } on InvalidUsernameException {
      setState(() => _error = 'Use a-z and underscores only');
    } on FirebaseException catch (error) {
      debugPrint(
        'Username save FirebaseException: ${error.code} - ${error.message}',
      );
      setState(() => _error = _friendlyFirestoreError(error));
    } catch (error) {
      debugPrint('Username save error: $error');
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                      const _IdentityMark(),
                      const SizedBox(height: 12),
                      Text(
                        'Choose your Court Name',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE6A0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5B540),
                            width: 2,
                          ),
                        ),
                        child: const Text(
                          'Use lowercase letters and underscores. Max 15 characters. Availability is checked when you save.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GameTextField(
                        controller: _usernameController,
                        maxLength: 15,
                        textInputAction: TextInputAction.done,
                        label: 'Court name',
                        icon: Icons.badge_rounded,
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          if (!_usernameRegex.hasMatch(username)) {
                            return 'Use a-z and underscores only';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          setState(() {
                            _liveUsername = _usernameController.text.trim();
                          });
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _saveUsername(),
                      ),
                      const SizedBox(height: 10),
                      _LiveUsernameState(
                        username: _liveUsername,
                        isValid: _usernameRegex.hasMatch(_liveUsername),
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
                        label: 'Save Username',
                        icon: Icons.check_circle_rounded,
                        isLoading: _isLoading,
                        onPressed: _saveUsername,
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _isLoading ? null : _authService.signOut,
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
      ),
    );
  }
}

class _IdentityMark extends StatefulWidget {
  const _IdentityMark();

  @override
  State<_IdentityMark> createState() => _IdentityMarkState();
}

class _IdentityMarkState extends State<_IdentityMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      child: Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE6A0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5B540), width: 3),
        ),
        child: const Icon(
          Icons.workspace_premium_rounded,
          color: Color(0xFFB83A4B),
          size: 42,
        ),
      ),
    );
  }
}

class _LiveUsernameState extends StatelessWidget {
  const _LiveUsernameState({required this.username, required this.isValid});

  final String username;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    if (username.isEmpty) {
      return const Text('Your name will appear as @court_name');
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isValid ? Icons.check_circle_rounded : Icons.error_rounded,
          color: isValid ? const Color(0xFF2F8F57) : const Color(0xFFB83A4B),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            isValid ? '@$username looks ready' : 'Use a-z and underscores only',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

String _friendlyFirestoreError(FirebaseException error) {
  return switch (error.code) {
    'already-exists' => 'username already taken',
    'permission-denied' => 'Firestore permission denied. Check rules.',
    'unavailable' || 'network-request-failed' => 'Network error. Try again.',
    _ => error.message ?? error.toString(),
  };
}
