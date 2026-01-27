// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'screens/auth_screen.dart';
import 'widgets/inactivity_guard.dart';

// If you already have firebase_options.dart, keep using it.
// import 'firebase_options.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    // If you use generated options:
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _handleInactivityTimeout() async {
    // Recommended: sign out so the session is truly locked.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    // Also clear Google session if possible (safe to ignore failures).
    try {
      await GoogleSignIn(scopes: const ['email']).signOut();
    } catch (_) {}

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      home: const AuthScreen(),

      // Wrap the whole app in the inactivity guard:
      builder: (context, child) {
        return InactivityGuard(
          timeout: const Duration(minutes: 5),
          onTimeout: _handleInactivityTimeout,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
