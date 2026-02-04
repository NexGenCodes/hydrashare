import 'package:flutter/material.dart';
import '../services/daemon_service.dart';
import 'qr_handshake_screen.dart';
import 'qr_scanner_screen.dart';
import 'manual_pairing_screen.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/action_card.dart';
import '../core/utils/platform_utils.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Join Network',
      scrollController: _scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How do you want to join the network today?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Flex(
            direction: isLandscape ? Axis.horizontal : Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Host Option
              Flexible(
                child: ActionCard(
                  title: 'Host Connection',
                  subtitle: 'Generate a PIN/QR code and manage the network',
                  icon: Icons.hub_rounded,
                  color: theme.colorScheme.primary,
                  isLarge: true,
                  onTap: () {
                    DaemonService().setRole('host');
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
              SizedBox(
                width: isLandscape ? 24 : 0,
                height: isLandscape ? 0 : 24,
              ),
              // Guest Option
              Flexible(
                child: ActionCard(
                  title: 'Guest Connection',
                  subtitle: 'Enter PIN or scan QR code to join',
                  icon: Icons.login_rounded,
                  color: theme.colorScheme.secondary,
                  isLarge: true,
                  onTap: () {
                    DaemonService().setRole('guest');
                    if (PlatformUtils.isDesktop) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManualPairingScreen(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QrScannerScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
