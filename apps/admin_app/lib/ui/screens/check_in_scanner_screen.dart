import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';
import '../../theme/admin_theme.dart';

class CheckInScannerScreen extends StatefulWidget {
  const CheckInScannerScreen({super.key});

  @override
  State<CheckInScannerScreen> createState() => _CheckInScannerScreenState();
}

class _CheckInScannerScreenState extends State<CheckInScannerScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  final _manualCodeController = TextEditingController();
  
  bool _isProcessing = false;
  bool _isManualMode = false;
  
  Map<String, dynamic>? _previewData;
  String? _previewQrPayload;
  String? _previewManualCode;
  
  String? _lastScannedCode;
  DateTime? _lastScannedTime;
  
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _scannerController.start();
        break;
      case AppLifecycleState.inactive:
        _scannerController.stop();
        break;
    }
  }

  Future<void> _processCheckIn({String? qrPayload, String? manualCode}) async {
    if (_isProcessing) return;
    
    // Prevent spamming the same error for the same QR code within 3 seconds
    if (qrPayload != null) {
      final now = DateTime.now();
      if (_lastScannedCode == qrPayload && _lastScannedTime != null) {
        if (now.difference(_lastScannedTime!).inSeconds < 3) {
          return;
        }
      }
      _lastScannedCode = qrPayload;
      _lastScannedTime = now;
    }

    setState(() => _isProcessing = true);

    final provider = context.read<AdminProvider>();
    final result = await provider.checkIn(qrPayload, manualCode, preview: true);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['verified'] == true && result['appointment'] != null) {
      setState(() {
        _previewData = result['appointment'];
        _previewQrPayload = qrPayload;
        _previewManualCode = manualCode;
      });
    } else {
      _showErrorSnackBar(result['error'] ?? 'Check-in failed');
    }
  }

  Future<void> _confirmCheckIn() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final provider = context.read<AdminProvider>();
    final result = await provider.checkIn(_previewQrPayload, _previewManualCode, preview: false);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['verified'] == true) {
      setState(() {
        _previewData = null;
        _previewQrPayload = null;
        _previewManualCode = null;
      });
      _showSuccessSnackBar('CHECK-IN CONFIRMED');
      _manualCodeController.clear();
    } else {
      _showErrorSnackBar(result['error'] ?? 'Confirm failed');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: AdminTheme.errorColor,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: AdminTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('SCANNER', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: AdminTheme.surfaceColor,
        foregroundColor: AdminTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_previewData == null)
            IconButton(
              icon: Icon(_isManualMode ? Icons.qr_code_scanner : Icons.keyboard_alt_outlined),
              color: AdminTheme.textPrimary,
              onPressed: () => setState(() => _isManualMode = !_isManualMode),
              tooltip: 'Toggle Input Mode',
            )
        ],
      ),
      body: _previewData != null 
          ? _buildPreviewOverlay() 
          : (_isManualMode ? _buildManualEntry() : _buildScanner()),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_previewData != null || _isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _processCheckIn(qrPayload: barcodes.first.rawValue);
              }
            },
            errorBuilder: (context, error) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography_rounded, size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        const Text(
                          'CAMERA ERROR',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.errorCode == MobileScannerErrorCode.permissionDenied 
                              ? 'Camera permission denied. Please enable it in Settings.'
                              : 'Failed: ${error.errorDetails?.message ?? error.toString()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: ScannerOverlayPainter(color: Colors.black.withValues(alpha: 0.85)),
          ),
        ),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final scanAreaSize = MediaQuery.of(context).size.width * 0.75;
            final topOffset = (MediaQuery.of(context).size.height - scanAreaSize) / 2.5;
            final currentY = topOffset + (_animationController.value * scanAreaSize);
            return Positioned(
              top: currentY,
              left: (MediaQuery.of(context).size.width - scanAreaSize) / 2,
              right: (MediaQuery.of(context).size.width - scanAreaSize) / 2,
              child: Container(
                height: 1,
                color: AdminTheme.successColor,
              ),
            );
          },
        ),
        if (_isProcessing)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: AdminTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTheme.borderColor),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AdminTheme.primaryColor, strokeWidth: 2)),
                  SizedBox(height: 16),
                  Text('VERIFYING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: AdminTheme.textPrimary)),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black,
                child: const Text(
                  'ALIGN QR CODE WITHIN FRAME',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildManualEntry() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.keyboard_alt_outlined, size: 40, color: AdminTheme.textPrimary),
              const SizedBox(height: 24),
              const Text(
                'MANUAL ENTRY',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the appointment code below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _manualCodeController,
                decoration: const InputDecoration(
                  labelText: 'APPOINTMENT CODE',
                  hintText: 'E.G. 76200',
                ),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary, letterSpacing: 1.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _processCheckIn(manualCode: _manualCodeController.text.trim()),
                  child: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('VERIFY', style: TextStyle(letterSpacing: 2.0)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeWindow(String? start, String? end) {
    if (start == null || end == null) return 'N/A';
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return '${DateFormat.jm().format(s)} - ${DateFormat.jm().format(e)}';
    } catch (_) {
      return 'Invalid Time';
    }
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date);
      return DateFormat('EEEE, MMM d, yyyy').format(d).toUpperCase();
    } catch (_) {
      return date.toUpperCase();
    }
  }

  Widget _buildPreviewOverlay() {
    final appt = _previewData!;
    final timeWindow = _formatTimeWindow(appt['slot_start_time'], appt['slot_end_time']);
    final formattedDate = _formatDate(appt['appointment_date']);
    
    return Container(
      color: AdminTheme.backgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              color: AdminTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimal Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AdminTheme.borderColor)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AdminTheme.successColor, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'VALID APPOINTMENT',
                        style: TextStyle(color: AdminTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2.0),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appt['appointment_code'] ?? 'UNKNOWN CODE',
                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('PATIENT', appt['patient_name'] ?? 'N/A', 'ID: ${appt['patient_id'] ?? 'N/A'}'),
                      const SizedBox(height: 24),
                      _buildDetailRow('DOCTOR', 'Dr. ${appt['doctor_name'] ?? 'N/A'}', appt['service_title'] ?? 'N/A'),
                      const SizedBox(height: 24),
                      _buildDetailRow('SCHEDULE', formattedDate, timeWindow),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('SERVICE FEE', style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                          Text(
                            '₹${appt['consultation_fee']}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 48),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _isProcessing ? null : () {
                                setState(() {
                                  _previewData = null;
                                  _previewQrPayload = null;
                                  _previewManualCode = null;
                                });
                              },
                              child: const Text('CANCEL', style: TextStyle(letterSpacing: 1.5)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _isProcessing ? null : _confirmCheckIn,
                              child: _isProcessing 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('CONFIRM', style: TextStyle(letterSpacing: 2.0)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String subValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(subValue, style: const TextStyle(fontSize: 13, color: AdminTheme.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    _manualCodeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color color;
  ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final scanAreaSize = size.width * 0.75;
    
    // Sharp rectangle
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2.5),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double cornerLength = 24.0;

    // Top Left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLength), borderPaint);
    // Top Right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLength), borderPaint);
    // Bottom Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLength), borderPaint);
    // Bottom Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
