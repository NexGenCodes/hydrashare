import 'package:flutter/material.dart';
import 'dart:io';
import 'services/go_daemon_ffi.dart';
import 'screens/onboarding_screen.dart';

void main() {
  // Initialize Go Daemon if running on Android
  if (Platform.isAndroid) {
    GoDaemonFfi.init();
    GoDaemonFfi.startDaemon();
  } else if (Platform.isWindows) {
    _startWindowsDaemon();
  }
  runApp(const MyApp());
}

Future<void> _startWindowsDaemon() async {
  try {
    // Check if daemon is already running by trying to connect to 5050
    // Actually, simple way is to just start it and let it fail to bind if already running
    // Or check process list. For now, we'll try to find the exe.
    // Check common locations for the daemon during development and production
    final possiblePaths = [
      'hydra_daemon.exe', // Current directory
      '../hydra_daemon.exe', // Project root if running from frontend/
      '../../hydra_daemon.exe', // Project root if running from frontend/lib/
    ];

    String? foundPath;
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        foundPath = File(path).absolute.path;
        break;
      }
    }

    if (foundPath != null) {
      debugPrint('🚀 Starting Go Daemon on Windows: $foundPath');
      await Process.start(foundPath, [], mode: ProcessStartMode.detached);
    } else {
      debugPrint(
        '⚠️ hydra_daemon.exe not found. Please ensure it is built and in the project root.',
      );
    }
  } catch (e) {
    debugPrint('❌ Failed to start Windows daemon: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydraShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Assuming default or system font
      ),
      home: const OnboardingScreen(),
    );
  }
}
