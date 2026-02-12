import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          "Return to the login screen?\n\nYou may not need to reselect your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoadingScreen(message: "Returning..."),
        ),
      );

      await _logout(context);
    }
  }

  /// IMPORTANT: This does NOT sign out Firebase or Google.
  /// It only redirects to the login screen and clears navigation history.
  Future<void> _logout(BuildContext context) async {
    try {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (_) {
      // remove loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      await _showErrorDialog(
        context,
        "Redirect Failed",
        "An error occurred while returning to login. Please try again.",
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
