import 'package:flutter/material.dart';

class GoogleSignInPanel extends StatelessWidget {
  final bool isBusy;
  final String? savedDisplayName;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onGooglePressed;

  const GoogleSignInPanel({
    super.key,
    required this.isBusy,
    required this.savedDisplayName,
    required this.onPrimaryPressed,
    required this.onGooglePressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasSaved = (savedDisplayName ?? '').trim().isNotEmpty;

    return Column(
      children: [
        const Text(
          'Sign in with your CJC GSuite Account',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 16),

        // Primary button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: hasSaved
                ? const Icon(Icons.account_circle, color: Colors.black87)
                : Image.asset('assets/google_logo.png', height: 24, width: 24),
            label: Text(
              hasSaved
                  ? 'Sign in as ${savedDisplayName!.trim()}'
                  : 'Sign in with Google',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
            ),
            onPressed: isBusy ? null : onPrimaryPressed,
          ),
        ),

        if (hasSaved) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: Image.asset(
                'assets/google_logo.png',
                height: 20,
                width: 20,
              ),
              label: const Text(
                'Sign in with Google',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              onPressed: isBusy ? null : onGooglePressed,
            ),
          ),
        ],

        const SizedBox(height: 10),
        if (isBusy)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Signing in…',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
