import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

Future<void>? _googleReady;

/// Google account picker, then Firebase sign-in with its ID token.
/// Returns false if the user closed the picker.
Future<bool> signInWithGoogle(FirebaseAuth auth) async {
  final google = GoogleSignIn.instance;
  await (_googleReady ??= google.initialize());
  try {
    final account = await google.authenticate();
    await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: account.authentication.idToken));
    return true;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return false;
    rethrow;
  }
}

/// Signs out of Firebase and Google, so the account picker shows again next time.
Future<void> signOut(FirebaseAuth auth) async {
  await auth.signOut();
  try {
    await (_googleReady ??= GoogleSignIn.instance.initialize());
    await GoogleSignIn.instance.signOut();
  } catch (_) {
    // Not signed in with Google, or Play services unavailable: nothing to clear.
  }
}

String authErrorMessage(Object error) {
  if (error is GoogleSignInException) return "Google sign-in didn't complete. Please try again.";
  if (error is! FirebaseAuthException) return 'Something went wrong. Please try again.';
  return switch (error.code) {
    'invalid-email' => 'That email address looks invalid.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email. Sign in instead.',
    'weak-password' => 'Choose a stronger password (at least 6 characters).',
    'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
    'network-request-failed' => 'No connection. Check your internet and try again.',
    'operation-not-allowed' => 'This sign-in method is not enabled for this Firebase project.',
    'account-exists-with-different-credential' => 'This email already has an account. Sign in with your password.',
    _ => error.message ?? 'Sign-in failed. Please try again.',
  };
}
