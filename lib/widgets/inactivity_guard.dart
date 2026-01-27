// lib/widgets/inactivity_guard.dart
//
// App-wide inactivity timeout guard.
// - Resets timer on any pointer interaction (tap/scroll/drag).
// - If idle for [timeout], runs [onTimeout].
// - Also handles app background/resume: if user was away longer than timeout,
//   it triggers timeout immediately on resume.

import 'dart:async';
import 'package:flutter/material.dart';

class InactivityGuard extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final FutureOr<void> Function() onTimeout;

  const InactivityGuard({
    super.key,
    required this.child,
    required this.timeout,
    required this.onTimeout,
  });

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _handleTimeoutIfStillIdle);
  }

  void _registerActivity() {
    _lastActivity = DateTime.now();
    _timedOut = false;
    _startTimer();
  }

  Future<void> _handleTimeoutIfStillIdle() async {
    if (!mounted) return;

    final idle = DateTime.now().difference(_lastActivity);
    if (idle < widget.timeout) {
      // Something updated lastActivity but timer fired late; reschedule.
      _startTimer();
      return;
    }

    if (_timedOut) return;
    _timedOut = true;

    await widget.onTimeout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If app goes background, we don't really want to keep timers running.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // If user was away longer than timeout, trigger immediately.
      final idle = DateTime.now().difference(_lastActivity);
      if (idle >= widget.timeout) {
        _handleTimeoutIfStillIdle();
      } else {
        _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener catches taps/scroll/drag anywhere in the app.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registerActivity(),
      onPointerMove: (_) => _registerActivity(),
      onPointerSignal: (_) => _registerActivity(),
      child: widget.child,
    );
  }
}
