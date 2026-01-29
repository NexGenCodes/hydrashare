import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  bool _isGenerating = false;
  late StreamSubscription _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _connectDaemon().then((_) => _generateCode());

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

  Future<void> _connectDaemon() async {
    try {
      await widget.daemonService.connect();
    } catch (e) {
      debugPrint('Error connecting to daemon: $e');
    }
  }

  Future<void> _generateCode() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await widget.daemonService.generateCodeWithIP();
      setState(() {
        _generatedKey = '${result['ip']}|${result['key']}';
        _isGenerating = false;
      });
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
                      'Ask the receiver to scan this code',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // Content area
              Expanded(
                child: Center(
                  child: _isGenerating
                      ? const CircularProgressIndicator()
                      : _generatedKey != null
                      ? _buildQrCodeView()
                      : _buildErrorState(),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodeView() {
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
              data: _generatedKey!,
              version: QrVersions.auto,
              size: 280.0,
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
