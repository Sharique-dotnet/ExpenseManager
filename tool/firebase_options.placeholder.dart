// Placeholder for lib/firebase_options.dart. `flutterfire configure` generates the real file from your Firebase
// project (see README). Copy this to lib/firebase_options.dart to build for the emulators only.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured. Run `flutterfire configure` (see README), '
    'or run against the local emulators with --dart-define=USE_FIREBASE_EMULATOR=true.',
  );
}
