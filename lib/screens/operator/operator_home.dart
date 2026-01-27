// lib/screens/operator/operator_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OperatorHome extends StatefulWidget {
  const OperatorHome({super.key});

  @override
  State<OperatorHome> createState() => _OperatorHomeState();
}

class _OperatorHomeState extends State<OperatorHome> {
  final Map<String, String> _studentNamesCache = {}; // studentID -> studentName

  String get todayDate => DateFormat('MM/dd/yyyy').format(DateTime.now());
  String get currentTime => DateFormat('hh:mm:ssa').format(DateTime.now());

  String get operatorEmail =>
      FirebaseAuth.instance.currentUser?.email?.trim() ?? 'unknown@cjc.edu.ph';

  String get operatorFullName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown User';

  String get operatorNameForHeader {
    final name = operatorFullName.trim();
    if (name.isEmpty) return 'Unknown User';
    return name.split(' ').first; // keep it short in header
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    Color iconColor = Colors.blue,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  Future<void> _preloadStudentNames(List<String> studentIds) async {
    final firestore = FirebaseFirestore.instance;
    final batchIds = studentIds.toSet().toList();
    final batchMap = <String, String>{};

    if (batchIds.isEmpty) return;

    try {
      final snapshots = await Future.wait(
        batchIds.map((id) => firestore.collection('students').doc(id).get()),
      );

      for (var snap in snapshots) {
        if (snap.exists) {
          final id = snap.id;
          final name = (snap.data()?['studentName'] ?? '').toString();
          if (name.isNotEmpty) batchMap[id] = name;
        }
      }

      if (mounted && batchMap.isNotEmpty) {
        setState(() {
          _studentNamesCache.addAll(batchMap);
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<bool> _confirmSimpleDelete() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
    return res ?? false;
  }

  Future<String?> _askRemarks() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Reason for Deletion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Enter remark',
            hintText: 'e.g., Wrong scan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final remark = controller.text.trim();
              if (remark.isEmpty) return;
              Navigator.of(ctx).pop(remark);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAttendanceRecord({
    required String docId,
    required String studentID,
    required String eventName,
  }) async {
    final ok = await _confirmSimpleDelete();
    if (!ok) return;

    final remarks = await _askRemarks();
    if (remarks == null || remarks.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('attendanceLog')
          .doc(docId)
          .delete();

      await FirebaseFirestore.instance.collection('deleteLog').add({
        'operator': operatorFullName,
        'remarks': remarks.trim(),
        'studentID': studentID,
        'eventName': eventName,
        'date': todayDate,
        'time': currentTime,
        'type': "Attendance",
      });

      await _showInfoDialog(
        title: 'Deleted',
        message: 'Record deleted successfully.',
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
      );
    } catch (_) {
      await _showInfoDialog(
        title: 'Error',
        message: 'Error deleting record. Please try again.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Widget _buildRecordCard({
    required String studentName,
    required String studentID,
    required String time,
    required String eventName,
    required String program,
    required String department,
    required String scannedBy,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Event: $eventName', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text('Program: $program', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'Department: $department',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scanned by: $scannedBy',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  'Student ID: $studentID',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);

    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "TODAY'S ATTENDANCE LOG",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('attendanceLog')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docsRaw = snapshot.data?.docs ?? [];

                          // Filter today's records
                          final docs = docsRaw.where((d) {
                            final m = (d.data() as Map<String, dynamic>);
                            final date = (m['date'] ?? '').toString();
                            return date == todayDate;
                          }).toList();

                          // Sort by time DESC (stored as hh:mm:ssa string)
                          docs.sort((a, b) {
                            final am = (a.data() as Map<String, dynamic>);
                            final bm = (b.data() as Map<String, dynamic>);
                            final at = (am['time'] ?? '').toString();
                            final bt = (bm['time'] ?? '').toString();
                            return bt.compareTo(at);
                          });

                          if (docs.isEmpty) {
                            return const Center(
                              child: Text('No attendance records today.'),
                            );
                          }

                          // Preload missing names if some records don't store studentName
                          final missingIds = docs
                              .map((d) {
                                final m = (d.data() as Map<String, dynamic>);
                                return (m['studentID'] ?? '').toString();
                              })
                              .where((id) => id.isNotEmpty)
                              .where(
                                (id) => !_studentNamesCache.containsKey(id),
                              )
                              .toSet()
                              .toList();

                          if (missingIds.isNotEmpty) {
                            _preloadStudentNames(missingIds);
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (ctx, i) {
                              final doc = docs[i];
                              final docId = doc.id;
                              final m = (doc.data() as Map<String, dynamic>);

                              final studentID = (m['studentID'] ?? '')
                                  .toString();
                              final storedName = (m['studentName'] ?? '')
                                  .toString();
                              final studentName = storedName.isNotEmpty
                                  ? storedName
                                  : (_studentNamesCache[studentID] ??
                                        'Loading...');

                              final time = (m['time'] ?? '').toString();
                              final eventName = (m['eventName'] ?? '')
                                  .toString();

                              final program = (m['program'] ?? '').toString();
                              final department = (m['department'] ?? '')
                                  .toString();

                              final scannedBy = (m['operator'] ?? '')
                                  .toString();

                              return _buildRecordCard(
                                studentName: studentName,
                                studentID: studentID,
                                time: time.isEmpty ? '--:--' : time,
                                eventName: eventName.isEmpty ? '—' : eventName,
                                program: program.isEmpty ? '—' : program,
                                department: department.isEmpty
                                    ? '—'
                                    : department,
                                scannedBy: scannedBy.isEmpty ? '—' : scannedBy,
                                onDelete: () => _deleteAttendanceRecord(
                                  docId: docId,
                                  studentID: studentID,
                                  eventName: eventName,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
