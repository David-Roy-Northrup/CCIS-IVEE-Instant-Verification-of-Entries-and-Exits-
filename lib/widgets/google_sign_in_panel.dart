import 'package:flutter/material.dart';

class GoogleSignInPanel extends StatelessWidget {
  final bool isBusy;

  /// Display name of saved Google account (used to derive first name)
  final String? savedDisplayName;

  /// Optional: photo URL of saved Google account (for avatar beside "Continue as ...")
  final String? savedPhotoUrl;

  /// Primary action:
  /// - if saved account exists: continue with saved account (silent sign-in)
  /// - else: sign in with Google (interactive)
  final VoidCallback onPrimaryPressed;

  /// Secondary action when saved account exists: interactive Google sign-in
  final VoidCallback onGooglePressed;

  const GoogleSignInPanel({
    super.key,
    required this.isBusy,
    required this.savedDisplayName,
    this.savedPhotoUrl,
    required this.onPrimaryPressed,
    required this.onGooglePressed,
  });

  String _firstNameFromDisplay(String? displayName) {
    final s = (displayName ?? '').trim();
    if (s.isEmpty) return '';
    final parts = s.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? '' : parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = (savedDisplayName ?? '').trim().isNotEmpty;
    final firstName = _firstNameFromDisplay(savedDisplayName);
    final photo = (savedPhotoUrl ?? '').trim();

    Widget buildGoogleLogo({double size = 22}) {
      return Image.asset('assets/google_logo.png', height: size, width: size);
    }

    Widget buildFooter() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Developed by David Roy A. Northrup',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          SizedBox(height: 2),
          Text(
            '© CJC CCIS 2025',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
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
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onPrimaryPressed,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: Colors.black87,
                    ),
                    child: Row(
                      children: [
                        // LEFT ICON (avatar if saved, Google logo otherwise)
                        if (hasSaved)
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: photo.isEmpty
                                ? null
                                : NetworkImage(photo),
                            child: photo.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.black54,
                                  )
                                : null,
                          )
                        else
                          buildGoogleLogo(),
                        const SizedBox(width: 10),

                        // CENTER TEXT
                        Expanded(
                          child: Text(
                            hasSaved
                                ? (firstName.isNotEmpty
                                      ? 'Continue as $firstName'
                                      : 'Continue')
                                : 'Sign in with Google',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // RIGHT SPACER to keep center text truly centered
                        const SizedBox(width: 22),
                      ],
                    ),
                  ),
                ),

                // Secondary button (only if saved login exists)
                if (hasSaved) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isBusy ? null : onGooglePressed,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.black87,
                      ),
                      child: Row(
                        children: [
                          buildGoogleLogo(size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Use a Different Google Account',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 30), // balance left icon width
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),

                // Footer at bottom
                buildFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}
