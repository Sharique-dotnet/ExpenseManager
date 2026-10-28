import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` runs against the local Emulator Suite
/// with a demo project, no Firebase account needed. 10.0.2.2 is the host machine
/// as seen from the Android emulator.
const _useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');

const _emulatorOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-expense-manager',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: _useEmulator ? _emulatorOptions : DefaultFirebaseOptions.currentPlatform);
    if (_useEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
    }
  } catch (e) {
    runApp(_SetupErrorApp('$e'));
    return;
  }
  // Failed providers show an error with a Retry button instead of retrying silently.
  runApp(ProviderScope(retry: (_, _) => null, child: const ExpenseApp()));
}

class _SetupErrorApp extends StatelessWidget {
  const _SetupErrorApp(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(24), child: Text('Firebase setup failed.\n\n$message')),
      ),
    ),
  );
}
