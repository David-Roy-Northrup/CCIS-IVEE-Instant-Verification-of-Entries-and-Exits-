import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '/screens/auth_screen.dart';
import '/screens/loading_screen.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final User? user = FirebaseAuth.instance.currentUser;

  // IMPORTANT: match AuthScreen config
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _openUserManual(BuildContext context) async {
    const String url = "https://david-roy-northrup.github.io/EVII/";
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _showErrorDialog(
          context,
          "Cannot Open Link",
          "We were unable to open the User Manual. Please check your internet connection or try again later.",
        );
      }
    } catch (_) {
      await _showErrorDialog(
        context,
        "Error",
        "An unexpected error occurred while opening the User Manual.",
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Confirm Logout"),
        content: const Text(
          "Are you sure you want to log out?\n\nYou will need to reselect your account at login.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Log out"),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoadingScreen(message: "Logging out..."),
        ),
      );

      await _logout(context);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // 1) Firebase sign out
      await FirebaseAuth.instance.signOut();

      // 2) Google sign out (local) + disconnect (revokes + clears cached account)
      // disconnect can throw if not currently connected; ignore safely
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 3) Go back to AuthScreen and clear navigation stack
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    } catch (_) {
      // remove loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      await _showErrorDialog(
        context,
        "Logout Failed",
        "An error occurred while trying to log out. Please try again.",
      );
    }
  }

  Widget _linkItem(String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? "Unknown User";
    final email = user?.email ?? "No Email";
    final photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F3C),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(
                  top: 3,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? const Icon(
                              Icons.account_circle,
                              size: 50,
                              color: Colors.black,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$displayName\n$email",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 1),
                    const Text(
                      "SETTINGS",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    _linkItem("User Manual", () => _openUserManual(context)),
                    const SizedBox(height: 10),
                    _linkItem("Log out", () => _confirmLogout(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
