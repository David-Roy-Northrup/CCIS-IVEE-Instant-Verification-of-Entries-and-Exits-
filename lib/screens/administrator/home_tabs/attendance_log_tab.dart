// lib/screens/operator/home_tabs/attendance_log_tab.dart
//
// ATTENDANCE LOG tab — now supports date selection via dropdown.
// Default selection is "TODAY" (value = today's MM/dd/yyyy).
//
// Each record shows: Student Name, Time, Event, Program, Department, Scanned by.
// Delete button: asks confirmation, then asks remarks, then deletes + writes deleteLog.
//
// NOTE: All SnackBars removed. Uses ActionFeedbackOverlay instead.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../widgets/action_feedback.dart';

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

  // Selected date value (MM/dd/yyyy). Default = today.
  late String _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = todayDate;
  }

  DateTime _parseDateOrFallback(String d) {
    try {
      return DateFormat('MM/dd/yyyy').parse(d);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
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
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Reason for Deletion',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  labelText: 'Enter remark',
                  hintText: 'e.g., Duplicate / Wrong scan',
                  errorText: errorText,
                ),
                autofocus: true,
              ),
            ],
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
                  setLocal(() => errorText = 'Remark cannot be blank.');
                  return;
                }
                Navigator.of(ctx).pop(remark);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
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
    required String recordDate,
    required String recordTime,
    required String eventName,
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
        // deletion timestamp (kept consistent with your existing schema)
        'date': todayDate,
        'time': currentTime,
        'type': "Attendance",
        // extra helpful context (won't break existing UI/search)
        'recordDate': recordDate,
        'recordTime': recordTime,
        'eventName': eventName,
      });

      if (!mounted) return;
      await ActionFeedbackOverlay.show(
        context,
        success: true,
        title: 'Record deleted',
        message: 'Attendance record was removed successfully.',
        affected: [
          'attendanceLog: 1 record removed',
          'Student ID: $studentId',
          'Record Date: $recordDate',
          if (recordTime.trim().isNotEmpty) 'Record Time: $recordTime',
          if (eventName.trim().isNotEmpty) 'Event: $eventName',
        ],
      );
    } catch (e) {
      if (!mounted) return;
      await ActionFeedbackOverlay.show(
        context,
        success: false,
        title: 'Delete failed',
        message: 'Unable to delete attendance record.',
        affected: ['Error: $e'],
      );
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
    required String recordDate,
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
                    _pill(
                      icon: Icons.badge_outlined,
                      text: studentId.isEmpty ? 'UNKNOWN ID' : studentId,
                    ),
                    _pill(icon: Icons.schedule, text: time),
                    _pill(
                      icon: Icons.celebration,
                      text: eventName.isEmpty ? 'UNKNOWN EVENT' : eventName,
                    ),
                    _pill(
                      icon: Icons.school_outlined,
                      text: program.isEmpty ? 'UNKNOWN PROGRAM' : program,
                    ),
                    _pill(
                      icon: Icons.apartment_outlined,
                      text: department.isEmpty ? 'UNKNOWN DEPT' : department,
                    ),
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
            onPressed: () => _deleteAttendanceDoc(
              docId: docId,
              studentId: studentId,
              recordDate: recordDate,
              recordTime: time,
              eventName: eventName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateDropdown(List<String> availableDates) {
    // Ensure selected date always exists in items
    final set = <String>{...availableDates, todayDate, _selectedDate};
    final dates = set.where((d) => d.trim().isNotEmpty).toList();

    // Sort by actual date descending
    dates.sort(
      (a, b) => _parseDateOrFallback(b).compareTo(_parseDateOrFallback(a)),
    );

    // Put today first (label = TODAY), then the rest (excluding today)
    final ordered = <String>[todayDate, ...dates.where((d) => d != todayDate)];

    return Row(
      children: [
        const Text(
          'Date:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedDate,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: ordered.map((d) {
              final label = (d == todayDate) ? 'TODAY' : d;
              return DropdownMenuItem<String>(
                value: d,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedDate = v);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _whitePane(
      child: StreamBuilder<QuerySnapshot>(
        // Used ONLY to build the available date list for the dropdown.
        // If your dataset grows large, consider maintaining a separate collection of dates.
        stream: FirebaseFirestore.instance
            .collection('attendanceLog')
            .snapshots(),
        builder: (context, dateSnap) {
          final availableDates = <String>[];

          if (dateSnap.hasData) {
            final docs = dateSnap.data!.docs;
            final set = <String>{};
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              final ds = (data['date'] ?? '').toString().trim();
              if (ds.isNotEmpty) set.add(ds);
            }
            availableDates.addAll(set);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "ATTENDANCE LOG",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _dateDropdown(availableDates),
              const SizedBox(height: 10),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendanceLog')
                      .where('date', isEqualTo: _selectedDate)
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
                      final msg = (_selectedDate == todayDate)
                          ? 'No attendance records today.'
                          : 'No attendance records for $_selectedDate.';
                      return Center(child: Text(msg));
                    }

                    // Sort by time descending (within selected date)
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

                        final studentName = (data['studentName'] ?? '')
                            .toString();
                        final studentId = (data['studentID'] ?? '').toString();
                        final time = (data['time'] ?? '').toString();
                        final eventName = (data['eventName'] ?? '').toString();

                        final program = (data['program'] ?? '').toString();
                        final department = (data['department'] ?? '')
                            .toString();

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
                          recordDate: _selectedDate,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
