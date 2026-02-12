// lib/screens/administrator/home_tabs/events_tab.dart
//
// ✅ Change requested:
// When opening / accessing this page, immediately check each event's schedule bounds,
// and if it is currently within the active window but not active, set it to ACTIVE automatically.
// Also keeps the periodic (per-second) scheduler so it continues to flip on/off as time passes.
//
// Rules implemented:
// - If startAt exists and now < startAt -> should be INACTIVE
// - If endAt exists and now >= endAt  -> should be INACTIVE
// - Otherwise (within bounds or bounds are open-ended) -> should be ACTIVE
//   - If only endAt exists and now < endAt -> ACTIVE
//   - If only startAt exists and now >= startAt -> ACTIVE
// - If no schedule fields at all -> do nothing (manual toggle only)
//
// We also:
// - run a "one-time" schedule sync on first snapshot / first build
// - avoid spamming updates using _autoBusy set
// - continue showing timer labels ("Active in ..." / "Inactive in ...")

import 'dart:async';

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

  Timer? _uiTick; // refresh countdown + scheduler
  final Set<String> _autoBusy = <String>{}; // prevent spam updates

  bool _initialScheduleSynced =
      false; // ✅ run schedule check once when page is accessed

  @override
  void initState() {
    super.initState();
    _eventSearchController.addListener(() => setState(() {}));

    // Tick UI every second so timers update live + apply schedule continuously
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    _eventSearchController.dispose();
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

  Future<void> _toggleEventEnabled(
    String docId,
    bool currentlyEnabled,
    String displayName,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(docId).update({
        'isEnabled': !currentlyEnabled,
      });
    } catch (e) {
      await _feedbackError(
        'Update failed',
        'Unable to update event status.',
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

      const int batchLimit = 450;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      for (final d in snap.docs) {
        batch.update(d.reference, {'isEnabled': false});
        ops++;
        if (ops >= batchLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
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

  DateTime? _readOptionalDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    return null;
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '0s';

    final totalSeconds = d.inSeconds;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String two(int n) => n.toString().padLeft(2, '0');

    if (days > 0) return '${days}d ${two(hours)}h ${two(minutes)}m';
    if (hours > 0) return '${two(hours)}h ${two(minutes)}m ${two(seconds)}s';
    if (minutes > 0) return '${two(minutes)}m ${two(seconds)}s';
    return '${seconds}s';
  }

  bool _hasAnySchedule(DateTime? startAt, DateTime? endAt) =>
      startAt != null || endAt != null;

  /// Computes whether event SHOULD be enabled based on bounds.
  /// Returns null if there is no schedule at all.
  bool? _computeShouldBeEnabled({
    required DateTime now,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    if (!_hasAnySchedule(startAt, endAt)) return null;

    // Before start -> inactive
    if (startAt != null && now.isBefore(startAt)) return false;

    // At/after cutoff -> inactive
    if (endAt != null && !now.isBefore(endAt)) return false;

    // Otherwise within window / open-ended -> active
    return true;
  }

  // ✅ Auto-update isEnabled to match schedule
  Future<void> _applyScheduleIfNeeded({
    required String docId,
    required bool currentEnabled,
    required DateTime now,
    required DateTime? startAt,
    required DateTime? endAt,
  }) async {
    final shouldBeEnabled = _computeShouldBeEnabled(
      now: now,
      startAt: startAt,
      endAt: endAt,
    );

    if (shouldBeEnabled == null) return; // no schedule -> manual only
    if (shouldBeEnabled == currentEnabled) return;
    if (_autoBusy.contains(docId)) return;

    _autoBusy.add(docId);
    try {
      await FirebaseFirestore.instance.collection('events').doc(docId).update({
        'isEnabled': shouldBeEnabled,
      });
    } catch (_) {
      // silent (avoid spamming dialogs)
    } finally {
      _autoBusy.remove(docId);
    }
  }

  // ✅ One-time sync when opening page (first snapshot)
  Future<void> _syncAllEventsOnce(List<QueryDocumentSnapshot> docs) async {
    if (_initialScheduleSynced) return;
    _initialScheduleSynced = true;

    final now = DateTime.now();
    for (final d in docs) {
      final m = (d.data() as Map<String, dynamic>);
      final enabled = (m['isEnabled'] == true);

      final startAt = _readOptionalDateTime(m['startAt']);
      final endAt = _readOptionalDateTime(m['endAt']);

      final shouldBeEnabled = _computeShouldBeEnabled(
        now: now,
        startAt: startAt,
        endAt: endAt,
      );

      // "If within the time bound and not active, set active automatically"
      if (shouldBeEnabled == true && enabled == false) {
        await _applyScheduleIfNeeded(
          docId: d.id,
          currentEnabled: enabled,
          now: now,
          startAt: startAt,
          endAt: endAt,
        );
      }

      // (Optional but consistent): if already past cutoff but still active, flip off
      if (shouldBeEnabled == false && enabled == true) {
        await _applyScheduleIfNeeded(
          docId: d.id,
          currentEnabled: enabled,
          now: now,
          startAt: startAt,
          endAt: endAt,
        );
      }
    }
  }

  String? _timerLineForEvent({
    required DateTime now,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    // If start is in the future => countdown until active
    if (startAt != null && now.isBefore(startAt)) {
      return 'Active in ${_formatDuration(startAt.difference(now))}';
    }

    // Otherwise, if cutoff is in the future => countdown until inactive
    if (endAt != null && now.isBefore(endAt)) {
      return 'Inactive in ${_formatDuration(endAt.difference(now))}';
    }

    return null;
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
                    hintText: 'Search',
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
                  try {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEventScreen()),
                    );
                  } catch (e) {
                    await _feedbackError(
                      'Add failed',
                      'Unable to open/add event.',
                      affected: ['Error: $e'],
                    );
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

                final now = DateTime.now();
                final q = _eventSearchController.text.trim().toLowerCase();
                final docs = snapshot.data!.docs.toList();

                // ✅ One-time schedule check when page is accessed / first loads
                // ignore: discarded_futures
                _syncAllEventsOnce(docs);

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

                    final startAt = _readOptionalDateTime(data['startAt']);
                    final endAt = _readOptionalDateTime(data['endAt']);

                    // ✅ Continuous auto-apply (keeps on/off correct as time passes)
                    // ignore: discarded_futures
                    _applyScheduleIfNeeded(
                      docId: doc.id,
                      currentEnabled: enabled,
                      now: now,
                      startAt: startAt,
                      endAt: endAt,
                    );

                    final timerLine = _timerLineForEvent(
                      now: now,
                      startAt: startAt,
                      endAt: endAt,
                    );

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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    display,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (timerLine != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      timerLine,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
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
