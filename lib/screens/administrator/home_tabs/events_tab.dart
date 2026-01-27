import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_event_screen.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _eventSearchController = TextEditingController();

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

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.black87),
    );
  }

  Future<void> _toggleEventEnabled(String docId, bool currentlyEnabled) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(docId).update({
        'isEnabled': !currentlyEnabled,
      });
    } catch (e) {
      _snack('Error updating event: $e', color: Colors.red);
    }
  }

  Future<void> _resetAllEvents() async {
    try {
      final eventsRef = FirebaseFirestore.instance.collection('events');
      final snap = await eventsRef.get();
      final batch = FirebaseFirestore.instance.batch();

      for (final d in snap.docs) {
        batch.update(d.reference, {'isEnabled': false});
      }

      await batch.commit();
      _snack('All events set to Inactive.');
    } catch (e) {
      _snack('Error resetting events: $e', color: Colors.red);
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
        _snack('Event deleted.', color: Colors.green);
      } catch (e) {
        _snack('Error deleting event: $e', color: Colors.red);
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
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      iconSize: 18,
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
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
                  decoration: const InputDecoration(
                    hintText: 'Search events',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _tinyIconButton(
                icon: Icons.restart_alt,
                color: Colors.orange,
                tooltip: 'Set all to Inactive',
                onPressed: _resetAllEvents,
              ),
              const SizedBox(width: 8),
              _tinyIconButton(
                icon: Icons.add_circle,
                color: Colors.green,
                tooltip: 'Add Event',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEventScreen()),
                  );
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
                  if (aEn != bEn) return bEn ? 1 : -1;

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
                                  _toggleEventEnabled(doc.id, enabled),
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
