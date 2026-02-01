import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/daemon_service.dart';

class RemotePairingScreen extends StatefulWidget {
  const RemotePairingScreen({super.key});

  @override
  State<RemotePairingScreen> createState() => _RemotePairingScreenState();
}

class _RemotePairingScreenState extends State<RemotePairingScreen> {
  final DaemonService _daemonService = DaemonService();
  final TextEditingController _codeController = TextEditingController();
  String? _myGeneratedCode;
  bool _isLoading = false;
  String? _error;

  Future<void> _generateCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final code = await _daemonService.generateSessionCode();
      setState(() {
        _myGeneratedCode = code;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate code: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await _daemonService.joinWithSessionCode(code);
      if (mounted) {
        if (status == 'connected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully connected to remote peer!'),
            ),
          );
          Navigator.pop(context); // Go back to Home (which will auto-refresh)
        } else if (status == 'signaling') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '📡 Direct connection failed. Hub is now relaying MFR signals...',
              ),
            ),
          );
          // Stay on screen or show progress? For now just notify.
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to join: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100d20),
      appBar: AppBar(
        title: const Text('Remote Pairing (LDT)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pair Over the Internet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use session codes to connect with friends who are not on your local network. These codes expire in 24 hours.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),

            // Section 1: Generate
            _buildSection(
              title: 'My Session Code',
              child: Column(
                children: [
                  if (_myGeneratedCode == null)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateCode,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Generate & Share My Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurpleAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _myGeneratedCode!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _myGeneratedCode!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to clipboard'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                label: const Text('Copy'),
                              ),
                              const SizedBox(width: 16),
                              TextButton.icon(
                                onPressed: _generateCode,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                ),
                                label: const Text('Regenerate'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Section 2: Join
            _buildSection(
              title: 'Join a Session',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Paste hydra:// code from a friend',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.link_rounded,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _joinSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Connect to Remote Friend'),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
