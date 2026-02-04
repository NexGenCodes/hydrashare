import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/daemon_service.dart';
import '../widgets/adaptive_layout.dart';
import '../core/utils/platform_utils.dart';

class QrHandshakeScreen extends StatefulWidget {
  final DaemonService daemonService;

  const QrHandshakeScreen({super.key, required this.daemonService});

  @override
  State<QrHandshakeScreen> createState() => _QrHandshakeScreenState();
}

class _QrHandshakeScreenState extends State<QrHandshakeScreen> {
  final ScrollController _scrollController = ScrollController();

  String? _pin;
  String? _qrData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePairing();
  }

  Future<void> _initializePairing() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Ensure daemon is connected if not already
      if (!widget.daemonService.isConnected) {
        await widget.daemonService.connect();
      }

      // Generate pairing code and get host IP
      final result = await widget.daemonService.generateCodeWithIP();

      if (mounted) {
        setState(() {
          _pin = result['pin'];
          // Expected format for guest scanner: "ip|key"
          _qrData = "${result['ip']}|${result['key']}";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing pairing: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = PlatformUtils.isMediumScreen(context);

    return AdaptiveLayout(
      title: 'Host Connection',
      scrollController: _scrollController,
      maxWidth: isDesktop ? 1000 : 500,
      child: _buildBody(theme, isDesktop),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDesktop) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Generating secure codes...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 24),
            Text(
              'Failed to generate pairing codes',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializePairing,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final pin = _pin ?? '000000';
    final qrData = _qrData ?? '';

    return isDesktop
        ? _buildDesktopLayout(theme, pin, qrData)
        : _buildMobileLayout(theme, pin, qrData);
  }

  Widget _buildDesktopLayout(ThemeData theme, String pin, String qrData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(theme, true),
              const SizedBox(height: 48),
              _buildPinSection(theme, pin, true),
            ],
          ),
        ),
        const SizedBox(width: 64),
        Expanded(flex: 1, child: _buildQrSection(theme, qrData, true)),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, String pin, String qrData) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHeader(theme, false),
        const SizedBox(height: 40),
        _buildQrSection(theme, qrData, false),
        const SizedBox(height: 40),
        _buildPinSection(theme, pin, false),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Ready to Pair',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Other devices can join your network by scanning the QR code or entering the PIN below.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQrSection(ThemeData theme, String qrData, bool isDesktop) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 280.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Colors.black87,
              ),
            ),
            if (!isDesktop) ...[
              const SizedBox(height: 16),
              Text(
                'Scan to connect',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinSection(ThemeData theme, String pin, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'MANUAL PIN',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          child: Text(
            pin,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
              color: theme.colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
