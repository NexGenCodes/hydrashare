import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/daemon_service.dart';
import '../widgets/adaptive_layout.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

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

      // Generate both QR payload (Smart JSON) and PIN (Manual)
      final results = await Future.wait([
        widget.daemonService.generateQrPayload(),
        widget.daemonService.generateCodeWithIP(),
      ]);

      final qrMap = results[0];
      final pinMap = results[1];

      if (mounted) {
        setState(() {
          _pin = pinMap['pin'];
          // Use JSON payload for Smart QR
          _qrData = jsonEncode(qrMap);
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
    final width = MediaQuery.of(context).size.width;
    // User requested "mobile layout" to avoid wrapping - increasing breakpoint to 900
    final isDesktop = width > 900;

    return AdaptiveLayout(
      title: 'Host Connection',
      scrollController: _scrollController,
      maxWidth: isDesktop ? 1000 : 500,
      child: _buildBody(theme, isDesktop),
    );
  }

  // ... (keeping _buildBody and other methods as is until _buildPinSection)

  Widget _buildPinSection(ThemeData theme, String pin, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'MANUAL PIN',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            pin,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: theme.colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _initializePairing();
              },
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
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Colors.black87,
                  ),
                ),
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
}
