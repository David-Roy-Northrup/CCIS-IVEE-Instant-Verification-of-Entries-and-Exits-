import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../widgets/action_feedback.dart';

class EditUserAccessScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic> initialData;

  const EditUserAccessScreen({
    super.key,
    required this.email,
    required this.initialData,
  });

  @override
  State<EditUserAccessScreen> createState() => _EditUserAccessScreenState();
}

class _EditUserAccessScreenState extends State<EditUserAccessScreen> {
  late final TextEditingController _nameController;

  bool _administrator = false;
  bool _operator = false;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final name = (widget.initialData['name'] ?? '').toString();
    _nameController = TextEditingController(text: name);

    _administrator = widget.initialData['administrator'] == true;
    _operator = widget.initialData['operator'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.email);

      await ref.set({
        'name': _nameController.text.trim(),
        'administrator': _administrator,
        'operator': _operator,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, {
        'updated': true,
        'email': widget.email,
        'name': _nameController.text.trim(),
        'administrator': _administrator,
        'operator': _operator,
      });
    } catch (e) {
      await _feedback(
        false,
        'Update failed',
        'Unable to update user access record.',
        affected: ['User: ${widget.email}', 'Error: $e'],
      );
      if (!mounted) return;
      Navigator.pop(context, {'error': e.toString()});
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDelete() async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text(
              'Remove user access?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'This will delete the access record for:\n\n${widget.email}\n\n'
              'They will no longer be able to sign in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final ok = await _confirmDelete();
    if (!ok) return;

    setState(() => _deleting = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.email)
          .delete();

      if (!mounted) return;

      Navigator.pop(context, {'deleted': true, 'email': widget.email});
    } catch (e) {
      await _feedback(
        false,
        'Remove failed',
        'Unable to delete access record.',
        affected: ['User: ${widget.email}', 'Error: $e'],
      );
      if (!mounted) return;
      Navigator.pop(context, {'error': e.toString()});
    } finally {
      if (mounted) setState(() => _deleting = false);
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
          'Edit User Access',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Remove',
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
            onPressed: (_saving || _deleting) ? null : _delete,
          ),
        ],
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
              const SizedBox(height: 6),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
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
                enabled: !_saving && !_deleting,
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
                onChanged: (_saving || _deleting)
                    ? null
                    : (v) => setState(() => _administrator = v),
              ),
              SwitchListTile(
                title: const Text('Operator'),
                subtitle: const Text('Access to scanning/operator features'),
                value: _operator,
                onChanged: (_saving || _deleting)
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
                onPressed: (_saving || _deleting) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'SAVE CHANGES',
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
