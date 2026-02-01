import 'package:flutter/material.dart';
import 'qr_handshake_screen.dart';
import 'qr_scanner_screen.dart';
import 'manual_pairing_screen.dart';
import 'remote_pairing_screen.dart';
import '../services/daemon_service.dart';

class NetworkSelectionScreen extends StatelessWidget {
  const NetworkSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF100d20),
      appBar: AppBar(
        title: const Text('Connect to Mesh'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_work_rounded,
              size: 80,
              color: Colors.deepPurpleAccent,
            ),
            const SizedBox(height: 32),
            const Text(
              'Join or Create a Network',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'To share files, you must first connect with a friend. No server, just direct connection.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),

            // Option 1: Create (Host QR)
            _buildOption(
              context,
              title: 'Create Network',
              subtitle: 'Show a QR code for your friend to scan',
              icon: Icons.qr_code_2_rounded,
              color: Colors.blueAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        QrHandshakeScreen(daemonService: DaemonService()),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Option 2: Join (Scan QR)
            _buildOption(
              context,
              title: 'Join Network',
              subtitle: 'Scan a friend\'s QR code to connect',
              icon: Icons.qr_code_scanner_rounded,
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QrScannerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Option 3: Manual (PIN)
            _buildOption(
              context,
              title: 'Manual Pairing',
              subtitle: 'Connect using a 6-digit PIN',
              icon: Icons.vpn_key_rounded,
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualPairingScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Option 4: Remote Pairing (LDT)
            _buildOption(
              context,
              title: 'Remote Pairing',
              subtitle: 'Connect with friends over the internet',
              icon: Icons.language_rounded,
              color: Colors.greenAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemotePairingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
