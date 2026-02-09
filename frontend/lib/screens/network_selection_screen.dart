import 'package:flutter/material.dart';
import 'qr_handshake_screen.dart';
import 'qr_scanner_screen.dart';
import 'manual_pairing_screen.dart';
import '../services/daemon_service.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/action_card.dart';
import '../core/utils/platform_utils.dart';

class NetworkSelectionScreen extends StatefulWidget {
  const NetworkSelectionScreen({super.key});

  @override
  State<NetworkSelectionScreen> createState() => _NetworkSelectionScreenState();
}

class _NetworkSelectionScreenState extends State<NetworkSelectionScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLarge = PlatformUtils.isLargeScreen(context);

    return AdaptiveLayout(
      title: 'Connect to Network',
      scrollController: _scrollController,
      maxWidth: isLarge ? 1200 : 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_tree_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Join or Create Network',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Share files directly with nearby devices.\nSecure, serverless, and lightning fast.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          if (isLarge)
            Row(
              children: [
                Expanded(
                  child: ActionCard(
                    title: 'Host Network',
                    subtitle: 'Generate a PIN/QR code for others to join',
                    icon: Icons.qr_code_2_rounded,
                    isLarge: true,
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
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ActionCard(
                    title: 'Join Network',
                    subtitle: 'Enter a 6-digit PIN to connect',
                    icon: Icons.dialpad_rounded,
                    isLarge: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManualPairingScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                ActionCard(
                  title: 'Host Network',
                  subtitle: 'Show QR code and PIN for others to join',
                  icon: Icons.qr_code_2_rounded,
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
                ActionCard(
                  title: 'Join Network',
                  subtitle: 'Scan QR code or enter 6-digit PIN',
                  icon: Icons.qr_code_scanner_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QrScannerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
