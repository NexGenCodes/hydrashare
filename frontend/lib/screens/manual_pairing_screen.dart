import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/daemon_service.dart';
import 'home_screen.dart';
import 'qr_scanner_screen.dart';
import 'dart:io';

class ManualPairingScreen extends StatefulWidget {
  const ManualPairingScreen({super.key});

  @override
  State<ManualPairingScreen> createState() => _ManualPairingScreenState();
}

class _ManualPairingScreenState extends State<ManualPairingScreen> {
  final DaemonService _daemonService = DaemonService();
  final TextEditingController _pinController = TextEditingController();
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
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final pin = _pinController.text.trim();

    if (pin.isEmpty) {
      _showError('Please enter the 6-digit PIN');
      return;
    }

    if (pin.length != 6) {
      _showError('PIN must be 6 digits');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      // Connect using just the PIN
      await _daemonService.connectWithPIN(pin);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(daemonService: _daemonService),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showError('Connection failed: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Network'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.dialpad,
                  size: 64,
                  color: Colors.deepPurple.shade300,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enter Pairing PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit PIN displayed on the host device',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 40),

                // PIN Input
                TextField(
                  controller: _pinController,
                  enabled: !_isConnecting,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 32,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // Connect Button
                ElevatedButton(
                  onPressed: _isConnecting ? null : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Connect',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const Spacer(),

                // Alternative option for Mobile only
                if (!Platform.isWindows && !Platform.isMacOS)
                  TextButton.icon(
                    onPressed: _isConnecting
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QrScannerScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code Instead'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
