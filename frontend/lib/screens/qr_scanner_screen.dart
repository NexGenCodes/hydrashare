import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/daemon_service.dart';
import '../widgets/qr_scanner_overlay_shape.dart';
import 'home_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final DaemonService _daemonService = DaemonService();
  bool _isScanning = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _connectDaemon();
  }

  Future<void> _connectDaemon() async {
    try {
      await _daemonService.connect();
    } catch (e) {
      debugPrint('Error connecting to daemon: $e');
    }
  }

  @override
  void dispose() {
    _daemonService.disconnect();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isConnecting) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // Found a code
        setState(() {
          _isScanning = false;
          _isConnecting = true;
        });

        _handleCode(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _handleCode(String code) async {
    try {
      // Parse the code if needed, or send directly to daemon
      // Assuming code contains "ip:port" or a token
      debugPrint('Scanned code: $code');

      // Send to daemon
      await _daemonService.connectToPeer(code);

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        // Show success and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to Host!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to HomeScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(daemonService: _daemonService),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isScanning = true; // Resume scanning
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Host QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.deepPurple,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              _isConnecting
                  ? 'Connecting...'
                  : 'Align QR code within the frame',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),

          // Loading Indicator
          if (_isConnecting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
