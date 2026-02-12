import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';

import '../../../widgets/action_feedback.dart';

class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  static const String _defaultEvent = 'No event selected.';

  bool _loadingStats = true;

  String _selectedEvent = _defaultEvent;

  // Preloaded data
  int _totalStudents = 0;
  List<Map<String, String>> _students =
      []; // {idNumber, studentName, department, program}
  List<String> _events = []; // unique events from attendanceLog
  Map<String, Set<String>> _attendedIdsByEvent =
      {}; // eventName -> {studentIDs}
  Map<String, Set<String>> _eventsByStudent = {}; // studentID -> {eventNames}

  String get _todayPretty => DateFormat('MMMM dd, yyyy').format(DateTime.now());
  String get _todayDate => DateFormat('MM/dd/yyyy').format(DateTime.now());
  String get _nowTime => DateFormat('hh:mm:ssa').format(DateTime.now());

  String get _currentUserDisplay =>
      FirebaseAuth.instance.currentUser?.displayName ??
      (FirebaseAuth.instance.currentUser?.email ?? 'Unknown User');

  @override
  void initState() {
    super.initState();
    _preloadStatistics();
  }

  Future<void> _feedback({
    required bool success,
    required String title,
    required String message,
    List<String> affected = const [],
  }) async {
    if (!mounted) return;
    await ActionFeedbackOverlay.show(
      context,
      success: success,
      title: title,
      message: message,
      affected: affected,
    );
  }

  // -------------------- PRELOAD --------------------
  Future<void> _preloadStatistics() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);

    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('attendanceLog')
          .get();

      // Students
      final students = <Map<String, String>>[];
      for (final d in studentsSnap.docs) {
        final m = d.data();
        final id = (m['idNumber'] ?? d.id).toString().trim();
        final name = (m['studentName'] ?? '').toString().trim();
        final dept = (m['department'] ?? '').toString().trim();
        final prog = (m['program'] ?? '').toString().trim();

        if (id.isEmpty) continue;
        students.add({
          'idNumber': id,
          'studentName': name,
          'department': dept,
          'program': prog,
        });
      }

      // Attendance: build unique events + attended sets
      final eventSet = <String>{};
      final attendedIdsByEvent = <String, Set<String>>{};
      final eventsByStudent = <String, Set<String>>{};

      for (final d in attendanceSnap.docs) {
        final m = d.data();
        final sid = (m['studentID'] ?? '').toString().trim();
        final ev = (m['eventName'] ?? '').toString().trim();

        if (sid.isEmpty || ev.isEmpty) continue;

        eventSet.add(ev);

        attendedIdsByEvent.putIfAbsent(ev, () => <String>{}).add(sid);
        eventsByStudent.putIfAbsent(sid, () => <String>{}).add(ev);
      }

      final events = eventSet.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      // Ensure selected event is valid
      String nextSelected = _selectedEvent;
      if (nextSelected != _defaultEvent && !events.contains(nextSelected)) {
        nextSelected = _defaultEvent;
      }

      // Sort students: department, program, name
      students.sort((a, b) {
        int c = (a['department'] ?? '').toLowerCase().compareTo(
          (b['department'] ?? '').toLowerCase(),
        );
        if (c != 0) return c;

        c = (a['program'] ?? '').toLowerCase().compareTo(
          (b['program'] ?? '').toLowerCase(),
        );
        if (c != 0) return c;

        return (a['studentName'] ?? '').toLowerCase().compareTo(
          (b['studentName'] ?? '').toLowerCase(),
        );
      });

      if (!mounted) return;
      setState(() {
        _students = students;
        _totalStudents = students.length;
        _events = events;
        _attendedIdsByEvent = attendedIdsByEvent;
        _eventsByStudent = eventsByStudent;
        _selectedEvent = nextSelected;
        _loadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
      await _feedback(
        success: false,
        title: 'Load failed',
        message: 'Error loading statistics.',
        affected: ['Error: $e'],
      );
    }
  }

  // -------------------- CSV helpers --------------------
  String _csvEscape(String v) {
    final s = v.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  Future<File> _writeCsvToTemp(String csvText) async {
    final safeDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File(
      '${Directory.systemTemp.path}/ivee_scanned_records_$safeDate.csv',
    );
    await file.writeAsString(csvText, flush: true);
    return file;
  }

  Future<void> _openEmailWithAttachment({
    required String subject,
    required String body,
    required String attachmentPath,
  }) async {
    final email = Email(
      subject: subject,
      body: body,
      recipients: const [], // user selects recipient
      attachmentPaths: [attachmentPath],
      isHTML: false,
    );
    await FlutterEmailSender.send(email);
  }

  // -------------------- Firestore helpers --------------------
  Future<void> _logDelete({
    required String type,
    required String remarks,
    required String studentId,
  }) async {
    await FirebaseFirestore.instance.collection('deleteLog').add({
      'operator': _currentUserDisplay,
      'remarks': remarks,
      'studentID': studentId,
      'date': _todayDate,
      'time': _nowTime,
      'type': type,
    });
  }

  Future<bool> _confirmDanger({
    required String title,
    required String message,
    String confirmText = 'Yes, delete',
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
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
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<int> _deleteAllInCollection(String collectionName) async {
    final col = FirebaseFirestore.instance.collection(collectionName);
    int deleted = 0;

    while (true) {
      final snap = await col.limit(450).get();
      if (snap.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
        deleted++;
      }
      await batch.commit();
    }

    return deleted;
  }

  Future<void> _clearAttendanceRecords() async {
    final confirm = await _confirmDanger(
      title: 'Clear Attendance Records',
      message:
          'This will permanently delete ALL attendanceLog records.\n\nMake sure you saved a backup before continuing.',
      confirmText: 'Clear Attendance',
    );
    if (!confirm) return;

    try {
      final deleted = await _deleteAllInCollection('attendanceLog');
      await _logDelete(
        type: 'Attendance',
        remarks: 'Cleared ALL attendance records (backup recommended).',
        studentId: 'ALL',
      );

      await _feedback(
        success: true,
        title: 'Attendance cleared',
        message: 'All attendance records were removed.',
        affected: [
          'attendanceLog: $deleted record(s) removed',
          'deleteLog: +1 record',
        ],
      );

      await _preloadStatistics();
    } catch (e) {
      await _feedback(
        success: false,
        title: 'Clear failed',
        message: 'Error clearing attendance records.',
        affected: ['Error: $e'],
      );
    }
  }

  Future<void> _clearStudentRecords() async {
    final confirm = await _confirmDanger(
      title: 'Clear Student Records',
      message:
          'This will permanently delete ALL student records.\n\nMake sure you saved a backup before continuing.',
      confirmText: 'Clear Students',
    );
    if (!confirm) return;

    try {
      final deleted = await _deleteAllInCollection('students');
      await _logDelete(
        type: 'Students',
        remarks: 'Cleared ALL student records (backup recommended).',
        studentId: 'ALL',
      );

      await _feedback(
        success: true,
        title: 'Students cleared',
        message: 'All student records were removed.',
        affected: [
          'students: $deleted record(s) removed',
          'deleteLog: +1 record',
        ],
      );

      await _preloadStatistics();
    } catch (e) {
      await _feedback(
        success: false,
        title: 'Clear failed',
        message: 'Error clearing student records.',
        affected: ['Error: $e'],
      );
    }
  }

  // -------------------- Send Data --------------------
  Future<void> _sendDataAsCsv() async {
    try {
      // Ensure preloaded data exists
      if (_loadingStats) {
        await _feedback(
          success: false,
          title: 'Please wait',
          message: 'Statistics are still loading.',
          affected: const ['Action: Email Attendance Log'],
        );
        return;
      }

      // Events must come from attendanceLog only (already preloaded)
      final events = List<String>.from(_events);

      final header = <String>[
        'Department',
        'Program',
        'Student ID',
        'Student Name',
        ...events,
      ];

      final lines = <String>[];
      lines.add(header.map(_csvEscape).join(','));

      for (final s in _students) {
        final dept = (s['department'] ?? '');
        final prog = (s['program'] ?? '');
        final id = (s['idNumber'] ?? '');
        final name = (s['studentName'] ?? '');

        final set = _eventsByStudent[id] ?? <String>{};

        final row = <String>[
          dept,
          prog,
          id,
          name,
          ...events.map((ev) => set.contains(ev) ? '✔' : ''),
        ];

        lines.add(row.map(_csvEscape).join(','));
      }

      final csvText = lines.join('\n');

      // 1) Generate CSV file first
      final file = await _writeCsvToTemp(csvText);

      // 2) Then open email app with attachment
      final subject = 'IVEE Scanned Records as of $_todayPretty';
      final body =
          'Attached is the IVEE Scanned Records CSV as of $_todayPretty.\n\nGenerated by IVEE Admin.';

      try {
        await _openEmailWithAttachment(
          subject: subject,
          body: body,
          attachmentPath: file.path,
        );

        await _feedback(
          success: true,
          title: 'Email ready',
          message: 'Email app opened with the CSV attached.',
          affected: [
            'Attachment: ${file.path}',
            'Students: $_totalStudents',
            'Events: ${events.length}',
          ],
        );
      } on PlatformException catch (e) {
        // Common: "No email clients found!"
        await _feedback(
          success: false,
          title: 'No email app found',
          message:
              'CSV was generated, but no email app was found. Install/configure an email client and try again.',
          affected: [
            'Attachment: ${file.path}',
            'Details: ${e.message ?? e.code}',
          ],
        );
      }
    } catch (e) {
      await _feedback(
        success: false,
        title: 'Export failed',
        message: 'Error generating/sending CSV.',
        affected: ['Error: $e'],
      );
    }
  }

  // -------------------- UI helpers --------------------
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

  Widget _statCard({
    required String title,
    required String value,
    IconData icon = Icons.analytics_outlined,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade100,
            ),
            child: Icon(icon, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _percentCircle({required double value, required String centerText}) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          Text(
            centerText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _loadingDashboard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'Loading Statistics',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendedCount = (_selectedEvent == _defaultEvent)
        ? 0
        : (_attendedIdsByEvent[_selectedEvent]?.length ?? 0);

    final percent = (_totalStudents == 0 || _selectedEvent == _defaultEvent)
        ? 0.0
        : attendedCount / _totalStudents;

    return _whitePane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'STATISTICS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _preloadStatistics,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Students count card (preloaded)
          _statCard(
            title: 'Students on record',
            value: _loadingStats ? '...' : _totalStudents.toString(),
            icon: Icons.people_alt_outlined,
          ),

          const SizedBox(height: 12),

          // Event attendance dashboard (preloaded) - while loading show ONLY "Loading Statistics"
          if (_loadingStats)
            _loadingDashboard()
          else
            Container(
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Attendance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: _selectedEvent,
                    items: <String>[_defaultEvent, ..._events]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedEvent = v ?? _defaultEvent;
                      });
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _percentCircle(
                        value: percent,
                        centerText: '${(percent * 100).toStringAsFixed(0)}%',
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedEvent == _defaultEvent
                                  ? 'Select an event to view stats.'
                                  : _selectedEvent,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Attended: $attendedCount',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Total Students: $_totalStudents',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0F3C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _sendDataAsCsv,
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'Email Attendance Log',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _clearAttendanceRecords,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text(
                    'Clear Attendance Records',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _clearStudentRecords,
                  icon: const Icon(Icons.person_remove_alt_1),
                  label: const Text(
                    'Clear Student Records',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
