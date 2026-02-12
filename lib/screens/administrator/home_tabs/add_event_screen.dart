// lib/screens/administrator/home_tabs/add_event_screen.dart
//
// ✅ Change: New events default to INACTIVE (isEnabled: false)
// ✅ Schedule is still optional (startAt/endAt can be null)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  DateTime? _startAt; // optional
  DateTime? _endAt; // optional

  final DateFormat _dtFmt = DateFormat('MMM dd, yyyy • hh:mm a');

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

  Future<DateTime?> _pickDateTime({
    required String title,
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final init = initial ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: title,
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
      helpText: title,
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      final payload = <String, dynamic>{
        'eventName': name,
        'label': _label,

        // ✅ Default new event to Inactive
        'isEnabled': false,
      };

      // Optional schedule fields
      if (_startAt != null) payload['startAt'] = Timestamp.fromDate(_startAt!);
      if (_endAt != null) payload['endAt'] = Timestamp.fromDate(_endAt!);

      await FirebaseFirestore.instance.collection('events').add(payload);

      if (!mounted) return;

      Navigator.pop(context, {
        'added': true,
        'eventName': name,
        'label': _label,
        'isEnabled': false,
        'startAt': _startAt,
        'endAt': _endAt,
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

  Widget _scheduleRow({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : onPick,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value == null ? label : '$label: ${_dtFmt.format(value)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Clear',
          onPressed: _saving || value == null ? null : onClear,
          icon: const Icon(Icons.close),
        ),
      ],
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
                  hintText: 'e.g. IT Week',
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
              const Divider(height: 24),
              const Text(
                'Active Schedule (Optional)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _scheduleRow(
                label: 'Start Time',
                value: _startAt,
                onPick: () async {
                  final picked = await _pickDateTime(
                    title: 'Start Time',
                    initial: _startAt,
                  );
                  if (picked != null) setState(() => _startAt = picked);
                },
                onClear: () => setState(() => _startAt = null),
              ),
              const SizedBox(height: 10),
              _scheduleRow(
                label: 'Cutoff',
                value: _endAt,
                onPick: () async {
                  final picked = await _pickDateTime(
                    title: 'Cutoff',
                    initial: _endAt,
                  );
                  if (picked != null) setState(() => _endAt = picked);
                },
                onClear: () => setState(() => _endAt = null),
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
