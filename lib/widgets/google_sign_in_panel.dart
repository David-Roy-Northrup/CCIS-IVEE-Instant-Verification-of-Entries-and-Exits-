// lib/widgets/google_sign_in_panel.dart
import 'package:flutter/material.dart';

class GoogleSignInPanel extends StatelessWidget {
  final VoidCallback onSignInPressed;

  const GoogleSignInPanel({super.key, required this.onSignInPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Sign in with your CJC GSuite Account',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Image.asset('assets/google_logo.png', height: 24, width: 24),
            label: const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              side: const BorderSide(color: Colors.grey),
              backgroundColor: Colors.white,
            ),
            onPressed: onSignInPressed,
          ),
        ),
        const Spacer(),
        const Text(
          'Developed by David Roy Northrup\n© CJC - College of Computing and Information Sciences',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color.fromARGB(179, 255, 255, 255),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
