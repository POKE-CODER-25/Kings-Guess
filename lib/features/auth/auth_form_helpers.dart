import 'package:firebase_auth/firebase_auth.dart';

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Enter your password';
  if (password.length < 6) return 'Password must be at least 6 characters';
  return null;
}

String friendlyAuthError(FirebaseAuthException error) {
  return switch (error.code) {
    'wrong-password' => 'Wrong password',
    'user-not-found' => 'No account found for that email',
    'invalid-credential' => 'Email or password is incorrect',
    'email-already-in-use' => 'Email already in use',
    'weak-password' => 'Password is too weak',
    'invalid-email' => 'Enter a valid email address',
    'network-request-failed' => 'Check your connection and try again',
    'account-exists-with-different-credential' =>
      'This email uses another sign-in method',
    'popup-closed-by-user' => 'Google sign-in was cancelled',
    'operation-not-allowed' => 'Google sign-in is not enabled in Firebase.',
    'google-sign-in-failed' => error.message ?? 'Google sign-in failed',
    'google-sign-in-missing-token' => 'Google sign-in could not verify you',
    _ => error.message ?? 'Authentication failed. Try again',
  };
}
