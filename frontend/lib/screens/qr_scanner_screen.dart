import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/daemon_service.dart';
import 'manual_pairing_screen.dart';
import 'home_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final DaemonService _daemonService = DaemonService();
  bool _isConnecting = false;
  StreamSubscription? _responseSubscription;

  @override
  void dispose() {
    controller.dispose();
    _responseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleQrCode(BarcodeCapture capture) async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final String? code = capture.barcodes.firstOrNull?.rawValue;
      if (code == null || code.isEmpty) {
        throw Exception('Invalid QR code');
      }

      debugPrint('📸 Scanned QR Code: $code'); // Added logging

      await controller.stop();

      if (!_daemonService.isConnected) {
        await _daemonService.connect();
      }

      _responseSubscription = _daemonService.responses.listen((response) {
        debugPrint('📩 Daemon Response during QR: $response'); // Added logging
        if (response['type'] == 'PEER_CONNECTED' && mounted) {
          debugPrint('✅ Peer Connected! Navigating to Home...');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(daemonService: _daemonService),
            ),
            (route) => false,
          );
        }
      });

      await _daemonService.connectToPeer(code);
    } catch (e) {
      debugPrint('❌ Error handling QR code: $e'); // Added logging
      if (mounted) {
        setState(() => _isConnecting = false);
        await controller.start();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: controller,
            onDetect: _handleQrCode,
            errorBuilder: (context, error) {
              final isWindows =
                  Theme.of(context).platform == TargetPlatform.windows;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isWindows
                          ? Icons.computer_rounded
                          : Icons.error_outline_rounded,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isWindows
                          ? 'Scanning not supported on Windows'
                          : 'Camera Error',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        isWindows
                            ? 'The QR scanner plugin is currently optimized for mobile. Please use Manual PIN entry for this desktop.'
                            : 'Could not access the camera. Please check your permissions.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Scanning frame overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),

          // Instructions overlay
          if (!_isConnecting)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    'Point camera at QR code',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Loading overlay
          if (_isConnecting)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Connecting...',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Manual entry button
          if (!_isConnecting)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManualPairingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.dialpad_rounded),
                    label: const Text('Enter PIN Manually'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
