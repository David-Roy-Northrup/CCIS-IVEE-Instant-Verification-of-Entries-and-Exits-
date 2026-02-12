// lib/screens/administrator/home_tabs/delete_log_tab.dart
//
// Delete Log tab — displays deletion audit logs stored in Firestore collection: `deleteLog`.
// UI mirrors Attendance Log cards, but replaces the date dropdown with a search bar,
// and includes a "Clear Logs" button that deletes all documents in `deleteLog`.
//
// SnackBars are NOT used. Feedback is shown using ActionFeedbackOverlay.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/action_feedback.dart';

class DeleteLogTab extends StatefulWidget {
  const DeleteLogTab({super.key});

  @override
  State<DeleteLogTab> createState() => _DeleteLogTabState();
}

class _DeleteLogTabState extends State<DeleteLogTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isClearing = false;

  DateTime _parseDateTimeOrFallback(String date, String time) {
    try {
      final d = DateFormat('MM/dd/yyyy').parse(date);
      final t = DateFormat('hh:mm:ssa').parse(time);
      return DateTime(d.year, d.month, d.day, t.hour, t.minute, t.second);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _confirmClearLogs() async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text(
              'Clear Delete Logs?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: const Text(
              'This will permanently remove ALL delete log entries.\n\n'
              'You can’t undo this action.',
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
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear Logs'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _clearLogs() async {
    if (_isClearing) return;

    final ok = await _confirmClearLogs();
    if (!ok) return;

    setState(() => _isClearing = true);

    try {
      final col = FirebaseFirestore.instance.collection('deleteLog');
      final snap = await col.get();

      final total = snap.docs.length;
      if (total == 0) {
        if (!mounted) return;
        await ActionFeedbackOverlay.show(
          context,
          success: true,
          title: 'Nothing to clear',
          message: 'Delete log is already empty.',
          affected: const ['deleteLog: 0 record(s)'],
        );
        return;
      }

      // Firestore batch limit safety: use chunks.
      const int batchLimit = 450;
      int deleted = 0;

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        ops++;
        deleted++;

        if (ops >= batchLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          ops = 0;
        }
      }

      if (ops > 0) {
        await batch.commit();
      }

      if (!mounted) return;
      await ActionFeedbackOverlay.show(
        context,
        success: true,
        title: 'Logs cleared',
        message: 'All delete log records have been removed.',
        affected: ['deleteLog: $deleted record(s) removed'],
      );
    } catch (e) {
      if (!mounted) return;
      await ActionFeedbackOverlay.show(
        context,
        success: false,
        title: 'Clear failed',
        message: 'Unable to clear logs.',
        affected: ['Error: $e'],
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
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

  Widget _pill({
    required IconData icon,
    required String text,
    Color? bg,
    Color? fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg ?? Colors.black87),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: fg ?? Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search (student ID, operator, remarks, date, type)…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
              ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _logCard({
    required String studentId,
    required String date,
    required String time,
    required String operatorName,
    required String type,
    required String remarks,
  }) {
    final title = studentId.trim().isEmpty ? 'UNKNOWN STUDENT ID' : studentId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(icon: Icons.calendar_today, text: date),
                    _pill(icon: Icons.schedule, text: time),
                    _pill(
                      icon: Icons.person_outline,
                      text: operatorName.isEmpty
                          ? 'Unknown operator'
                          : operatorName,
                    ),
                    _pill(
                      icon: Icons.label_outline,
                      text: type.isEmpty ? 'Unknown type' : type,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        remarks.trim().isEmpty
                            ? 'Remarks: (none)'
                            : 'Remarks: ${remarks.trim()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;

    final studentId = (data['studentID'] ?? '').toString().toLowerCase();
    final date = (data['date'] ?? '').toString().toLowerCase();
    final time = (data['time'] ?? '').toString().toLowerCase();
    final operatorName = (data['operator'] ?? '').toString().toLowerCase();
    final remarks = (data['remarks'] ?? '').toString().toLowerCase();
    final type = (data['type'] ?? '').toString().toLowerCase();

    final haystack = '$studentId $date $time $operatorName $remarks $type';
    return haystack.contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return _whitePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (title + clear logs)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'DELETE LOG',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isClearing ? null : _clearLogs,
                icon: _isClearing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_sweep),
                label: Text(_isClearing ? 'Clearing…' : 'Clear Logs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search bar (replaces dropdown)
          _searchBar(),
          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('deleteLog')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = (snapshot.data?.docs ?? []).toList();

                // Map + filter
                final filtered = <Map<String, dynamic>>[];
                for (final d in docs) {
                  final data = (d.data() as Map<String, dynamic>);
                  if (_matchesSearch(data)) {
                    filtered.add(data);
                  }
                }

                // Sort newest first (date+time)
                filtered.sort((a, b) {
                  final ad = (a['date'] ?? '').toString();
                  final at = (a['time'] ?? '').toString();
                  final bd = (b['date'] ?? '').toString();
                  final bt = (b['time'] ?? '').toString();

                  final aDT = _parseDateTimeOrFallback(ad, at);
                  final bDT = _parseDateTimeOrFallback(bd, bt);
                  return bDT.compareTo(aDT);
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No delete logs.'
                          : 'No results for "${_searchController.text.trim()}".',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final data = filtered[i];

                    final studentId = (data['studentID'] ?? '').toString();
                    final date = (data['date'] ?? '').toString();
                    final time = (data['time'] ?? '').toString();
                    final operatorName = (data['operator'] ?? '').toString();
                    final type = (data['type'] ?? '').toString();
                    final remarks = (data['remarks'] ?? '').toString();

                    return _logCard(
                      studentId: studentId,
                      date: date,
                      time: time,
                      operatorName: operatorName,
                      type: type,
                      remarks: remarks,
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
