// lib/screens/operator/home_tabs/students_tab_add_student_screen.dart
//
// Add/Edit Student screen (updated):
// - Manual add/edit (existing)
// - Import students from an XLSX file (uploaded inside the app)
//   - Validates required columns + required non-blank fields
//   - Middle name optional; other fields required
//   - Saves studentName in ALL CAPS as: "LASTNAME, FIRSTNAME MIDDLENAME"
//   - Uses student ID as Firestore doc ID; skips duplicates (Firestore + within-file)
//   - Returns summary to parent: total, added, skipped, errors
// - No SnackBars (uses ActionFeedbackOverlay for errors)
// - Add mode: validates Student ID format + prevents duplicates
// - Edit mode: updates name/department/program (ID read-only)
// - Returns a Map result to parent for success feedback + data affected

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/action_feedback.dart';
import '../../../utils/upper_case_text_formatter.dart';

enum _AddMode { manual, xlsx }

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
  bool _importing = false;

  _AddMode _addMode = _AddMode.manual;

  // Picked XLSX
  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  String? _pickedFilePath;

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
      _addMode = _AddMode.manual; // edit is always manual
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

  // -------------------- MANUAL SAVE --------------------
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
          'idNumber': id,
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

  // -------------------- XLSX IMPORT --------------------
  String _normHeader(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[\s\(\)\-_/]+'), '');

  String _cellToString(xls.Data? d) => (d?.value ?? '').toString().trim();

  String _normalizeStudentId(String raw) {
    var s = raw.trim();
    if (RegExp(r'^\d+\.0$').hasMatch(s)) {
      s = s.replaceAll('.0', '');
    }
    return s;
  }

  String _buildStudentNameUpper({
    required String last,
    required String first,
    required String middle,
  }) {
    final ln = last.trim();
    final fn = first.trim();
    final mi = middle.trim();
    final base = '$ln, $fn${mi.isEmpty ? '' : ' $mi'}';
    return base.toUpperCase();
  }

  int? _findCol(List<String> headerNorm, List<String> synonyms) {
    for (int i = 0; i < headerNorm.length; i++) {
      final h = headerNorm[i];
      for (final s in synonyms) {
        if (h == _normHeader(s)) return i;
      }
    }
    return null;
  }

  Future<void> _pickXlsxFile() async {
    if (_importing || _saving) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final f = result.files.first;

      setState(() {
        _pickedFileName = f.name;
        _pickedFileBytes = f.bytes;
        _pickedFilePath = f.path;
      });
    } catch (e) {
      await _feedbackError(
        'Pick failed',
        'Unable to pick XLSX file.',
        affected: ['Error: $e'],
      );
    }
  }

  Future<Uint8List> _getPickedBytesOrThrow() async {
    if (_pickedFileBytes != null) return _pickedFileBytes!;
    final path = _pickedFilePath;
    if (path == null || path.trim().isEmpty) {
      throw Exception('No file bytes/path available.');
    }
    return File(path).readAsBytes();
  }

  Future<void> _importFromXlsx() async {
    if (_importing || _saving) return;
    if (_pickedFileName == null) {
      await _feedbackError(
        'No file selected',
        'Please select an XLSX file to import.',
      );
      return;
    }

    setState(() => _importing = true);

    int totalInList = 0;
    int added = 0;
    int skipped = 0;
    final errors = <String>[];

    try {
      final bytes = await _getPickedBytesOrThrow();
      final workbook = xls.Excel.decodeBytes(bytes);

      if (workbook.tables.isEmpty) {
        await _feedbackError(
          'Invalid file',
          'This XLSX file has no sheets.',
          affected: ['File: $_pickedFileName'],
        );
        return;
      }

      // Preload existing IDs (Firestore)
      final existingSnap = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final existingIds = <String>{};
      for (final d in existingSnap.docs) {
        final m = d.data();
        final id = (m['idNumber'] ?? d.id).toString().trim();
        if (id.isNotEmpty) existingIds.add(id.toLowerCase());
      }

      // Find a sheet that matches the expected headers
      xls.Sheet? matchedSheet;
      List<List<xls.Data?>> matchedRows = const [];

      for (final name in workbook.tables.keys) {
        final sheet = workbook.tables[name];
        if (sheet == null) continue;
        if (sheet.rows.isEmpty) continue;

        final header = sheet.rows.first;
        final headerText = header.map(_cellToString).toList();
        final headerNorm = headerText.map(_normHeader).toList();

        final idCol = _findCol(headerNorm, [
          'Enter your Student ID Number',
          'Student ID',
          'Student ID Number',
          'ID Number',
          'idNumber',
        ]);
        final lastCol = _findCol(headerNorm, ['LAST NAME', 'Last Name']);
        final firstCol = _findCol(headerNorm, ['FIRST NAME', 'First Name']);
        final progCol = _findCol(headerNorm, ['Program']);
        final deptCol = _findCol(headerNorm, ['Department']);

        if (idCol != null &&
            lastCol != null &&
            firstCol != null &&
            progCol != null &&
            deptCol != null) {
          matchedSheet = sheet;
          matchedRows = sheet.rows;
          break;
        }
      }

      if (matchedSheet == null || matchedRows.isEmpty) {
        await _feedbackError(
          'Wrong file format',
          'Your XLSX does not match the expected student template.',
          affected: const [
            'Required columns: Student ID, LAST NAME, FIRST NAME, Program, Department',
            'Middle name is optional.',
          ],
        );
        return;
      }

      final headerText = matchedRows.first.map(_cellToString).toList();
      final headerNorm = headerText.map(_normHeader).toList();

      final idCol = _findCol(headerNorm, [
        'Enter your Student ID Number',
        'Student ID',
        'Student ID Number',
        'ID Number',
        'idNumber',
      ]);
      final lastCol = _findCol(headerNorm, ['LAST NAME', 'Last Name']);
      final firstCol = _findCol(headerNorm, ['FIRST NAME', 'First Name']);
      final middleCol = _findCol(headerNorm, [
        'MIDDLE NAME (if applicable)',
        'Middle Name (if applicable)',
        'MIDDLE NAME',
        'Middle Name',
      ]);
      final progCol = _findCol(headerNorm, ['Program']);
      final deptCol = _findCol(headerNorm, ['Department']);

      if (idCol == null ||
          lastCol == null ||
          firstCol == null ||
          progCol == null ||
          deptCol == null) {
        await _feedbackError(
          'Missing columns',
          'Some required columns are missing.',
          affected: const [
            'Required: Student ID, LAST NAME, FIRST NAME, Program, Department',
            'Middle name is optional.',
          ],
        );
        return;
      }

      // Validate against known programs (if loaded)
      final knownProgramsLower = _programs
          .map((p) => p.trim().toLowerCase())
          .toSet();
      const allowedDepts = {'CCIS', 'CSP'};

      String cell(List<xls.Data?> row, int idx) =>
          idx < row.length ? _cellToString(row[idx]) : '';

      final seenInFile = <String>{};
      final toInsert = <Map<String, String>>[];

      for (int r = 1; r < matchedRows.length; r++) {
        final row = matchedRows[r];

        final rowText = row.map(_cellToString).toList();
        if (rowText.every((c) => c.trim().isEmpty)) continue;

        totalInList++;

        final rawId = _normalizeStudentId(cell(row, idCol));
        final last = cell(row, lastCol);
        final first = cell(row, firstCol);
        final middle = (middleCol == null) ? '' : cell(row, middleCol);
        final prog = cell(row, progCol);
        final dept = cell(row, deptCol);

        if (rawId.isEmpty ||
            last.isEmpty ||
            first.isEmpty ||
            prog.isEmpty ||
            dept.isEmpty) {
          skipped++;
          if (errors.length < 10) {
            errors.add('Row ${r + 1}: Missing required field(s).');
          }
          continue;
        }

        if (!_isValidStudentId(rawId)) {
          skipped++;
          if (errors.length < 10) {
            errors.add('Row ${r + 1}: Invalid Student ID "$rawId".');
          }
          continue;
        }

        final idKey = rawId.toLowerCase();

        if (seenInFile.contains(idKey)) {
          skipped++;
          continue;
        }
        seenInFile.add(idKey);

        if (existingIds.contains(idKey)) {
          skipped++;
          continue;
        }

        final deptUp = dept.trim().toUpperCase();
        final progTrim = prog.trim();

        if (!allowedDepts.contains(deptUp)) {
          skipped++;
          if (errors.length < 10) {
            errors.add('Row ${r + 1}: Unknown Department "$deptUp".');
          }
          continue;
        }

        if (knownProgramsLower.isNotEmpty &&
            !knownProgramsLower.contains(progTrim.toLowerCase())) {
          skipped++;
          if (errors.length < 10) {
            errors.add('Row ${r + 1}: Program not found "$progTrim".');
          }
          continue;
        }

        final nameUpper = _buildStudentNameUpper(
          last: last,
          first: first,
          middle: middle,
        );

        toInsert.add({
          'idNumber': rawId,
          'studentName': nameUpper,
          'program': progTrim.toUpperCase(),
          'department': deptUp,
        });

        existingIds.add(idKey);
      }

      if (toInsert.isEmpty) {
        await _feedbackError(
          'Nothing to import',
          'No valid student rows were found.',
          affected: [
            'File: $_pickedFileName',
            'Total in list: $totalInList',
            'Added: 0',
            'Skipped: $skipped',
            if (errors.isNotEmpty) 'Errors (sample): ${errors.length}',
            ...errors.map((e) => '• $e'),
          ],
        );
        return;
      }

      // Batch insert
      final studentsRef = FirebaseFirestore.instance.collection('students');
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      Future<void> commit() async {
        if (ops == 0) return;
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        ops = 0;
      }

      for (final s in toInsert) {
        final id = s['idNumber']!.trim();
        batch.set(studentsRef.doc(id), {
          'idNumber': id,
          'studentName': s['studentName'] ?? '',
          'department': s['department'] ?? '',
          'program': s['program'] ?? '',
        }, SetOptions(merge: true));

        ops++;
        added++;

        if (ops >= 450) {
          await commit();
        }
      }

      await commit();

      if (!mounted) return;

      // Return to parent, parent shows the summary overlay
      Navigator.of(context).pop({
        'imported': true,
        'mode': 'xlsx',
        'file': _pickedFileName,
        'total': totalInList,
        'added': added,
        'skipped': skipped,
        'errors': errors,
      });
    } catch (e) {
      await _feedbackError(
        'Import failed',
        'Unable to import from XLSX.',
        affected: ['File: $_pickedFileName', 'Error: $e'],
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // -------------------- UI --------------------
  Widget _modeToggle() {
    if (_isEdit) return const SizedBox.shrink();

    final selected = _addMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        color: Colors.grey.shade50,
      ),
      child: Center(
        child: ToggleButtons(
          isSelected: [selected == _AddMode.manual, selected == _AddMode.xlsx],
          onPressed: (_saving || _importing)
              ? null
              : (index) {
                  setState(() {
                    _addMode = index == 0 ? _AddMode.manual : _AddMode.xlsx;
                  });
                },
          borderRadius: BorderRadius.circular(12),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 140),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note),
                  SizedBox(width: 8),
                  Text('Manual'),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file),
                  SizedBox(width: 8),
                  Text('Import XLSX'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualForm() {
    return Column(
      children: [
        TextField(
          controller: _studentIdController,
          decoration: _pillDecoration(
            _isEdit
                ? 'Student ID (locked)'
                : 'Student ID (####-####-# / ###### / #######)',
          ),
          keyboardType: TextInputType.number,
          enabled: !_isEdit && !_saving,
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
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
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
                              child: Text(p, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _program = v ?? ''),
                      decoration: InputDecoration(
                        labelText: 'Program',
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
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A0F3C),
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
    );
  }

  Widget _xlsxImportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import Students from XLSX',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload an XLSX file that matches the student template.\n\n'
          'Required columns: Student ID, LAST NAME, FIRST NAME, Program, Department\n'
          'Middle name is optional. Other fields must not be blank.\n'
          'Duplicates will be skipped.\n'
          'A summary will be shown after import.',
          style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(14),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pickedFileName == null
                      ? 'No file selected'
                      : _pickedFileName!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _pickedFileName == null
                        ? Colors.black54
                        : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _importing ? null : _pickXlsxFile,
                child: const Text('Choose File'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A0F3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: (_importing || _pickedFileName == null)
                ? null
                : _importFromXlsx,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(_importing ? 'Importing…' : 'Import Students'),
          ),
        ),
      ],
    );
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
                  _modeToggle(),
                  const SizedBox(height: 14),
                  if (_isEdit || _addMode == _AddMode.manual) _manualForm(),
                  if (!_isEdit && _addMode == _AddMode.xlsx) _xlsxImportForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
