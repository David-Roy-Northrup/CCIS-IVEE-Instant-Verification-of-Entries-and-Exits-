// lib/screens/administrator/home_tabs/delete_log_tab.dart
//
// Delete Log tab — displays deletion audit logs stored in Firestore collection: `deleteLog`.
// UI mirrors Attendance Log cards, but replaces the date dropdown with a search bar.
//
// SnackBars are NOT used. Feedback is shown using ActionFeedbackOverlay.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeleteLogTab extends StatefulWidget {
  const DeleteLogTab({super.key});

  @override
  State<DeleteLogTab> createState() => _DeleteLogTabState();
}

class _DeleteLogTabState extends State<DeleteLogTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
              ),
        filled: true,
        fillColor: Colors.grey.shade100,
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
          const Text(
            'DELETE LOG',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

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

                final filtered = <Map<String, dynamic>>[];
                for (final d in docs) {
                  final data = (d.data() as Map<String, dynamic>);
                  if (_matchesSearch(data)) {
                    filtered.add(data);
                  }
                }

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
