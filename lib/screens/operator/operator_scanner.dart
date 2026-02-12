// lib/screens/operator/operator_scanner.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class OperatorScanner extends StatefulWidget {
  const OperatorScanner({super.key});

  @override
  State<OperatorScanner> createState() => _OperatorScannerState();
}

class _OperatorScannerState extends State<OperatorScanner>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    torchEnabled: false,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.code39],
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentIDController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();

  bool isFlashOn = false;
  String? _studentID = '';
  bool _paused = false;
  bool _isProcessing = false;

  // Event dropdown
  String? _selectedEventId; // null = "No event Selected."

  // Student detail fields
  String _department = '';
  String _program = '';
  List<String> _programs = [];
  bool _loadingPrograms = true;

  Timer? _scanDebounce;

  bool _scannerExpanded = true;

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
      setState(() {});
    });

    _studentIDController.addListener(() {
      final curr = _studentIDController.text.trim();
      _studentID = curr;
      if (curr.isNotEmpty && _scannerExpanded) _collapseScanner();
      setState(() {});
    });

    _idFocusNode.addListener(() {
      if (_idFocusNode.hasFocus && _scannerExpanded) _collapseScanner();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _studentIDController.dispose();
    _idFocusNode.dispose();
    _scanDebounce?.cancel();
    super.dispose();
  }

  // ---------- Helpers ----------

  String _sanitize(String value) => value.trim().replaceAll('*', '');

  bool _isProbablyValidId(String v) {
    final code39Pattern = RegExp(r'^\d{4}-\d{4}-\d{1}$'); // 0000-0000-0
    final sixDigitPattern = RegExp(r'^\d{6}$'); // 000000
    final sevenDigitPattern = RegExp(r'^\d{7}$'); // 0000000
    return code39Pattern.hasMatch(v) ||
        sixDigitPattern.hasMatch(v) ||
        sevenDigitPattern.hasMatch(v);
  }

  bool get _isManualId =>
      _studentID != null && _isProbablyValidId(_studentID!.trim());

  String _safeForId(String input) {
    final s = input.trim();
    if (s.isEmpty) return 'event';
    var cleaned = s.replaceAll(RegExp(r'[^\w]+'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned;
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
      setState(() => _programs = names);
    } catch (_) {
      setState(() => _programs = []);
    } finally {
      setState(() => _loadingPrograms = false);
    }
  }

  Future<void> _fetchStudentName(String id) async {
    if (id.trim().isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(id.trim())
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final name = (data['studentName'] ?? '').toString().toUpperCase();
        final dept = (data['department'] ?? '').toString();
        final prog = (data['program'] ?? '').toString();

        _nameController.text = name;
        setState(() {
          _department = dept;
          _program = prog;
        });
      } else {
        _nameController.clear();
        setState(() {
          _department = '';
          _program = '';
        });
      }
    } catch (_) {
      _nameController.clear();
      setState(() {
        _department = '';
        _program = '';
      });
    }
  }

  // ---------- Scanner flow ----------

  void _onDetect(BarcodeCapture capture) {
    if (_paused) return;

    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;

      if (b.format == BarcodeFormat.code39 ||
          b.format == BarcodeFormat.unknown) {
        final cleaned = _sanitize(raw);
        if (!_isProbablyValidId(cleaned)) continue;

        setState(() {
          _paused = true;
          _studentID = cleaned;
          _studentIDController.text = cleaned;
          _nameController.clear();
          _department = '';
          _program = '';
        });

        _collapseScanner();
        _fetchStudentName(cleaned);

        _scanDebounce?.cancel();
        _scanDebounce = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() {});
        });

        break;
      }
    }
  }

  Future<void> _collapseScanner() async {
    if (!_scannerExpanded) return;
    setState(() => _scannerExpanded = false);
    try {
      await _controller.stop();
    } catch (_) {}
  }

  Future<void> _expandScanner() async {
    if (_scannerExpanded) return;
    setState(() => _scannerExpanded = true);
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _clearFields({bool keepPaused = false}) {
    setState(() {
      _paused = keepPaused ? _paused : false;
      _studentID = '';
      _studentIDController.clear();
      _nameController.clear();
      _department = '';
      _program = '';
    });

    _expandScanner();
  }

  // ---------- Confirm ----------

  Future<void> _confirmAttendance() async {
    if (_selectedEventId == null) {
      await _showAlert(
        title: 'No Event Selected',
        message: 'Please select an event before scanning.',
        success: false,
      );
      return;
    }

    if (_studentID == null ||
        _studentID!.isEmpty ||
        _nameController.text.isEmpty) {
      await _showAlert(
        title: 'Missing Information',
        message: 'Please ensure Student ID and Name are filled.',
        success: false,
      );
      return;
    }

    if (_department.isEmpty || _program.isEmpty) {
      await _showAlert(
        title: 'Missing Student Details',
        message: 'Please select Department and Program before confirming.',
        success: false,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Ensure selected event still exists and is enabled.
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .get();

      if (!eventDoc.exists ||
          ((eventDoc.data()?['isEnabled'] ?? false) != true)) {
        // Event no longer available → reset to default
        setState(() {
          _selectedEventId = null;
        });

        _clearFields();

        await _showAlert(
          title: 'Event Not Available',
          message:
              'The selected event is no longer available. Please select another event.',
          success: false,
        );
        return;
      }

      final firestore = FirebaseFirestore.instance;

      final idNumber = _studentID!.trim();
      final studentName = _nameController.text.trim().toUpperCase();

      // Upsert student
      final studentsDocRef = firestore.collection('students').doc(idNumber);
      final studentSnap = await studentsDocRef.get();

      final studentData = {
        'idNumber': idNumber,
        'studentName': studentName,
        'department': _department,
        'program': _program,
      };

      if (!studentSnap.exists) {
        await studentsDocRef.set(studentData);
      } else {
        await studentsDocRef.update(studentData);
      }

      // Build event display name from doc (in case label/name changed)
      final eventName = (eventDoc.data()?['eventName'] ?? '').toString();
      final label = (eventDoc.data()?['label'] ?? '').toString();
      final eventDisplay = label.isNotEmpty ? '$eventName - $label' : eventName;

      // Prevent re-scan for same event (per day)
      final now = DateTime.now();
      final dateForId = DateFormat('MM_dd_yyyy').format(now);
      final safeEvent = _safeForId(eventDisplay);
      final attendanceId = '${idNumber}_${safeEvent}_$dateForId';

      final attendanceRef = firestore.collection('attendanceLog');
      final existingAttendance = await attendanceRef.doc(attendanceId).get();
      if (existingAttendance.exists) {
        await _showAlert(
          title: 'Already Recorded',
          message: 'This student has already been recorded for this event.',
          success: false,
          onClose: () => _clearFields(),
        );
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final operatorEmail =
          FirebaseAuth.instance.currentUser?.email ?? 'unknown@cjc.edu.ph';

      final storedDate = DateFormat('MM/dd/yyyy').format(now);
      final storedTime = DateFormat('hh:mm:ssa').format(now);

      await attendanceRef.doc(attendanceId).set({
        'operator': operatorEmail,
        'eventName': eventDisplay,
        'eventId': _selectedEventId,
        'studentID': idNumber,
        'date': storedDate,
        'time': storedTime,
        'studentName': studentName,
        'department': _department,
        'program': _program,
      });

      _clearFields();

      await _showAlert(
        title: 'Success',
        message: 'Attendance recorded successfully.',
        success: true,
      );
    } catch (e) {
      await _showAlert(
        title: 'Error',
        message:
            'Please restart app. If issues continue, contact an Administrator.\n\nDetails: ${e.toString()}',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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

  // ---------- UI pieces ----------

  Widget _buildAnimatedScanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = math.min(constraints.maxWidth, 420.0);
        final boxWidth = maxW;
        const boxHeight = 220.0;
        final cutoutWidth = boxWidth * 0.85;
        final cutoutHeight = boxHeight * 0.40;

        final scanWindow = Rect.fromCenter(
          center: Offset(boxWidth / 2, boxHeight / 2),
          width: cutoutWidth,
          height: cutoutHeight,
        );

        return AnimatedContainer(
          width: boxWidth,
          height: _scannerExpanded ? boxHeight : 0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                AnimatedSlide(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  offset: _scannerExpanded
                      ? Offset.zero
                      : const Offset(0, -0.08),
                  child: AnimatedOpacity(
                    opacity: _scannerExpanded ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      scanWindow: scanWindow,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ScannerOverlayPainter(scanWindow),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: FloatingActionButton(
                    heroTag: 'flashBtn',
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() => isFlashOn = !isFlashOn);
                    },
                    child: Icon(
                      Icons.flash_on,
                      color: isFlashOn ? Colors.yellow : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [UpperCaseTextFormatter()],
      onChanged: (_) => setState(() {}),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: enabled ? Colors.black38 : Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: enabled ? Colors.black38 : Colors.grey),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildEditableIDField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      focusNode: _idFocusNode,
      enabled: !_isProcessing,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        UpperCaseTextFormatter(),
      ],
      onFieldSubmitted: (val) {
        final cleaned = _sanitize(val);
        _studentID = cleaned;
        if (cleaned.isNotEmpty) _fetchStudentName(cleaned);
        _collapseScanner();
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        suffixIcon: IconButton(
          tooltip: 'Use Camera',
          icon: Icon(
            _scannerExpanded ? Icons.north : Icons.camera_alt_outlined,
          ),
          onPressed: () {
            if (_scannerExpanded) {
              _collapseScanner();
              FocusScope.of(context).requestFocus(_idFocusNode);
            } else {
              _clearFields();
            }
          },
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
      onChanged: enabled
          ? (v) {
              setState(() => _department = v ?? '');
            }
          : null,
      decoration: InputDecoration(
        labelText: 'Department',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: enabled ? Colors.black38 : Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: enabled ? Colors.black38 : Colors.grey),
        ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
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
      onChanged: enabled
          ? (v) {
              setState(() => _program = v ?? '');
            }
          : null,
      decoration: InputDecoration(
        labelText: 'Program',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: enabled ? Colors.black38 : Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: enabled ? Colors.black38 : Colors.grey),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildEventDropdown(List<QueryDocumentSnapshot> activeEvents) {
    // Keep selection consistent if event removed/inactivated
    final exists =
        _selectedEventId != null &&
        activeEvents.any((d) => d.id == _selectedEventId);

    if (!exists && _selectedEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedEventId = null;
        });
      });
    }

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text("No event Selected."),
      ),
      ...activeEvents.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['eventName'] ?? '').toString();
        final label = (data['label'] ?? '').toString();
        final display = label.isNotEmpty ? '$name - $label' : name;
        return DropdownMenuItem<String?>(value: doc.id, child: Text(display));
      }),
    ];

    return DropdownButtonFormField<String?>(
      initialValue: _selectedEventId,
      items: items,
      onChanged: _isProcessing
          ? null
          : (val) {
              setState(() {
                _selectedEventId = val;
                if (val == null) {
                } else {
                  final match = activeEvents.firstWhere((d) => d.id == val);
                  final data = match.data() as Map<String, dynamic>;
                  (data['eventName'] ?? '').toString();
                  (data['label'] ?? '').toString();
                }
              });
            },
      decoration: InputDecoration(
        labelText: 'Event',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);
    const greenBtn = Color(0xFF8CC63F);
    const grayBtn = Color(0xFF777777);

    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .where('isEnabled', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            final activeEvents =
                snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];

            // If there are no active events, stop scanner and show "No Current Events."
            final noEvents =
                snapshot.connectionState == ConnectionState.active &&
                activeEvents.isEmpty;

            if (noEvents) {
              // Make sure scanner is stopped without spamming calls
              if (_scannerExpanded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _collapseScanner();
                });
              }

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "ATTENDANCE SCANNER",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "No Current Events.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            // If events exist, ensure scanner can run as normal
            final bool confirmEnabled =
                (_selectedEventId != null &&
                _studentID != null &&
                _studentID!.isNotEmpty &&
                _nameController.text.trim().isNotEmpty &&
                _department.isNotEmpty &&
                _program.isNotEmpty &&
                !_isProcessing);

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 3,
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
                            "ATTENDANCE SCANNER",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Event dropdown (replaces the old event title)
                          _buildEventDropdown(activeEvents),

                          const SizedBox(height: 12),

                          _buildAnimatedScanner(),
                          const SizedBox(height: 10),

                          _buildEditableIDField(
                            'Student ID Number',
                            _studentIDController,
                          ),
                          const SizedBox(height: 8),

                          _buildEditableField(
                            'Name of Student (LN, FN, MI)',
                            _nameController,
                            enabled: _isManualId && !_isProcessing,
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildDepartmentDropdown(
                                  enabled: _isManualId && !_isProcessing,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: _buildProgramDropdown(
                                  enabled: _isManualId && !_isProcessing,
                                ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _clearFields(),
                                  child: const Text(
                                    'RESTART',
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
                                    backgroundColor: confirmEnabled
                                        ? greenBtn
                                        : Colors.grey,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: confirmEnabled
                                      ? _confirmAttendance
                                      : null,
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
                                          'CONFIRM',
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect cutout;
  _ScannerOverlayPainter(this.cutout);

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black54;
    final bg = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(RRect.fromRectXY(cutout, 12, 12));
    final diff = Path.combine(PathOperation.difference, bg, hole);
    canvas.drawPath(diff, overlayPaint);

    final border = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectXY(cutout, 12, 12), border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
