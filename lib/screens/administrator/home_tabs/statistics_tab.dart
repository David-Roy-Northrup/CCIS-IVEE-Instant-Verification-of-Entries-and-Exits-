// lib/screens/administrator/home_tabs/statistics_tab.dart

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
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
      []; // {idNumber, studentName, dept, prog}
  List<String> _events = []; // unique events from attendanceLog
  Map<String, Set<String>> _attendedIdsByEvent =
      {}; // eventName -> {studentIDs}
  Map<String, Set<String>> _eventsByStudent = {}; // studentID -> {eventNames}

  // Auto refresh
  StreamSubscription? _studentsSub;
  StreamSubscription? _attendanceSub;
  Timer? _reloadDebounce;
  bool _preloadInFlight = false;

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
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _studentsSub?.cancel();
    _attendanceSub?.cancel();

    _studentsSub = FirebaseFirestore.instance
        .collection('students')
        .snapshots()
        .listen((_) => _scheduleReload());

    _attendanceSub = FirebaseFirestore.instance
        .collection('attendanceLog')
        .snapshots()
        .listen((_) => _scheduleReload());
  }

  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      _preloadStatistics();
    });
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _studentsSub?.cancel();
    _attendanceSub?.cancel();
    super.dispose();
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

  // -------------------- PRELOAD (automatic) --------------------
  Future<void> _preloadStatistics() async {
    if (!mounted) return;
    if (_preloadInFlight) return;
    _preloadInFlight = true;

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
    } finally {
      _preloadInFlight = false;
    }
  }

  // -------------------- Excel helpers (MATCH TEMPLATE) --------------------
  xls.CellIndex _ci(int col, int row) =>
      xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);

  void _setText(
    xls.Sheet sheet,
    int col,
    int row,
    String text, {
    xls.CellStyle? style,
  }) {
    final cell = sheet.cell(_ci(col, row));
    cell.value = xls.TextCellValue(text);
    if (style != null) cell.cellStyle = style;
  }

  void _setStyle(xls.Sheet sheet, int col, int row, xls.CellStyle style) {
    final cell = sheet.cell(_ci(col, row));
    cell.cellStyle = style;
  }

  Future<File> _writeWorkbookToTemp(xls.Excel excel) async {
    final safeDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File(
      '${Directory.systemTemp.path}/ivee_records_$safeDate.xlsx',
    );

    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel bytes.');

    await file.writeAsBytes(bytes, flush: true);
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
      recipients: const [],
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
    } catch (e) {
      await _feedback(
        success: false,
        title: 'Clear failed',
        message: 'Error clearing student records.',
        affected: ['Error: $e'],
      );
    }
  }

  Future<void> _clearDeleteRecords() async {
    final confirm = await _confirmDanger(
      title: 'Clear Delete Records',
      message:
          'This will permanently delete ALL deleteLog records.\n\nThis action cannot be undone.',
      confirmText: 'Clear Delete Records',
    );
    if (!confirm) return;

    try {
      final deleted = await _deleteAllInCollection('deleteLog');

      await _feedback(
        success: true,
        title: 'Delete records cleared',
        message: 'All delete records were removed.',
        affected: ['deleteLog: $deleted record(s) removed'],
      );
    } catch (e) {
      await _feedback(
        success: false,
        title: 'Clear failed',
        message: 'Error clearing delete records.',
        affected: ['Error: $e'],
      );
    }
  }

  // -------------------- Build XLSX to match your uploaded template --------------------
  void _buildAttendanceSheet({
    required xls.Sheet sheet,
    required List<String> eventsRaw,
    required List<Map<String, String>> students,
    required Map<String, Set<String>> eventsByStudent,
  }) {
    // Template expects an EVENTS group even if empty.
    final events = eventsRaw.isEmpty ? <String>['(No events)'] : eventsRaw;

    // Columns: A-D fixed, E.. dynamic for events
    const int colDept = 0; // A
    const int colProg = 1; // B
    const int colId = 2; // C
    const int colName = 3; // D
    const int firstEventCol = 4; // E
    final int lastEventCol = firstEventCol + events.length - 1;

    final blue = xls.ExcelColor.fromHexString('FF0B5394');
    final white = xls.ExcelColor.fromHexString('FFFFFFFF');
    final black = xls.ExcelColor.fromHexString('FF000000');

    xls.Border b(xls.BorderStyle s, xls.ExcelColor c) =>
        xls.Border(borderStyle: s, borderColorHex: c);

    final thinWhite = b(xls.BorderStyle.Thin, white);
    final mediumBlack = b(xls.BorderStyle.Medium, black);
    final mediumWhite = b(xls.BorderStyle.Medium, white);

    // Header base (blue, white text)
    xls.CellStyle headerCell({
      xls.Border? left,
      xls.Border? right,
      xls.Border? top,
      xls.Border? bottom,
    }) {
      return xls.CellStyle(
        backgroundColorHex: blue,
        fontColorHex: white,
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        textWrapping: xls.TextWrapping.WrapText,
        leftBorder: left,
        rightBorder: right,
        topBorder: top,
        bottomBorder: bottom,
      );
    }

    // Body styles
    final bodyCenter = xls.CellStyle(
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
    );
    final bodyText = xls.CellStyle(verticalAlign: xls.VerticalAlign.Center);

    xls.CellStyle withTop(xls.CellStyle base) =>
        base.copyWith(topBorderVal: mediumBlack);

    xls.CellStyle withRight(xls.CellStyle base, xls.Border right) =>
        base.copyWith(rightBorderVal: right);

    xls.CellStyle withTopRight(xls.CellStyle base, xls.Border right) =>
        base.copyWith(topBorderVal: mediumBlack, rightBorderVal: right);

    // Column widths (from your uploaded file)
    sheet.setColumnWidth(colDept, 13); // A
    sheet.setColumnWidth(colProg, 7.88); // B
    sheet.setColumnWidth(colId, 10.5); // C
    sheet.setColumnWidth(colName, 34.5); // D
    for (int c = firstEventCol; c <= lastEventCol; c++) {
      sheet.setColumnWidth(c, 13); // E.. end
    }

    // Merges (template)
    sheet.merge(_ci(colDept, 0), _ci(colDept, 1));
    sheet.merge(_ci(colProg, 0), _ci(colProg, 1));
    sheet.merge(_ci(colId, 0), _ci(colId, 1));
    sheet.merge(_ci(colName, 0), _ci(colName, 1));
    sheet.merge(_ci(firstEventCol, 0), _ci(lastEventCol, 0));

    // Row 1 labels
    _setText(sheet, colDept, 0, 'Department');
    _setText(sheet, colProg, 0, 'Program');
    _setText(sheet, colId, 0, 'Student ID');
    _setText(sheet, colName, 0, 'Student Name');
    _setText(sheet, firstEventCol, 0, 'EVENTS');

    // Style header rows (row 0 and 1)
    for (int c = colDept; c <= lastEventCol; c++) {
      // Top border medium black for first header row
      final isLast = c == lastEventCol;
      final isNameCol = c == colName;

      final right = isLast
          ? mediumBlack
          : (isNameCol ? mediumWhite : thinWhite); // divider after name

      // Row 0 (top header)
      _setStyle(
        sheet,
        c,
        0,
        headerCell(
          left: thinWhite,
          right: right,
          top: mediumBlack,
          bottom: thinWhite,
        ),
      );

      // Row 1 (second header row):
      // A-D are merged (blank cells) but still styled; Events row shows event names.
      final bottom = thinWhite;
      final top = thinWhite;

      _setStyle(
        sheet,
        c,
        1,
        headerCell(left: thinWhite, right: right, top: top, bottom: bottom),
      );
    }

    // Row 2 (event names in E..end)
    for (int i = 0; i < events.length; i++) {
      final c = firstEventCol + i;
      _setText(sheet, c, 1, events[i]);
    }

    // Data starts at row index 2 (Excel row 3)
    for (int r = 0; r < students.length; r++) {
      final row = 2 + r;
      final s = students[r];

      final dept = (s['department'] ?? '');
      final prog = (s['program'] ?? '');
      final id = (s['idNumber'] ?? '');
      final name = (s['studentName'] ?? '');

      final set = eventsByStudent[id] ?? <String>{};

      // Top medium black only on first data row (matches your template separator)
      final bool firstDataRow = row == 2;

      _setText(
        sheet,
        colDept,
        row,
        dept,
        style: firstDataRow ? withTop(bodyCenter) : bodyCenter,
      );
      _setText(
        sheet,
        colProg,
        row,
        prog,
        style: firstDataRow ? withTop(bodyCenter) : bodyCenter,
      );
      _setText(
        sheet,
        colId,
        row,
        id,
        style: firstDataRow ? withTop(bodyCenter) : bodyCenter,
      );

      // Name column: right border medium black (divider)
      final nameStyle = firstDataRow
          ? withTopRight(bodyText, mediumBlack)
          : withRight(bodyText, mediumBlack);

      _setText(sheet, colName, row, name, style: nameStyle);

      for (int i = 0; i < events.length; i++) {
        final ev = events[i];
        final c = firstEventCol + i;

        final isLast = c == lastEventCol;
        final mark = set.contains(ev) ? '✔' : '';

        final base = firstDataRow ? withTop(bodyCenter) : bodyCenter;
        final styled = isLast
            ? (firstDataRow
                  ? withTopRight(bodyCenter, mediumBlack)
                  : withRight(bodyCenter, mediumBlack))
            : base;

        _setText(sheet, c, row, mark, style: styled);
      }
    }

    // If there are no students, still draw the divider under headers by setting row 2 top border
    if (students.isEmpty) {
      for (int c = colDept; c <= lastEventCol; c++) {
        final isLast = c == lastEventCol;
        final isName = c == colName;

        final right = isLast || isName
            ? mediumBlack
            : null; // keep divider/right edge
        final style = xls.CellStyle(
          topBorder: mediumBlack,
          rightBorder: right,
          verticalAlign: xls.VerticalAlign.Center,
        );

        _setStyle(sheet, c, 2, style);
      }
    }
  }

  void _buildDeleteLogSheet({
    required xls.Sheet sheet,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> deleteDocs,
  }) {
    final blue = xls.ExcelColor.fromHexString('FF0B5394');
    final white = xls.ExcelColor.fromHexString('FFFFFFFF');
    final black = xls.ExcelColor.fromHexString('FF000000');

    xls.Border b(xls.BorderStyle s, xls.ExcelColor c) =>
        xls.Border(borderStyle: s, borderColorHex: c);

    final thinWhite = b(xls.BorderStyle.Thin, white);
    final mediumBlack = b(xls.BorderStyle.Medium, black);

    // Column widths (from your uploaded file)
    sheet.setColumnWidth(0, 12.5); // Date
    sheet.setColumnWidth(1, 10.5); // Time
    sheet.setColumnWidth(2, 23); // Operator
    sheet.setColumnWidth(3, 12.5); // Type
    sheet.setColumnWidth(4, 14.5); // Student ID
    sheet.setColumnWidth(5, 59.5); // Remarks

    xls.CellStyle headerCell({required bool isFirst, required bool isLast}) {
      return xls.CellStyle(
        backgroundColorHex: blue,
        fontColorHex: white,
        bold: true,
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
        textWrapping: xls.TextWrapping.WrapText,
        topBorder: mediumBlack,
        bottomBorder: mediumBlack,
        leftBorder: isFirst ? mediumBlack : thinWhite,
        rightBorder: isLast ? mediumBlack : thinWhite,
      );
    }

    final bodyBase = xls.CellStyle(
      verticalAlign: xls.VerticalAlign.Center,
      textWrapping: xls.TextWrapping.WrapText,
    );

    xls.CellStyle bodyCell({
      required bool isFirst,
      required bool isLast,
      bool bottom = false,
    }) {
      return bodyBase.copyWith(
        leftBorderVal: isFirst ? mediumBlack : null,
        rightBorderVal: isLast ? mediumBlack : null,
        bottomBorderVal: bottom ? mediumBlack : null,
      );
    }

    // Header
    final headers = [
      'Date',
      'Time',
      'Operator',
      'Type',
      'Student ID',
      'Remarks',
    ];
    for (int c = 0; c < headers.length; c++) {
      _setText(
        sheet,
        c,
        0,
        headers[c],
        style: headerCell(isFirst: c == 0, isLast: c == headers.length - 1),
      );
    }

    // Data rows
    final startRow = 1;
    for (int i = 0; i < deleteDocs.length; i++) {
      final r = startRow + i;
      final m = deleteDocs[i].data();

      final rowVals = <String>[
        (m['date'] ?? '').toString(),
        (m['time'] ?? '').toString(),
        (m['operator'] ?? '').toString(),
        (m['type'] ?? '').toString(),
        (m['studentID'] ?? '').toString(),
        (m['remarks'] ?? '').toString(),
      ];

      final isLastDataRow = (i == deleteDocs.length - 1);

      for (int c = 0; c < rowVals.length; c++) {
        _setText(
          sheet,
          c,
          r,
          rowVals[c],
          style: bodyCell(
            isFirst: c == 0,
            isLast: c == rowVals.length - 1,
            bottom: isLastDataRow,
          ),
        );
      }
    }

    // If no data rows, bottom border should still exist right under header (matches template feel)
    if (deleteDocs.isEmpty) {
      for (int c = 0; c < headers.length; c++) {
        final style = xls.CellStyle(
          leftBorder: c == 0 ? mediumBlack : null,
          rightBorder: c == headers.length - 1 ? mediumBlack : null,
          bottomBorder: mediumBlack,
        );
        _setStyle(sheet, c, 1, style);
      }
    }
  }

  // -------------------- Send Data (Excel with 2 sheets) --------------------
  Future<void> _sendDataAsCsv() async {
    // (kept name so you don't have to refactor callers)
    try {
      if (_loadingStats) {
        await _feedback(
          success: false,
          title: 'Please wait',
          message: 'Statistics are still loading.',
          affected: const ['Action: Email Records'],
        );
        return;
      }

      // Load delete log
      final deleteSnap = await FirebaseFirestore.instance
          .collection('deleteLog')
          .get();
      final deleteDocs = deleteSnap.docs.toList();

      // Build workbook
      final xls.Excel excel = xls.Excel.createExcel();

      // Rename default Sheet1 -> Attendance Log
      if (excel.sheets.keys.contains('Sheet1')) {
        excel.rename('Sheet1', 'Attendance Log');
      }
      excel.setDefaultSheet('Attendance Log');

      final attendanceSheet = excel['Attendance Log'];
      _buildAttendanceSheet(
        sheet: attendanceSheet,
        eventsRaw: List<String>.from(_events),
        students: List<Map<String, String>>.from(_students),
        eventsByStudent: _eventsByStudent,
      );

      final deleteSheet = excel['Delete Log'];
      _buildDeleteLogSheet(sheet: deleteSheet, deleteDocs: deleteDocs);

      final file = await _writeWorkbookToTemp(excel);

      final subject = 'IVEE Records as of $_todayPretty';
      final body =
          'Attached is the IVEE Records Excel file as of $_todayPretty.\n\n'
          'Generated by IVEE Admin.';

      try {
        await _openEmailWithAttachment(
          subject: subject,
          body: body,
          attachmentPath: file.path,
        );
      } on PlatformException catch (e) {
        await _feedback(
          success: false,
          title: 'No email app found',
          message:
              'Excel file was generated, but no email app was found. Install/configure an email client and try again.',
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
        message: 'Error generating/sending Excel file.',
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
          const Text(
            'STATISTICS',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
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
                    onChanged: (v) =>
                        setState(() => _selectedEvent = v ?? _defaultEvent),
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
                  onPressed: _clearDeleteRecords,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text(
                    'Clear Delete Records',
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
