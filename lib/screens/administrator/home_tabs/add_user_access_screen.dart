import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddUserAccessScreen extends StatefulWidget {
  const AddUserAccessScreen({super.key});

  @override
  State<AddUserAccessScreen> createState() => _AddUserAccessScreenState();
}

class _AddUserAccessScreenState extends State<AddUserAccessScreen> {
  final TextEditingController _emailController = TextEditingController();

  bool _isAdmin = false;
  bool _isOperator = false;
  bool _saving = false;

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.black87),
    );
  }

  bool _emailOk(String email) {
    final e = email.trim().toLowerCase();
    return e.endsWith('@g.cjc.edu.ph') && e.length > '@g.cjc.edu.ph'.length;
  }

  Future<void> _save() async {
    final email = _emailController.text.trim().toLowerCase();

    if (!_emailOk(email)) {
      _snack('Email must end with @g.cjc.edu.ph', color: Colors.red);
      return;
    }

    setState(() => _saving = true);

    try {
      // Only store email + access.
      // Name/photoUrl should be written by that user when they SIGN IN (AuthScreen merge update).
      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'email': email,
        'administrator': _isAdmin,
        'operator': _isOperator,
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context);
      _snack('User added.', color: Colors.green);
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Widget _whiteCard({required Widget child}) {
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
        title: const Text('Add User', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'User Email',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'example@g.cjc.edu.ph',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: Icon(
                    _emailOk(_emailController.text)
                        ? Icons.check_circle
                        : Icons.info,
                    color: _emailOk(_emailController.text)
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Access',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Administrator'),
                value: _isAdmin,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _isAdmin = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Operator'),
                value: _isOperator,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _isOperator = v ?? false),
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
