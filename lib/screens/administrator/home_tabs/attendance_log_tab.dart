// lib/screens/operator/home_tabs/attendance_log_tab.dart
//
// Attendance Log tab (dashboard cards) — filters to today's records.
// Each record shows: Student Name, Time, Event, Program, Department, Scanned by.
// Delete button: asks "Are you sure...?" then asks for remarks, then deletes + writes deleteLog.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AttendanceLogTab extends StatefulWidget {
  const AttendanceLogTab({super.key});

  @override
  State<AttendanceLogTab> createState() => _AttendanceLogTabState();
}

class _AttendanceLogTabState extends State<AttendanceLogTab> {
  String get todayDate => DateFormat('MM/dd/yyyy').format(DateTime.now());
  String get currentTime => DateFormat('hh:mm:ssa').format(DateTime.now());

  String get currentUserDisplay =>
      FirebaseAuth.instance.currentUser?.displayName ??
      (FirebaseAuth.instance.currentUser?.email ?? 'Unknown User');

  Future<void> _snack(String msg, {Color? color}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.black87),
    );
  }

  DateTime _parseTimeOrFallback(String t) {
    try {
      return DateFormat('hh:mm:ssa').parse(t);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<String?> _askRemarks() async {
    final TextEditingController remarksController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Reason for Deletion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'Enter remark',
            hintText: 'e.g., Duplicate / Wrong scan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final remark = remarksController.text.trim();
              if (remark.isEmpty) {
                _snack('Remark cannot be blank!', color: Colors.red);
                return;
              }
              Navigator.of(ctx).pop(remark);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Attendance Record',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to delete this record?'),
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
    return confirm == true;
  }

  Future<void> _deleteAttendanceDoc({
    required String docId,
    required String studentId,
  }) async {
    // Step 1: "Are you sure?"
    final sure = await _confirmDeleteDialog();
    if (!sure) return;

    // Step 2: remarks (required)
    final remarks = await _askRemarks();
    if (remarks == null || remarks.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('attendanceLog')
          .doc(docId)
          .delete();

      await FirebaseFirestore.instance.collection('deleteLog').add({
        'operator': currentUserDisplay,
        'remarks': remarks,
        'studentID': studentId,
        'date': todayDate,
        'time': currentTime,
        'type': "Attendance",
      });

      await _snack('Record deleted.', color: Colors.green);
    } catch (e) {
      await _snack('Error deleting record: $e', color: Colors.red);
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

  Widget _recordCard({
    required String docId,
    required String studentName,
    required String studentId,
    required String time,
    required String eventName,
    required String program,
    required String department,
    required String scannedBy,
  }) {
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
          // left info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName.isEmpty ? 'UNKNOWN STUDENT' : studentName,
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
                    _pill(icon: Icons.badge_outlined, text: studentId),
                    _pill(icon: Icons.schedule, text: time),
                    _pill(icon: Icons.celebration, text: eventName),
                    _pill(icon: Icons.school_outlined, text: program),
                    _pill(icon: Icons.apartment_outlined, text: department),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Scanned by: $scannedBy',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // delete
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () =>
                _deleteAttendanceDoc(docId: docId, studentId: studentId),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _whitePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TODAY'S ATTENDANCE LOG",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendanceLog')
                  .where('date', isEqualTo: todayDate)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = (snapshot.data?.docs ?? []).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No attendance records today.'),
                  );
                }

                docs.sort((a, b) {
                  final at = (a['time'] ?? '').toString();
                  final bt = (b['time'] ?? '').toString();
                  return _parseTimeOrFallback(
                    bt,
                  ).compareTo(_parseTimeOrFallback(at));
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;

                    final studentName = (data['studentName'] ?? '').toString();
                    final studentId = (data['studentID'] ?? '').toString();
                    final time = (data['time'] ?? '').toString();
                    final eventName = (data['eventName'] ?? '').toString();

                    final program = (data['program'] ?? '').toString();
                    final department = (data['department'] ?? '').toString();

                    // In attendanceLog, "operator" is typically email
                    final scannedBy = (data['operator'] ?? '').toString();

                    return _recordCard(
                      docId: d.id,
                      studentName: studentName,
                      studentId: studentId,
                      time: time,
                      eventName: eventName,
                      program: program,
                      department: department,
                      scannedBy: scannedBy,
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
