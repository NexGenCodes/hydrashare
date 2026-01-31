import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/peer.dart';
import '../services/daemon_service.dart';

class RadarScreen extends StatefulWidget {
  final DaemonService daemonService;

  const RadarScreen({super.key, required this.daemonService});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with TickerProviderStateMixin {
  final List<Peer> _discoveredPeers = [];
  bool _isScanning = false;
  PlatformFile? _selectedFile;
  late AnimationController _radarController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Radar sweep animation
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulse animation for concentric circles
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Listen for discovered peers
    widget.daemonService.responses.listen((response) {
      if (response['type'] == 'PEER_DISCOVERED') {
        final peer = Peer.fromJson(response);
        setState(() {
          // Avoid duplicates by stable ID
          if (!_discoveredPeers.any((p) => p.id == peer.id)) {
            _discoveredPeers.add(peer);
          }
        });
      } else if (response['type'] == 'RECEIVE_STARTED') {
        _showIncomingTransfer(response['file_name'], response['file_size']);
      } else if (response['type'] == 'RECEIVE_COMPLETE') {
        _showTransferComplete(response['file_name'], response['path']);
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  void _showIncomingTransfer(String fileName, int fileSize) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📥 Receiving: $fileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
        ),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  void _showTransferComplete(String fileName, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $fileName received! Saved to $path'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleScanning() async {
    if (_isScanning) {
      await widget.daemonService.stopDiscovery();
      setState(() {
        _isScanning = false;
      });
    } else {
      await widget.daemonService.startDiscovery();
      setState(() {
        _isScanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1a0033),
              const Color(0xFF0d001a),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Radar animation background
              if (_isScanning)
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _radarController,
                      _pulseController,
                    ]),
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(300, 300),
                        painter: RadarPainter(
                          sweepAngle: _radarController.value * 2 * pi,
                          pulseValue: _pulseController.value,
                        ),
                      );
                    },
                  ),
                ),

              // Content
              Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.radar,
                              color: Colors.cyanAccent,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Peer Discovery',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // File selection bar
                        _buildFileSelectionBar(),
                        const SizedBox(height: 8),
                        Text(
                          _isScanning
                              ? 'Scanning for nearby devices...'
                              : 'Tap below to start scanning',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ), // Peers list
                  Expanded(
                    child: _discoveredPeers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isScanning)
                                  Icon(
                                    Icons.search,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  _isScanning
                                      ? 'Searching for peers...'
                                      : 'No peers discovered yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _discoveredPeers.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildPeerCard(_discoveredPeers[index]);
                            },
                          ),
                  ),

                  // Scan button
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _toggleScanning,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning
                              ? Colors.red.shade700
                              : Colors.cyanAccent,
                          foregroundColor: _isScanning
                              ? Colors.white
                              : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: _isScanning
                              ? Colors.red.withOpacity(0.5)
                              : Colors.cyanAccent.withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isScanning ? Icons.stop : Icons.play_arrow,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isScanning ? 'Stop Scanning' : 'Start Scanning',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildFileSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            _selectedFile != null ? Icons.file_present : Icons.file_upload,
            color: _selectedFile != null ? Colors.cyanAccent : Colors.white38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedFile?.name ?? 'No file selected',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _selectedFile != null ? Colors.white : Colors.white38,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: _pickFile,
            child: Text(
              _selectedFile != null ? 'Change' : 'Choose File',
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerCard(Peer peer) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.1),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              if (_selectedFile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a file first!')),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🚀 Sending ${_selectedFile!.name} to ${peer.displayName}...',
                  ),
                  backgroundColor: Colors.deepPurple,
                ),
              );

              try {
                await widget.daemonService.sendCommand({
                  'type': 'START_TRANSFER',
                  'file_path': _selectedFile!.path,
                  'dest_ip': peer.ip,
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Device icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.devices,
                      color: Colors.cyanAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Peer info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          peer.displayName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${peer.id.length > 8 ? peer.id.substring(0, 8) : peer.id}',
                          style: TextStyle(fontSize: 14, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),

                  // Connect button
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.cyanAccent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for radar effect
class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseValue;

  RadarPainter({required this.sweepAngle, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw concentric circles (pulsating)
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= 4; i++) {
      final radius = maxRadius * (i / 4);
      final opacity = (1 - pulseValue) * 0.3;
      circlePaint.color = Colors.cyanAccent.withOpacity(opacity);
      canvas.drawCircle(center, radius + (pulseValue * 20), circlePaint);
    }

    // Draw sweep line
    final sweepPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.6),
          Colors.cyanAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    final path = Path();
    path.moveTo(center.dx, center.dy);
    path.arcTo(
      Rect.fromCircle(center: center, radius: maxRadius),
      sweepAngle - 0.5,
      0.5,
      false,
    );
    path.close();
    canvas.drawPath(path, sweepPaint);

    // Draw center dot
    final centerDotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerDotPaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.pulseValue != pulseValue;
  }
}
