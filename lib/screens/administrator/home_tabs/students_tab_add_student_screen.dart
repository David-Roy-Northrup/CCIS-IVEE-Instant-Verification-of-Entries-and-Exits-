// lib/screens/operator/home_tabs/add_student_screen.dart
//
// Scanner-style Add/Edit Student screen (updated):
// - No SnackBars (uses ActionFeedbackOverlay for errors)
// - Validates Student ID format in Add mode
// - Add mode: uses student ID as Firestore doc ID and prevents duplicates
// - Edit mode: updates name/department/program (ID read-only)
// - Returns a Map result to parent for success feedback + data affected

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/action_feedback.dart';

/// Forces uppercase typing in TextFields.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class AddStudentScreen extends StatefulWidget {
  final String? editDocId; // if not null => edit mode
  final Map<String, dynamic>? initialData;

  const AddStudentScreen({super.key, this.editDocId, this.initialData});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();

  String _department = '';
  String _program = '';

  List<String> _programs = [];
  bool _loadingPrograms = true;

  bool _saving = false;

  bool get _isEdit => widget.editDocId != null;

  @override
  void initState() {
    super.initState();

    // Prefill when editing
    if (_isEdit) {
      final data = widget.initialData ?? {};
      _studentIdController.text = (data['idNumber'] ?? widget.editDocId ?? '')
          .toString();
      _studentNameController.text = (data['studentName'] ?? '').toString();
      _department = (data['department'] ?? '').toString();
      _program = (data['program'] ?? '').toString();
    }

    _fetchPrograms();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
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

  Future<void> _fetchPrograms() async {
    setState(() {
      _loadingPrograms = true;
      _programs = [];
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('programs')
          .get();
      final names = <String>[];
      for (final doc in snap.docs) {
        final n = (doc.data()['name'] ?? '').toString().trim();
        if (n.isNotEmpty) names.add(n);
      }
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _programs = names;
        _loadingPrograms = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _programs = [];
        _loadingPrograms = false;
      });
      await _feedbackError(
        'Load failed',
        'Unable to load programs list.',
        affected: ['Error: $e'],
      );
    }
  }

  bool _isValidStudentId(String id) {
    final regex = RegExp(r'^(\d{4}-\d{4}-\d{1}|\d{6}|\d{7})$');
    return regex.hasMatch(id);
  }

  InputDecoration _pillDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _save() async {
    final id = _studentIdController.text.trim();
    final name = _studentNameController.text.trim().toUpperCase();

    if (!_isEdit) {
      if (!_isValidStudentId(id)) {
        await _feedbackError(
          'Invalid Student ID',
          'Use ####-####-# or ###### / #######.',
          affected: ['Entered: $id'],
        );
        return;
      }
    } else {
      // Edit mode: ID is read-only; still ensure not blank
      if (id.isEmpty) {
        await _feedbackError(
          'Missing Student ID',
          'Student ID is required.',
          affected: const ['Field: Student ID'],
        );
        return;
      }
    }

    if (name.isEmpty) {
      await _feedbackError(
        'Missing student name',
        'Student name is required.',
        affected: const ['Field: Student Name'],
      );
      return;
    }
    if (_department.isEmpty) {
      await _feedbackError(
        'Missing department',
        'Department is required.',
        affected: const ['Field: Department'],
      );
      return;
    }
    if (_program.isEmpty) {
      await _feedbackError(
        'Missing program',
        'Program is required.',
        affected: const ['Field: Program'],
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final studentsRef = FirebaseFirestore.instance.collection('students');

      if (_isEdit) {
        final docId = widget.editDocId!;
        await studentsRef.doc(docId).update({
          'idNumber': id, // keep consistent
          'studentName': name,
          'department': _department,
          'program': _program,
        });

        if (!mounted) return;
        Navigator.of(context).pop({
          'saved': true,
          'mode': 'edit',
          'docId': docId,
          'id': id,
          'name': name,
          'department': _department,
          'program': _program,
        });
        return;
      }

      // Add mode
      final docRef = studentsRef.doc(id);
      final existing = await docRef.get();
      if (existing.exists) {
        await _feedbackError(
          'Duplicate Student ID',
          'A student with this ID already exists.',
          affected: ['Student ID: $id'],
        );
        return;
      }

      await docRef.set({
        'idNumber': id,
        'studentName': name,
        'department': _department,
        'program': _program,
      });

      if (!mounted) return;
      Navigator.of(context).pop({
        'saved': true,
        'mode': 'add',
        'docId': id,
        'id': id,
        'name': name,
        'department': _department,
        'program': _program,
      });
    } catch (e) {
      await _feedbackError(
        'Save failed',
        'Unable to save student record.',
        affected: ['Student ID: $id', 'Error: $e'],
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Text(_isEdit ? 'Edit Student' : 'Add Student'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _fetchPrograms,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Programs',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: _studentIdController,
                    decoration: _pillDecoration(
                      _isEdit
                          ? 'Student ID (locked)'
                          : 'Student ID (####-####-# / ###### / #######)',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isEdit, // lock ID in edit mode
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                    ],
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _studentNameController,
                    decoration: _pillDecoration('Name of Student (LN, FN, MI)'),
                    inputFormatters: [UpperCaseTextFormatter()],
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _department.isEmpty ? null : _department,
                          items: const ['CCIS', 'CSP']
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _department = v ?? ''),
                          decoration: InputDecoration(
                            labelText: 'Department',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _loadingPrograms
                            ? InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Program',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                child: const SizedBox(
                                  height: 18,
                                  child: Text('Loading...'),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _program.isEmpty ? null : _program,
                                items: _programs
                                    .map(
                                      (p) => DropdownMenuItem<String>(
                                        value: p,
                                        child: Text(
                                          p,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _program = v ?? ''),
                                decoration: InputDecoration(
                                  labelText: 'Program',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.always,
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEdit ? 'Save Changes' : 'Add Student'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
