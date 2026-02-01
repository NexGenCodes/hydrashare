import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../services/daemon_service.dart';
import 'home_screen.dart';

class QrHandshakeScreen extends StatefulWidget {
  final DaemonService daemonService;

  const QrHandshakeScreen({super.key, required this.daemonService});

  @override
  State<QrHandshakeScreen> createState() => _QrHandshakeScreenState();
}

class _QrHandshakeScreenState extends State<QrHandshakeScreen> {
  String? _generatedKey;
  String? _displayPin;
  bool _isGenerating = false;
  bool _isRemoteMode = false;
  late StreamSubscription _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _generateCode();

    // Listen for peer connection
    _connectionSubscription = widget.daemonService.responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED') {
        debugPrint('🤝 Peer connected event received in Handshake Screen');
        if (mounted) {
          _goToHomeScreen();
        }
      }
    });
  }

  void _goToHomeScreen() {
    if (!mounted) return;

    debugPrint('🚀 Navigating to HomeScreen');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(daemonService: widget.daemonService),
      ),
    );
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // Check if daemon is connected
      if (!widget.daemonService.isConnected) {
        debugPrint('⚠️ Daemon not connected, attempting to connect...');
        await widget.daemonService.connect();
      }

      if (_isRemoteMode) {
        final code = await widget.daemonService.generateSessionCode();
        setState(() {
          _generatedKey = code;
          _displayPin = null; // Session codes are long URLs
          _isGenerating = false;
        });
      } else {
        final result = await widget.daemonService.generateCodeWithIP();
        setState(() {
          final ip = result['ip'];
          final key = result['key'];
          final pin = result['pin'];

          // QR Code = IP|KEY (for secure scanning)
          _generatedKey = '$ip|$key';

          // Display PIN = PIN (for manual entry)
          _displayPin = pin;

          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate code: $e'),
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
        title: const Text('Send Files (Host)'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isGenerating ? null : _generateCode,
            tooltip: 'Regenerate Code',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      color: Colors.deepPurple,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready to Transfer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRemoteMode
                          ? 'Share session code via QR'
                          : 'Ask the receiver to scan this code',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Toggle Mode Button
                    OutlinedButton.icon(
                      onPressed: _isGenerating
                          ? null
                          : () {
                              setState(() {
                                _isRemoteMode = !_isRemoteMode;
                                _generateCode();
                              });
                            },
                      icon: Icon(
                        _isRemoteMode
                            ? Icons.language_rounded
                            : Icons.home_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isRemoteMode
                            ? 'Switch to Local Mode'
                            : 'Switch to Remote Mode',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isRemoteMode
                            ? Colors.green
                            : Colors.deepPurple,
                        side: BorderSide(
                          color: _isRemoteMode
                              ? Colors.green
                              : Colors.deepPurple,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content area
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: _isGenerating
                          ? const CircularProgressIndicator()
                          : _generatedKey != null
                          ? _buildQrCodeView()
                          : _buildErrorState(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodeView() {
    // Check if running on likely desktop platform
    final isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux;

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Code (Left)
          Hero(
            tag: 'qr-code-hero',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: _generatedKey!,
                version: QrVersions.auto,
                size: 200.0, // Smaller on desktop to save space
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.deepPurple,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          const SizedBox(width: 48),

          // PIN Display (Right, Larger)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAIRING WITH DESKTOP?',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'ENTER THIS PIN',
                      style: TextStyle(
                        color: Colors.deepPurple.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      _displayPin ?? '??????',
                      style: const TextStyle(
                        fontSize: 64, // HUGE PIN
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                        letterSpacing: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_displayPin != null) {
                          Clipboard.setData(ClipboardData(text: _displayPin!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy PIN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade50,
                        foregroundColor: Colors.deepPurple,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Waiting for connection...',
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    // MOBILE LAYOUT (Original)
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // QR Code container
        Hero(
          tag: 'qr-code-hero',
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: _generatedKey!, // Contains IP|PIN for mobile scanning
              version: QrVersions.auto,
              size: 280.0, // Increased size
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.deepPurple,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // PIN Display (Text)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Column(
            children: [
              Text(
                'PAIRING PIN',
                style: TextStyle(
                  color: Colors.deepPurple.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                _displayPin ?? '??????',
                style: const TextStyle(
                  fontSize: 32, // Smaller size
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        // Wait indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting for connection...',
                style: TextStyle(
                  color: Colors.deepPurple.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // manual escape button
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.daemonService.connectedPeers,
          initialData: widget.daemonService.currentPeers,
          builder: (context, snapshot) {
            final hasPeers = (snapshot.data ?? []).isNotEmpty;
            if (!hasPeers) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _goToHomeScreen,
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go to Home Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          'Could not generate QR code',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _generateCode,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
