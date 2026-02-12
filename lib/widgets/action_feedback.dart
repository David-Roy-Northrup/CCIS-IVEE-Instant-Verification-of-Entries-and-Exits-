import 'dart:async';

import 'package:flutter/material.dart';

/// Lightweight, non-intrusive feedback UI (replaces SnackBars).
/// Shows a small card near the top of the screen and auto-dismisses.
class ActionFeedbackOverlay {
  static Future<void> show(
    BuildContext context, {
    required bool success,
    required String title,
    required String message,
    List<String> affected = const [],
    Duration duration = const Duration(seconds: 4),
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ActionFeedbackCard(
        success: success,
        title: title,
        message: message,
        affected: affected,
        onClose: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
    await Future<void>.delayed(duration);
    if (entry.mounted) entry.remove();
  }
}

class _ActionFeedbackCard extends StatelessWidget {
  final bool success;
  final String title;
  final String message;
  final List<String> affected;
  final VoidCallback onClose;

  const _ActionFeedbackCard({
    required this.success,
    required this.title,
    required this.message,
    required this.affected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: topInset + 8, left: 12, right: 12),
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(
                      width: 6,
                      color: success ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    if (affected.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: affected.map((t) => _Chip(text: t)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
