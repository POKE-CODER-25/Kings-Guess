import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/game_toast.dart';
import '../../widgets/game_text_field.dart';
import '../../widgets/royal_background.dart';
import '../../widgets/royal_button.dart';
import '../../widgets/royal_card.dart';
import 'auth_form_helpers.dart';
import 'verification_pending_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted || credential.user == null) return;
      showSuccessToast(
        context,
        'Verification email sent',
        icon: Icons.mark_email_read_rounded,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerificationPendingScreen(user: credential.user!),
        ),
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
      if (!mounted) return;
      if (credential == null) {
        setState(() => _error = 'Google sign-in was cancelled');
        return;
      }
      Navigator.of(context).pop();
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
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 68,
                        color: Color(0xFFB83A4B),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Claim Your Crown',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create your account and join the royal table.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 22),
                      _GoogleSignupButton(
                        isLoading: _isGoogleLoading,
                        onPressed: _googleSignIn,
                      ),
                      const SizedBox(height: 18),
                      const _SignupDivider(),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE7C879),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
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
                              textInputAction: TextInputAction.next,
                              validator: validatePassword,
                            ),
                            const SizedBox(height: 14),
                            GameTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              icon: Icons.verified_user_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords must match';
                                }
                                return null;
                              },
                              onSubmitted: (_) => _signup(),
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
                        label: 'Create Account',
                        icon: Icons.person_add_alt_1_rounded,
                        isLoading: _isLoading,
                        onPressed: _signup,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading || _isGoogleLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Already have an account? Login'),
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

class _GoogleSignupButton extends StatelessWidget {
  const _GoogleSignupButton({required this.isLoading, required this.onPressed});

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

class _SignupDivider extends StatelessWidget {
  const _SignupDivider();

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
