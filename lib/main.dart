// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'widgets/inactivity_guard.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _handleInactivityTimeout() async {
    // DO NOT sign out. Just redirect to login screen.
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
      builder: (context, child) {
        return InactivityGuard(
          timeout: const Duration(minutes: 1),
          onTimeout: _handleInactivityTimeout,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
