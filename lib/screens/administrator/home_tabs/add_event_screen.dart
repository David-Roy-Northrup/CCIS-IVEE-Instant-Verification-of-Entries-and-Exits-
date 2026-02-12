import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../widgets/action_feedback.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final TextEditingController _nameController = TextEditingController();

  String _label = 'Login';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _feedbackError(
    String title,
    String message, {
    List<String> affected = const [],
  }) async {
    if (!mounted) return;
    await ActionFeedbackOverlay.show(
      context,
      success: false,
      title: title,
      message: message,
      affected: affected,
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await _feedbackError(
        'Missing event name',
        'Event name is required.',
        affected: const ['Field: Event Name'],
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('events').add({
        'eventName': name,
        'label': _label,
        // multiple events can be active; default new event to Active
        'isEnabled': true,
      });

      if (!mounted) return;

      // Return a result so the parent (EventsTab) can show the success feedback
      Navigator.pop(context, {
        'added': true,
        'eventName': name,
        'label': _label,
        'isEnabled': true,
      });
    } catch (e) {
      await _feedbackError(
        'Add failed',
        'Unable to add event.',
        affected: ['Error: $e'],
      );
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
        title: const Text('Add Event', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Event Name',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                enabled: !_saving,
                decoration: InputDecoration(
                  hintText: 'e.g. CCS Orientation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Label',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              RadioListTile<String>(
                title: const Text('Login'),
                value: 'Login',
                groupValue: _label,
                onChanged: _saving ? null : (v) => setState(() => _label = v!),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('Logout'),
                value: 'Logout',
                groupValue: _label,
                onChanged: _saving ? null : (v) => setState(() => _label = v!),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text('Unspecified'),
                value: '',
                groupValue: _label,
                onChanged: _saving ? null : (v) => setState(() => _label = v!),
                contentPadding: EdgeInsets.zero,
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
                        'ADD EVENT',
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
