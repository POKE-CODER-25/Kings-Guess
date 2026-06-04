import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// TODO: set this to false before production.
const bool allowUnverifiedDebugLogin = true;

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  bool _googleSignInInitialized = false;

  Stream<User?> authStateChanges() => _firebaseAuth.userChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.reload();
    return credential;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.sendEmailVerification();
    return credential;
  }

  Future<UserCredential?> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..addScope('email');

    if (kIsWeb) {
      return _firebaseAuth.signInWithPopup(provider);
    }

    await _initializeGoogleSignIn();
    try {
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email'],
      );
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-missing-token',
          message: 'Google sign-in did not return an identity token.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: error.description ?? 'Google sign-in failed.',
      );
    }
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  Future<void> sendEmailVerification() async {
    await _firebaseAuth.currentUser?.sendEmailVerification();
  }

  bool isPasswordUser(User user) {
    return user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  bool canEnterApp(User user) {
    if (!isPasswordUser(user)) return true;
    if (user.emailVerified) return true;
    return kDebugMode && allowUnverifiedDebugLogin;
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase sign out below is the source of truth for app routing.
      }
    }
    await _firebaseAuth.signOut();
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleSignInInitialized = true;
  }
}
