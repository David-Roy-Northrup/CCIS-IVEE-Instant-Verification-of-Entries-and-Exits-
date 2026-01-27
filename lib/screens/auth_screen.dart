// lib/screens/auth_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'administrator/administrator.dart';
import 'loading_screen.dart';
import 'operator/operator.dart';
import '../widgets/google_sign_in_panel.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _showSignIn = false;

  static const String _logoGifAsset = 'assets/logo.gif';
  static const String _logoFallbackPng = 'assets/logo.png';

  Future<void> _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRoleSelectionDialog(
    BuildContext context, {
    required bool isAdmin,
    required bool isOperator,
  }) async {
    const navy = Color(0xFF0A0F3C);

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/ccis_logo.png',
              height: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            const Text(
              "Select Role",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop("admin"),
                  label: const Text(
                    "Administrator",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (isOperator) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop("operator"),
                  label: const Text(
                    "Operator",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateWithRole(BuildContext context, String role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoadingScreen(message: "Signing in..."),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      Widget screen;
      switch (role) {
        case "admin":
          screen = const AdministratorMain();
          break;
        case "operator":
          screen = const OperatorMain();
          break;
        default:
          return;
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => screen));
    });
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException("No internet connection");
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final email = googleUser.email.toLowerCase().trim();

      if (!email.endsWith('@g.cjc.edu.ph')) {
        await _googleSignIn.signOut();
        await _showErrorDialog(
          context,
          "Invalid Account",
          "Only CJC GSuite accounts are allowed.\n\nPlease sign in using your @g.cjc.edu.ph email.",
        );
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      final userDocRef = _firestore.collection('users').doc(email);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        await _showErrorDialog(
          context,
          "Access Denied",
          "You do not have access to IVEE. Please contact an admin.",
        );
        return;
      }

      final data = userDoc.data() ?? {};
      final bool isAdmin = (data['administrator'] ?? false) == true;
      final bool isOperator = (data['operator'] ?? false) == true;

      final enabledRoles = <String>[
        if (isAdmin) "admin",
        if (isOperator) "operator",
      ];

      if (enabledRoles.isEmpty) {
        await _showErrorDialog(
          context,
          "Access Denied",
          "You do not have access to IVEE. Please contact an admin.",
        );
        return;
      }

      final u = _auth.currentUser;
      if (u != null) {
        await userDocRef.set({
          'email': email,
          'name': u.displayName ?? '',
          'photoUrl': u.photoURL ?? '',
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (enabledRoles.length == 1) {
        _navigateWithRole(context, enabledRoles.first);
      } else {
        final selectedRole = await _showRoleSelectionDialog(
          context,
          isAdmin: isAdmin,
          isOperator: isOperator,
        );
        if (selectedRole != null) {
          _navigateWithRole(context, selectedRole);
        }
      }
    } on SocketException {
      await _showErrorDialog(
        context,
        "No Internet Connection",
        "Please check your internet connection and try again.",
      );
    } catch (e) {
      await _showErrorDialog(
        context,
        "Sign-In Error",
        "An unexpected error occurred while signing in.\n\nDetails: ${e.toString()}",
      );
    }
  }

  void _showSignInAfterDelay() {
    if (!mounted) return;
    if (_showSignIn) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showSignIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);
    const bg = Color(0xFFFCFCFC);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSignInAfterDelay();
    });

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final double bottomHeightCollapsed = h * 0.16;
            final double bottomHeightExpanded = h * 0.28;
            final double bottomHeight = _showSignIn
                ? bottomHeightExpanded
                : bottomHeightCollapsed;

            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: LoopingGifWithFallback(
                            gifAsset: _logoGifAsset,
                            fallbackPngAsset: _logoFallbackPng,
                            width: 260,
                            height: 260,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/cjc_logo.png', height: 40),
                                const SizedBox(width: 16),
                                Image.asset('assets/ccis_logo.png', height: 40),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                'Official Student Attendance System of the College of Computing and Information Sciences of Cor Jesu College, Inc.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOut,
                  height: bottomHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.elliptical(w * 0.1, bottomHeight * 0.1),
                      topRight: Radius.elliptical(w * 0.1, bottomHeight * 0.1),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(anim);

                        return SlideTransition(
                          position: slide,
                          child: FadeTransition(opacity: anim, child: child),
                        );
                      },
                      child: _showSignIn
                          ? GoogleSignInPanel(
                              key: const ValueKey('signInPanel'),
                              onSignInPressed: () => _signInWithGoogle(context),
                            )
                          : const PreparingSignIn(key: ValueKey('preparing')),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PreparingSignIn extends StatelessWidget {
  const PreparingSignIn({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 6),
        Text(
          'Preparing sign-in...',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

/// Plays an asset GIF in a loop (decodes frames manually),
/// falls back to a PNG if the GIF asset is missing/unreadable.
class LoopingGifWithFallback extends StatefulWidget {
  final String gifAsset;
  final String fallbackPngAsset;
  final double width;
  final double height;

  const LoopingGifWithFallback({
    super.key,
    required this.gifAsset,
    required this.fallbackPngAsset,
    required this.width,
    required this.height,
  });

  @override
  State<LoopingGifWithFallback> createState() => _LoopingGifWithFallbackState();
}

class _LoopingGifWithFallbackState extends State<LoopingGifWithFallback> {
  bool _gifFailed = false;

  @override
  Widget build(BuildContext context) {
    if (_gifFailed) {
      return Image.asset(
        widget.fallbackPngAsset,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
      );
    }

    return LoopingGif(
      assetPath: widget.gifAsset,
      width: widget.width,
      height: widget.height,
      onError: () {
        if (mounted) setState(() => _gifFailed = true);
      },
    );
  }
}

class LoopingGif extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;
  final VoidCallback onError;

  const LoopingGif({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.onError,
  });

  @override
  State<LoopingGif> createState() => _LoopingGifState();
}

class _LoopingGifState extends State<LoopingGif> {
  final List<ui.Image> _frames = <ui.Image>[];
  final List<Duration> _durations = <Duration>[];

  int _frameIndex = 0;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAndLoop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final img in _frames) {
      try {
        img.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadAndLoop() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final bytes = data.buffer.asUint8List();

      final codec = await ui.instantiateImageCodec(bytes);

      for (int i = 0; i < codec.frameCount; i++) {
        final frameInfo = await codec.getNextFrame();
        _frames.add(frameInfo.image);

        final d = frameInfo.duration;
        _durations.add(
          (d == Duration.zero) ? const Duration(milliseconds: 60) : d,
        );
      }

      if (!mounted || _frames.isEmpty) return;

      setState(() {
        _loading = false;
        _frameIndex = 0;
      });

      _scheduleNextFrame();
    } catch (_) {
      widget.onError();
    }
  }

  void _scheduleNextFrame() {
    if (!mounted || _frames.isEmpty) return;

    final delay = _durations[_frameIndex];
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!mounted) return;

      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length; // LOOP
      });

      _scheduleNextFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: RawImage(image: _frames[_frameIndex], fit: BoxFit.contain),
        ),
      ),
    );
  }
}
