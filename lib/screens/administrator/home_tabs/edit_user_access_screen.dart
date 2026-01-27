import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditUserAccessScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditUserAccessScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditUserAccessScreen> createState() => _EditUserAccessScreenState();
}

class _EditUserAccessScreenState extends State<EditUserAccessScreen> {
  late bool _isAdmin;
  late bool _isOperator;
  bool _saving = false;

  String get _email => (widget.data['email'] ?? widget.docId).toString();
  String get _name => (widget.data['name'] ?? '').toString();
  String get _photoUrl => (widget.data['photoUrl'] ?? '').toString();

  String _deriveNameFromEmail(String email) {
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) return 'Unknown';
    final local = e.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[\._\-]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Unknown';
    return cleaned
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  String get _displayName =>
      _name.isNotEmpty ? _name : _deriveNameFromEmail(_email);

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.black87),
    );
  }

  @override
  void initState() {
    super.initState();
    _isAdmin = (widget.data['administrator'] ?? false) == true;
    _isOperator = (widget.data['operator'] ?? false) == true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.docId)
          .update({'administrator': _isAdmin, 'operator': _isOperator});

      if (mounted) Navigator.pop(context);
      _snack('Saved.', color: Colors.green);
    } catch (e) {
      _snack('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        title: const Text(
          'Edit User Access',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _photoUrl.isNotEmpty
                        ? NetworkImage(_photoUrl)
                        : null,
                    child: _photoUrl.isEmpty
                        ? Text(
                            _displayName.isNotEmpty
                                ? _displayName[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black54,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
