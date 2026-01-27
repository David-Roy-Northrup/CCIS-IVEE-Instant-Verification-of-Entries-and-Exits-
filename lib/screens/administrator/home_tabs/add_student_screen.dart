// lib/screens/operator/home_tabs/add_student_screen.dart
//
// "Separate file exactly the same with the scanner but for adding students"
// - Style aligned to scanner (rounded fields, center text, navy background)
// - Fields match scanner AFTER requirements:
//   * Student ID
//   * Student Name
//   * Department (dropdown)
//   * Program (dropdown from Firestore 'programs' collection)
// - Removed: student email, year level
// - Saves into Firestore: students/<idNumber>
//   { idNumber, studentName, department, program }
// - If student already exists, it will update (admin-friendly).
//
// Usage (from StudentsTab "Add Student" button):
// Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudentScreen()));

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _studentIDController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final FocusNode _idFocusNode = FocusNode();

  String _department = '';
  String _program = '';
  List<String> _programs = [];
  bool _loadingPrograms = true;
  bool _isProcessing = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchPrograms();

    _nameController.addListener(() {
      final upper = _nameController.text.toUpperCase();
      if (_nameController.text != upper) {
        _nameController.value = _nameController.value.copyWith(
          text: upper,
          selection: _nameController.selection,
          composing: TextRange.empty,
        );
      }
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() {});
      });
    });

    _studentIDController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _studentIDController.dispose();
    _nameController.dispose();
    _idFocusNode.dispose();
    super.dispose();
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
        final n = (doc.data()['name'] ?? '').toString();
        if (n.isNotEmpty) names.add(n);
      }
      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() => _programs = names);
    } catch (_) {
      setState(() => _programs = []);
    } finally {
      setState(() => _loadingPrograms = false);
    }
  }

  void _clearFields() {
    setState(() {
      _studentIDController.clear();
      _nameController.clear();
      _department = '';
      _program = '';
    });
    FocusScope.of(context).requestFocus(_idFocusNode);
  }

  bool _isProbablyValidId(String v) {
    final code39Pattern = RegExp(r'^\d{4}-\d{4}-\d{1}$'); // 0000-0000-0
    final sixDigitPattern = RegExp(r'^\d{6}$'); // 000000
    final sevenDigitPattern = RegExp(r'^\d{7}$'); // 0000000
    return code39Pattern.hasMatch(v) ||
        sixDigitPattern.hasMatch(v) ||
        sevenDigitPattern.hasMatch(v);
  }

  Future<void> _showAlert({
    required String title,
    required String message,
    required bool success,
    VoidCallback? onClose,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: success ? Colors.green : Colors.red,
            ),
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
            onPressed: () {
              Navigator.of(context).pop();
              if (onClose != null) onClose();
            },
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStudent() async {
    final id = _studentIDController.text.trim();
    final name = _nameController.text.trim().toUpperCase();

    if (id.isEmpty || !_isProbablyValidId(id)) {
      await _showAlert(
        title: 'Invalid Student ID',
        message: 'Use ####-####-# or ###### or #######.',
        success: false,
      );
      return;
    }

    if (name.isEmpty) {
      await _showAlert(
        title: 'Missing Name',
        message: 'Please enter the student name.',
        success: false,
      );
      return;
    }

    if (_department.isEmpty || _program.isEmpty) {
      await _showAlert(
        title: 'Missing Details',
        message: 'Please select Department and Program.',
        success: false,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('students').doc(id);

      await docRef.set({
        'idNumber': id,
        'studentName': name,
        'department': _department,
        'program': _program,
      }, SetOptions(merge: true));

      await _showAlert(
        title: 'Saved',
        message: 'Student record saved successfully.',
        success: true,
        onClose: _clearFields,
      );
    } catch (e) {
      await _showAlert(
        title: 'Error',
        message: 'Failed to save student.\n\nDetails: $e',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: (_) => setState(() {}),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown({bool enabled = true}) {
    return DropdownButtonFormField<String>(
      initialValue: _department.isEmpty ? null : _department,
      items: [
        'CCIS',
        'CSP',
      ].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: enabled ? (v) => setState(() => _department = v ?? '') : null,
      decoration: InputDecoration(
        labelText: 'Department',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildProgramDropdown({bool enabled = true}) {
    if (_loadingPrograms) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Program',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: const SizedBox(height: 18, child: Text('Loading...')),
      );
    }

    final items = _programs
        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: _program.isEmpty ? null : _program,
      items: items,
      onChanged: enabled ? (v) => setState(() => _program = v ?? '') : null,
      decoration: InputDecoration(
        labelText: 'Program',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);
    const greenBtn = Color(0xFF8CC63F);
    const grayBtn = Color(0xFF777777);

    final bool saveEnabled =
        !_isProcessing &&
        _studentIDController.text.trim().isNotEmpty &&
        _isProbablyValidId(_studentIDController.text.trim()) &&
        _nameController.text.trim().isNotEmpty &&
        _department.isNotEmpty &&
        _program.isNotEmpty;

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Add Student', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.only(
              top: 12,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                const Text(
                  "STUDENT RECORD",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildEditableField(
                  'Student ID Number',
                  _studentIDController,
                  enabled: !_isProcessing,
                  focusNode: _idFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                    UpperCaseTextFormatter(),
                  ],
                ),
                const SizedBox(height: 10),
                _buildEditableField(
                  'Name of Student (LN, FN, MI)',
                  _nameController,
                  enabled: !_isProcessing,
                  inputFormatters: [UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDepartmentDropdown(enabled: !_isProcessing),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildProgramDropdown(enabled: !_isProcessing),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: grayBtn,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isProcessing ? null : _clearFields,
                        child: const Text(
                          'RESET',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saveEnabled ? greenBtn : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: saveEnabled ? _saveStudent : null,
                        child: _isProcessing
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'SAVE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
