import 'package:flutter/material.dart';
import '../services/daemon_service.dart';
import 'qr_handshake_screen.dart';
import 'qr_scanner_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Choose Your Role'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How do you want to use HydraShare today?',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Flex(
                  direction: isLandscape ? Axis.horizontal : Axis.vertical,
                  children: [
                    // Host Option
                    Expanded(
                      child: _RoleCard(
                        title: 'Send Files',
                        subtitle: 'I want to share files with someone nearby',
                        icon: Icons.upload_file_rounded,
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QrHandshakeScreen(
                                daemonService: DaemonService(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: isLandscape ? 24 : 0,
                      height: isLandscape ? 0 : 24,
                    ),
                    // Guest Option
                    Expanded(
                      child: _RoleCard(
                        title: 'Receive Files',
                        subtitle: 'I want to download files from a host',
                        icon: Icons.download_rounded,
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QrScannerScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.05), color.withOpacity(0.15)],
            ),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
