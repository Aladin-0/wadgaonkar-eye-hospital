import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../state/admin_provider.dart';

class CheckInScannerScreen extends StatefulWidget {
  const CheckInScannerScreen({super.key});

  @override
  State<CheckInScannerScreen> createState() => _CheckInScannerScreenState();
}

class _CheckInScannerScreenState extends State<CheckInScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final _manualCodeController = TextEditingController();
  bool _isProcessing = false;
  bool _isManualMode = false;

  Future<void> _processCheckIn({String? qrPayload, String? manualCode}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final provider = context.read<AdminProvider>();
    final result = await provider.checkIn(qrPayload, manualCode);

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (result['verified'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in successful!'), backgroundColor: Colors.green),
      );
      _manualCodeController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Check-in failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Check-In'),
        actions: [
          IconButton(
            icon: Icon(_isManualMode ? Icons.qr_code_scanner : Icons.keyboard),
            onPressed: () => setState(() => _isManualMode = !_isManualMode),
            tooltip: 'Toggle Input Mode',
          )
        ],
      ),
      body: _isManualMode ? _buildManualEntry() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _processCheckIn(qrPayload: barcodes.first.rawValue);
            }
          },
        ),
        if (_isProcessing)
          const Center(
            child: CircularProgressIndicator(),
          ),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Point camera at appointment QR code',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Enter 6-digit Appointment Code', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          TextField(
            controller: _manualCodeController,
            decoration: const InputDecoration(
              labelText: 'Appointment Code',
              border: OutlineInputBorder(),
            ),
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : () => _processCheckIn(manualCode: _manualCodeController.text.trim()),
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Verify & Check In'),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }
}
