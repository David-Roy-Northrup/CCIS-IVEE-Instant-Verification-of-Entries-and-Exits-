import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../widgets/action_feedback.dart';
import 'add_event_screen.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _eventSearchController = TextEditingController();
  bool _resetBusy = false;

  @override
  void initState() {
    super.initState();
    _eventSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _eventSearchController.dispose();
    super.dispose();
  }

  Future<void> _feedbackSuccess(
    String title,
    String message, {
    List<String> affected = const [],
  }) async {
    if (!mounted) return;
    await ActionFeedbackOverlay.show(
      context,
      success: true,
      title: title,
      message: message,
      affected: affected,
    );
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

  Future<void> _toggleEventEnabled(
    String docId,
    bool currentlyEnabled,
    String displayName,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(docId).update({
        'isEnabled': !currentlyEnabled,
      });

      await _feedbackSuccess(
        'Event updated',
        currentlyEnabled ? 'Event set to Inactive.' : 'Event set to Active.',
        affected: [
          'Event: $displayName',
          'Status: ${currentlyEnabled ? 'Inactive' : 'Active'}',
          'events/$docId updated',
        ],
      );
    } catch (e) {
      await _feedbackError(
        'Update failed',
        'Unable to update event.',
        affected: ['Event: $displayName', 'Error: $e'],
      );
    }
  }

  Future<void> _resetAllEvents() async {
    if (_resetBusy) return;

    setState(() => _resetBusy = true);
    try {
      final eventsRef = FirebaseFirestore.instance.collection('events');
      final snap = await eventsRef.get();

      if (snap.docs.isEmpty) {
        await _feedbackSuccess(
          'Nothing to reset',
          'No events were found.',
          affected: const ['events: 0 record(s)'],
        );
        return;
      }

      // Firestore batch limit safety: commit in chunks.
      const int batchLimit = 450;
      int updated = 0;

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      for (final d in snap.docs) {
        batch.update(d.reference, {'isEnabled': false});
        ops++;
        updated++;
        if (ops >= batchLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          ops = 0;
        }
      }
      if (ops > 0) {
        await batch.commit();
      }

      await _feedbackSuccess(
        'Events reset',
        'All events set to Inactive.',
        affected: ['events: $updated record(s) updated', 'isEnabled = false'],
      );
    } catch (e) {
      await _feedbackError(
        'Reset failed',
        'Unable to reset events.',
        affected: ['Error: $e'],
      );
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  Future<void> _confirmDeleteEvent(String docId, String displayName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Event',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete:\n\n$displayName'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(docId)
            .delete();
        await _feedbackSuccess(
          'Event deleted',
          'Event removed successfully.',
          affected: ['Event: $displayName', 'events/$docId deleted'],
        );
      } catch (e) {
        await _feedbackError(
          'Delete failed',
          'Unable to delete event.',
          affected: ['Event: $displayName', 'Error: $e'],
        );
      }
    }
  }

  Widget _whitePane({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _tinyIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    String? tooltip,
    bool disabled = false,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      iconSize: 22,
      color: disabled ? Colors.grey : (color ?? Colors.black87),
      tooltip: tooltip,
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon),
    );
  }

  Widget _statusButton({
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.white,
        backgroundColor: enabled ? Colors.green : Colors.grey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        enabled ? 'Active' : 'Inactive',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _whitePane(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _eventSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search events',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _eventSearchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () => _eventSearchController.clear(),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _tinyIconButton(
                icon: Icons.restart_alt,
                color: Colors.orange,
                tooltip: 'Set all to Inactive',
                disabled: _resetBusy,
                onPressed: _resetAllEvents,
              ),
              const SizedBox(width: 8),
              _tinyIconButton(
                icon: Icons.add_circle,
                color: Colors.green,
                tooltip: 'Add Event',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEventScreen()),
                  );

                  if (result is Map) {
                    final added = result['added'] == true;
                    if (added) {
                      final name = (result['eventName'] ?? '').toString();
                      final label = (result['label'] ?? '').toString();
                      final display = label.isEmpty ? name : '$name - $label';

                      await _feedbackSuccess(
                        'Event added',
                        'New event created successfully.',
                        affected: [
                          if (display.trim().isNotEmpty) 'Event: $display',
                          'events: +1 record',
                          'Default status: Active',
                        ],
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _eventSearchController.text.trim().toLowerCase();
                final docs = snapshot.data!.docs.toList();

                // Sort enabled first then name
                docs.sort((a, b) {
                  final am = (a.data() as Map<String, dynamic>);
                  final bm = (b.data() as Map<String, dynamic>);
                  final aEn = (am['isEnabled'] == true);
                  final bEn = (bm['isEnabled'] == true);
                  if (aEn != bEn) return aEn ? -1 : 1;

                  final aName = (am['eventName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final bName = (bm['eventName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return aName.compareTo(bName);
                });

                final filtered = docs.where((d) {
                  final m = (d.data() as Map<String, dynamic>);
                  final name = (m['eventName'] ?? '').toString().toLowerCase();
                  final label = (m['label'] ?? '').toString().toLowerCase();
                  if (q.isEmpty) return true;
                  return name.contains(q) || label.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No events found.'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = (doc.data() as Map<String, dynamic>);

                    final name = (data['eventName'] ?? '').toString();
                    final label = (data['label'] ?? '').toString();
                    final enabled = (data['isEnabled'] == true);

                    final display = label.isEmpty ? name : "$name - $label";

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                display,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _statusButton(
                              enabled: enabled,
                              onPressed: () =>
                                  _toggleEventEnabled(doc.id, enabled, display),
                            ),
                            const SizedBox(width: 10),
                            _tinyIconButton(
                              icon: Icons.delete,
                              color: Colors.red,
                              tooltip: 'Delete',
                              onPressed: () =>
                                  _confirmDeleteEvent(doc.id, display),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
