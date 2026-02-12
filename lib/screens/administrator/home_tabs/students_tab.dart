// lib/screens/operator/home_tabs/students_tab.dart
//
// Students tab (updated):
// - No SnackBars (uses ActionFeedbackOverlay)
// - Delete asks confirmation FIRST, then asks remarks (required), then deletes + logs to deleteLog
// - ADD STUDENT opens AddStudentScreen
// - EDIT STUDENT opens AddStudentScreen in edit mode
// - Shows clear, actionable feedback indicating action + data affected

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../widgets/action_feedback.dart';
import 'students_tab_add_student_screen.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _studentSearchController = TextEditingController();

  String get _todayDate => DateFormat('MM/dd/yyyy').format(DateTime.now());
  String get _currentTime => DateFormat('hh:mm:ssa').format(DateTime.now());

  String get _operatorName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      (FirebaseAuth.instance.currentUser?.email ?? 'Unknown User');

  @override
  void initState() {
    super.initState();
    _studentSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
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

  // ---------- Delete flow ----------
  Future<bool> _confirmDeleteDialog(
    String studentId,
    String studentName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Student Record',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the student record for:\n\n$studentName\n($studentId)\n',
        ),
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

  Future<String?> _askRemarksDialog() async {
    final TextEditingController remarksController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Reason for Deletion',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: remarksController,
            decoration: InputDecoration(
              labelText: 'Enter remark',
              hintText: 'e.g., Duplicate / Wrong data',
              errorText: errorText,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final r = remarksController.text.trim();
                if (r.isEmpty) {
                  setLocal(() => errorText = 'Remark cannot be blank.');
                  return;
                }
                Navigator.of(ctx).pop(r);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStudentDoc(
    String docId,
    String studentId,
    String name,
  ) async {
    // Step 1: confirmation first
    final confirmed = await _confirmDeleteDialog(studentId, name);
    if (!confirmed) return;

    // Step 2: ask remarks
    final remarks = await _askRemarksDialog();
    if (remarks == null || remarks.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(docId)
          .delete();

      await FirebaseFirestore.instance.collection('deleteLog').add({
        'operator': _operatorName,
        'remarks': remarks,
        'studentID': studentId,
        'date': _todayDate,
        'time': _currentTime,
        'type': "Student",
      });

      await _feedbackSuccess(
        'Student deleted',
        'Student record has been removed successfully.',
        affected: [
          'students: 1 record removed',
          'Student ID: $studentId',
          'Name: $name',
          'deleteLog: +1 record',
        ],
      );
    } catch (e) {
      await _feedbackError(
        'Delete failed',
        'Unable to delete student record.',
        affected: ['Student ID: $studentId', 'Name: $name', 'Error: $e'],
      );
    }
  }

  // ---------- Navigation ----------
  Future<void> _openAddStudent() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );

    if (result == null) return;

    if (result['saved'] == true && result['mode'] == 'add') {
      final id = (result['id'] ?? '').toString();
      final name = (result['name'] ?? '').toString();
      final dept = (result['department'] ?? '').toString();
      final prog = (result['program'] ?? '').toString();

      await _feedbackSuccess(
        'Student added',
        'New student record saved successfully.',
        affected: [
          'students: +1 record',
          if (id.isNotEmpty) 'Student ID: $id',
          if (name.isNotEmpty) 'Name: $name',
          if (dept.isNotEmpty) 'Department: $dept',
          if (prog.isNotEmpty) 'Program: $prog',
        ],
      );
    }
  }

  Future<void> _openEditStudent(String docId, Map<String, dynamic> data) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AddStudentScreen(editDocId: docId, initialData: data),
      ),
    );

    if (result == null) return;

    if (result['saved'] == true && result['mode'] == 'edit') {
      final id = (result['id'] ?? '').toString();
      final name = (result['name'] ?? '').toString();
      final dept = (result['department'] ?? '').toString();
      final prog = (result['program'] ?? '').toString();

      await _feedbackSuccess(
        'Student updated',
        'Student record updated successfully.',
        affected: [
          'students/$docId updated',
          if (id.isNotEmpty) 'Student ID: $id',
          if (name.isNotEmpty) 'Name: $name',
          if (dept.isNotEmpty) 'Department: $dept',
          if (prog.isNotEmpty) 'Program: $prog',
        ],
      );
    }
  }

  // ---------- Layout helpers ----------
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

  @override
  Widget build(BuildContext context) {
    final q = _studentSearchController.text.trim().toLowerCase();

    return _whitePane(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _studentSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or ID',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () => _studentSearchController.clear(),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _tinyIconButton(
                icon: Icons.add_circle,
                color: Colors.green,
                tooltip: 'Add Student',
                onPressed: _openAddStudent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .orderBy('studentName')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();

                final filtered = docs.where((d) {
                  final m = (d.data() as Map<String, dynamic>);
                  final name = (m['studentName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final id = (m['idNumber'] ?? d.id).toString().toLowerCase();
                  if (q.isEmpty) return true;
                  return name.contains(q) || id.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      q.isEmpty ? 'No students found.' : 'No results for "$q".',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = (doc.data() as Map<String, dynamic>);

                    final idNumber = (data['idNumber'] ?? doc.id).toString();
                    final studentName = (data['studentName'] ?? 'UNKNOWN')
                        .toString();
                    final department = (data['department'] ?? '—').toString();
                    final program = (data['program'] ?? '—').toString();

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID: $idNumber',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                                _tinyIconButton(
                                  icon: Icons.edit,
                                  color: Colors.blueGrey,
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _openEditStudent(doc.id, data),
                                ),
                                const SizedBox(width: 8),
                                _tinyIconButton(
                                  icon: Icons.delete,
                                  color: Colors.red,
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteStudentDoc(
                                    doc.id,
                                    idNumber,
                                    studentName,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Department: $department'),
                            Text('Program: $program'),
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
