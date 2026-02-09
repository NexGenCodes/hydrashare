import 'package:flutter/material.dart';
import '../services/daemon_service.dart';

class WarningBanner extends StatefulWidget {
  const WarningBanner({super.key});

  @override
  State<WarningBanner> createState() => _WarningBannerState();
}

class _WarningBannerState extends State<WarningBanner> {
  Map<String, dynamic>? _currentWarning;

  @override
  void initState() {
    super.initState();
    DaemonService().warnings.listen((warning) {
      if (mounted) {
        setState(() {
          _currentWarning = warning;
        });
        // Auto-clear after 15 seconds
        Future.delayed(const Duration(seconds: 15), () {
          if (mounted && _currentWarning == warning) {
            setState(() {
              _currentWarning = null;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentWarning == null) return const SizedBox.shrink();

    final type = _currentWarning!['type'];
    final bool isCritical = type == 'PROXIMITY_WARNING';

    String message = "⚠️ Warning";
    if (type == 'LOW_SIGNAL_WARNING') {
      message =
          "🛜 Low Signal: ${_currentWarning!['signal']}% - Transfer may be slow or fail.";
    } else if (isCritical) {
      message = "🚨 Distance Alert! Peer is moving away. Transfer at risk.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade900 : Colors.orange.shade900,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCritical ? Icons.error_outline : Icons.wifi_off_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => setState(() => _currentWarning = null),
          ),
        ],
      ),
    );
  }
}
