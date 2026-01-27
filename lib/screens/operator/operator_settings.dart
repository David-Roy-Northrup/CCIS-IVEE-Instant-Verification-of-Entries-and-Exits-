import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '/screens/auth_screen.dart';
import '/screens/loading_screen.dart';

class OperatorSettings extends StatefulWidget {
  const OperatorSettings({super.key});

  @override
  State<OperatorSettings> createState() => _OperatorSettingsState();
}

class _OperatorSettingsState extends State<OperatorSettings> {
  final User? user = FirebaseAuth.instance.currentUser;

  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchUserPermissions();
  }

  Future<Map<String, dynamic>?> _getUserDocData(User u) async {
    // Try doc keyed by UID first
    final uidDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .get();
    if (uidDoc.exists) return uidDoc.data();

    // Fallback: doc keyed by lowercase email (if your collection uses email as ID)
    final email = (u.email ?? '').toLowerCase();
    if (email.isNotEmpty) {
      final emailDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      if (emailDoc.exists) return emailDoc.data();
    }

    // Fallback: query by email field if needed
    if (email.isNotEmpty) {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
    }

    return null;
  }

  Future<void> _fetchUserPermissions() async {
    if (user == null) return;
    try {
      await _getUserDocData(user!);

      setState(() {
        _loadingRole = false;
      });
    } catch (_) {
      setState(() {
        _loadingRole = false;
      });
    }
  }

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
    const String url = "https://youtube.com";
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
          "Are you sure you want to log out? You will need to reselect your account at login.",
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
      await FirebaseAuth.instance.signOut();
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
        (route) => false,
      );
    } catch (_) {
      Navigator.pop(context); // remove loading
      await _showErrorDialog(
        context,
        "Logout Failed",
        "An error occurred while trying to log out. Please try again.",
      );
    }
  }

  // Helper to keep the same look as "User Manual" and "Log out"
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
        child: _loadingRole
            ? const Center(child: CircularProgressIndicator())
            : Column(
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

                          // Always first
                          _linkItem(
                            "User Manual",
                            () => _openUserManual(context),
                          ),
                          const SizedBox(height: 10),

                          // Always last
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
