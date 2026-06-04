import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/game_text_field.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import '../../widgets/royal_nav.dart';
import 'auth_form_helpers.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = friendlyAuthError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null && mounted) {
        setState(() => _error = 'Google sign-in was cancelled');
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = friendlyAuthError(error);
      setState(() => _error = message);
      showErrorToast(context, message);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
                      const _AnimatedCrownMark(),
                      const SizedBox(height: 12),
                      Text(
                        "King's Guess",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter the Court of Secrets',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),
                      _GoogleButton(
                        isLoading: _isGoogleLoading,
                        onPressed: _googleSignIn,
                      ),
                      const SizedBox(height: 18),
                      const _AuthDivider(),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFAEC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE7C879),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Royal Credentials',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            GameTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.mail_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: validateEmail,
                            ),
                            const SizedBox(height: 14),
                            GameTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: validatePassword,
                              onSubmitted: (_) => _login(),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        GameErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 22),
                      RoyalButton(
                        label: 'Enter Court',
                        icon: Icons.login_rounded,
                        isLoading: _isLoading,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading || _isGoogleLoading
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).push(royalRoute(const SignupScreen()));
                              },
                        child: const Text('New to the court? Create account'),
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

class _AnimatedCrownMark extends StatefulWidget {
  const _AnimatedCrownMark();

  @override
  State<_AnimatedCrownMark> createState() => _AnimatedCrownMarkState();
}

class _AnimatedCrownMarkState extends State<_AnimatedCrownMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -4 * _controller.value),
          child: Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6A0),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5B540), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFE5B540,
                  ).withValues(alpha: 0.35 + (_controller.value * 0.25)),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 50,
              color: Color(0xFFB83A4B),
            ),
          ),
        );
      },
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.account_circle_rounded),
        label: const Text('Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4C2B20),
          backgroundColor: const Color(0xFFFFFAEC),
          side: const BorderSide(color: Color(0xFFE5B540), width: 2),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE7C879), thickness: 1.5)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('or', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        Expanded(child: Divider(color: Color(0xFFE7C879), thickness: 1.5)),
      ],
    );
  }
}
