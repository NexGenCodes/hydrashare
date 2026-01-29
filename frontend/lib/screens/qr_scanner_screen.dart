import 'dart:async';
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
  String? _expectedHostIp; // Track the IP we're trying to connect to
  late StreamSubscription _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _connectDaemon();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _connectionSubscription = _daemonService.responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED' &&
          _isConnecting &&
          _expectedHostIp != null) {
        final connectedIp = response['ip'] as String?;
        // Only navigate if we connected to the expected host (not localhost)
        if (connectedIp == _expectedHostIp && connectedIp != '127.0.0.1') {
          debugPrint(
            '✅ Guest connected to host $connectedIp, navigating to HomeScreen',
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(daemonService: _daemonService),
              ),
            );
          }
        }
      }
    });
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
    _connectionSubscription.cancel();
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
      // Parse the code: format is "ip|key"
      final parts = code.split('|');
      final targetIp = parts[0];
      debugPrint('Scanned IP: $targetIp');

      // Ignore localhost connections
      if (targetIp == '127.0.0.1') {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isScanning = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot connect to localhost. Please scan a different device.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Set the expected host IP before connecting
      setState(() {
        _expectedHostIp = targetIp;
      });

      // Send to daemon - this will complete after successful handshake
      await _daemonService.connectToPeer(targetIp);

      if (mounted) {
        // Connection successful, navigate to HomeScreen
        debugPrint(
          '✅ Guest successfully connected to $targetIp, navigating to HomeScreen',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(daemonService: _daemonService),
          ),
        );
      }
    } catch (e) {
      // TODO: If connection fails, check for another way to connect (e.g., relay, bluetooth, etc.)
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
