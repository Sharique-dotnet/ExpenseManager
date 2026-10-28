import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Signed-in user, or null. Firebase persists the session across restarts.
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String input) {
  if (input.trim().isEmpty) return 'Enter your email';
  if (!_emailPattern.hasMatch(input.trim())) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String input) {
  if (input.isEmpty) return 'Enter your password';
  if (input.length < 6) return 'Use at least 6 characters';
  return null;
}

String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) return 'Something went wrong. Please try again.';
  return switch (error.code) {
    'invalid-email' => 'That email address looks invalid.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email. Sign in instead.',
    'weak-password' => 'Choose a stronger password (at least 6 characters).',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' => 'No connection. Check your internet and try again.',
    'operation-not-allowed' => 'Email sign-in is not enabled for this Firebase project.',
    _ => error.message ?? 'Sign-in failed. Please try again.',
  };
}
