import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../widgets/action_feedback.dart';

class AddUserAccessScreen extends StatefulWidget {
  const AddUserAccessScreen({super.key});

  @override
  State<AddUserAccessScreen> createState() => _AddUserAccessScreenState();
}

class _AddUserAccessScreenState extends State<AddUserAccessScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _administrator = false;
  bool _operator = false;

  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  bool _isValidEmail(String email) {
    final e = _normalizeEmail(email);
    // Basic check; keep simple and strict.
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  }

  Future<void> _feedback(
    bool ok,
    String title,
    String msg, {
    List<String> affected = const [],
  }) async {
    if (!mounted) return;
    await ActionFeedbackOverlay.show(
      context,
      success: ok,
      title: title,
      message: msg,
      affected: affected,
    );
  }

  Future<void> _save() async {
    final email = _normalizeEmail(_emailController.text);
    final name = _nameController.text.trim();

    if (email.isEmpty) {
      await _feedback(
        false,
        'Missing email',
        'Email is required.',
        affected: const ['Field: Email'],
      );
      return;
    }
    if (!_isValidEmail(email)) {
      await _feedback(
        false,
        'Invalid email',
        'Please enter a valid email address.',
        affected: ['Email: $email'],
      );
      return;
    }

    // If you want to enforce only @g.cjc.edu.ph accounts:
    if (!email.endsWith('@g.cjc.edu.ph')) {
      await _feedback(
        false,
        'Invalid domain',
        'Only CJC GSuite accounts are allowed.',
        affected: ['Email must end with @g.cjc.edu.ph', 'Email: $email'],
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(email);
      final existing = await ref.get();
      if (existing.exists) {
        await _feedback(
          false,
          'User already exists',
          'This email already has an access record.',
          affected: ['User: $email', 'users/$email already exists'],
        );
        return;
      }

      await ref.set({
        'email': email,
        'name': name,
        'administrator': _administrator,
        'operator': _operator,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context, {
        'added': true,
        'email': email,
        'name': name,
        'administrator': _administrator,
        'operator': _operator,
      });
    } catch (e) {
      await _feedback(
        false,
        'Add failed',
        'Unable to create user access record.',
        affected: ['User: $email', 'Error: $e'],
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Add User Access',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'user@g.cjc.edu.ph',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Name (optional)',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                enabled: !_saving,
                decoration: InputDecoration(
                  hintText: 'Full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Roles',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Administrator'),
                subtitle: const Text('Access to admin dashboard features'),
                value: _administrator,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _administrator = v),
              ),
              SwitchListTile(
                title: const Text('Operator'),
                subtitle: const Text('Access to scanning/operator features'),
                value: _operator,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _operator = v),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8CC63F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'SAVE',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
