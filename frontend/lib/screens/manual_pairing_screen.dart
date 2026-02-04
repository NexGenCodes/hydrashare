import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/daemon_service.dart';
import 'qr_scanner_screen.dart';
import 'home_screen.dart';
import '../widgets/adaptive_layout.dart';
import '../core/utils/platform_utils.dart';

class ManualPairingScreen extends StatefulWidget {
  const ManualPairingScreen({super.key});

  @override
  State<ManualPairingScreen> createState() => _ManualPairingScreenState();
}

class _ManualPairingScreenState extends State<ManualPairingScreen> {
  final TextEditingController _pinController = TextEditingController();
  final DaemonService _daemonService = DaemonService();
  bool _isConnecting = false;
  StreamSubscription? _responseSubscription;
  bool _hasCamera = false;
  bool _isCheckingCamera = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkCamera();
  }

  Future<void> _checkCamera() async {
    // Skip camera check on Windows as the current plugin implementation
    // is causing MissingPluginException. MobileScanner is used for QR scanning on mobile.
    if (!kIsWeb && Platform.isWindows) {
      if (mounted) {
        setState(() {
          _hasCamera = false;
          _isCheckingCamera = false;
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (mounted) {
        setState(() {
          _hasCamera = cameras.isNotEmpty;
          _isCheckingCamera = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking cameras: $e');
      if (mounted) {
        setState(() {
          _hasCamera = false;
          _isCheckingCamera = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _responseSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit PIN'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      if (!_daemonService.isConnected) {
        await _daemonService.connect();
      }

      _responseSubscription = _daemonService.responses.listen((response) {
        if (response['type'] == 'PEER_CONNECTED' && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(daemonService: _daemonService),
            ),
            (route) => false,
          );
        }
      });

      await _daemonService.connectWithPIN(pin);
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
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
    final isDesktop = PlatformUtils.isMediumScreen(context);

    return AdaptiveLayout(
      title: 'Enter PIN',
      scrollController: _scrollController,
      maxWidth: 400,
      padding: isDesktop
          ? const EdgeInsets.all(40)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dialpad_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Enter Pairing PIN',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter the 6-digit PIN from the host device to securely connect.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // PIN Input
          TextField(
            controller: _pinController,
            enabled: !_isConnecting,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              fontFamily: 'monospace',
              color: theme.colorScheme.primary,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: theme.colorScheme.primary.withOpacity(0.1),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 24),
            ),
          ),

          const SizedBox(height: 32),

          // Connect Button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: _isConnecting ? null : _handleConnect,
              child: _isConnecting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Connect to Peer'),
            ),
          ),

          const SizedBox(height: 24),

          // Alternative QR scan option - Hidden if no camera is detected
          if (!_isCheckingCamera && _hasCamera)
            Center(
              child: TextButton.icon(
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
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Scan QR Code Instead',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
