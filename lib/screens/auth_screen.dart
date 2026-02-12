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
  bool _isSigningIn = false;

  GoogleSignInAccount? _savedGoogleAccount;

  static const String _logoGifAsset = 'assets/logo.gif';
  static const String _logoFallbackPng = 'assets/logo.png';

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
  }

  Future<void> _loadSavedAccount() async {
    try {
      final acc = await _googleSignIn.signInSilently();
      if (!mounted) return;
      setState(() => _savedGoogleAccount = acc);
    } catch (_) {}
  }

  String _deriveNameFromEmail(String email) {
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) return email;
    final local = e.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[\._\-]+'), ' ').trim();
    if (cleaned.isEmpty) return email;
    return cleaned
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  String? get _savedDisplayName {
    final acc = _savedGoogleAccount;
    if (acc == null) return null;
    final dn = (acc.displayName ?? '').trim();
    if (dn.isNotEmpty) return dn;
    return _deriveNameFromEmail(acc.email);
  }

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

  void _navigateWithRole(String role) {
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
  }

  Future<void> _fullSignOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<void> _signInFlow({required bool interactive}) async {
    if (_isSigningIn) return;

    setState(() => _isSigningIn = true);

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException("No internet connection");
      }

      GoogleSignInAccount? googleUser;
      if (interactive) {
        googleUser = await _googleSignIn.signIn();
      } else {
        googleUser =
            _savedGoogleAccount ?? await _googleSignIn.signInSilently();
      }

      if (googleUser == null) {
        return;
      }

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
        await _fullSignOut();
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
        await _fullSignOut();
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

      if (mounted) {
        setState(() => _savedGoogleAccount = googleUser);
      }

      if (enabledRoles.length == 1) {
        _navigateWithRole(enabledRoles.first);
      } else {
        if (mounted) setState(() => _isSigningIn = false);
        final selectedRole = await _showRoleSelectionDialog(
          context,
          isAdmin: isAdmin,
          isOperator: isOperator,
        );
        if (selectedRole != null) {
          _navigateWithRole(selectedRole);
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
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
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

            return Stack(
              children: [
                Column(
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
                                    Image.asset(
                                      'assets/cjc_logo.png',
                                      height: 40,
                                    ),
                                    const SizedBox(width: 16),
                                    Image.asset(
                                      'assets/ccis_logo.png',
                                      height: 40,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.0,
                                  ),
                                  child: Text(
                                    'Official Student Attendance System of the College of Computing and Information Sciences of Cor Jesu College, Inc. and its affiliated Academic Organizations.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),

                                // ✅ Added small footer text
                                const SizedBox(height: 10),
                                const Text(
                                  'Developed by David Roy A. Northrup',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '© CJC CCIS 2025',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
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
                          topLeft: Radius.elliptical(
                            w * 0.1,
                            bottomHeight * 0.1,
                          ),
                          topRight: Radius.elliptical(
                            w * 0.1,
                            bottomHeight * 0.1,
                          ),
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
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            );
                          },
                          child: _showSignIn
                              ? GoogleSignInPanel(
                                  key: const ValueKey('signInPanel'),
                                  isBusy: _isSigningIn,
                                  savedDisplayName: _savedDisplayName,
                                  onPrimaryPressed: () => _signInFlow(
                                    interactive: _savedGoogleAccount == null,
                                  ),
                                  onGooglePressed: () =>
                                      _signInFlow(interactive: true),
                                )
                              : const PreparingSignIn(
                                  key: ValueKey('preparing'),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isSigningIn)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: false,
                      child: Container(
                        color: Colors.black45,
                        child: const Center(child: _SigningInOverlay()),
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

class _SigningInOverlay extends StatelessWidget {
  const _SigningInOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F3C),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 14),
            Text(
              'Signing in…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------- original GIF widgets below -----------------------
class PreparingSignIn extends StatelessWidget {
  const PreparingSignIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 16),
        Text(
          'Preparing Sign-In…',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Plays an asset GIF in a loop using frame decode.
/// Falls back to PNG if GIF fails.
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
  ui.Codec? _codec;
  List<ui.FrameInfo> _frames = [];
  int _frameIndex = 0;
  Timer? _timer;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadGif();
  }

  Future<void> _loadGif() async {
    try {
      final data = await rootBundle.load(widget.gifAsset);
      _codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _frames = [];
      for (int i = 0; i < _codec!.frameCount; i++) {
        final fi = await _codec!.getNextFrame();
        _frames.add(fi);
      }
      _startLoop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _startLoop() {
    if (_frames.isEmpty) return;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _frames[_frameIndex].duration.inMilliseconds),
      (_) {
        if (!mounted) return;
        setState(() {
          _frameIndex = (_frameIndex + 1) % _frames.length;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Image.asset(
        widget.fallbackPngAsset,
        width: widget.width,
        height: widget.height,
      );
    }
    if (_frames.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return RawImage(
      image: _frames[_frameIndex].image,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
    );
  }
}
