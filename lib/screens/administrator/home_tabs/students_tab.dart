// lib/screens/operator/home_tabs/students_tab.dart
//
// Students tab (updated):
// - Removed student email + year level (already not present here)
// - Delete asks confirmation FIRST, then asks remarks, then deletes and logs to deleteLog
// - ADD STUDENT now opens a separate widget/screen: AddStudentScreen
// - EDIT STUDENT also opens the same screen (optional but consistent)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.black87),
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
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'Enter remark',
            hintText: 'e.g., Duplicate / Wrong data',
          ),
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
                _snack('Remark cannot be blank!', color: Colors.red);
                return;
              }
              Navigator.of(ctx).pop(r);
            },
            child: const Text('Continue'),
          ),
        ],
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

      _snack('Student deleted.', color: Colors.green);
    } catch (e) {
      _snack('Error deleting: $e', color: Colors.red);
    }
  }

  // ---------- Navigation ----------
  Future<void> _openAddStudent() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddStudentScreen()));

    if (result == true) {
      _snack('Student saved.', color: Colors.green);
    }
  }

  Future<void> _openEditStudent(String docId, Map<String, dynamic> data) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddStudentScreen(editDocId: docId, initialData: data),
      ),
    );

    if (result == true) {
      _snack('Student updated.', color: Colors.green);
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
    return _whitePane(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _studentSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or ID',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _studentSearchController.text.trim().toLowerCase();
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
                  return const Center(child: Text('No students found.'));
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
