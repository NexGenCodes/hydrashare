import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'services/go_daemon_ffi.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/theme_provider.dart';
import 'services/daemon_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Go Daemon if running on Android
  if (Platform.isAndroid) {
    GoDaemonFfi.init();
    await GoDaemonFfi.startDaemon();
  } else if (Platform.isWindows) {
    _startWindowsDaemon();
  } else if (Platform.isMacOS) {
    _startMacOSDaemon();
  }

  // Initialize storage service
  await StorageService().init();

  // Initialize notification service
  await NotificationService().init();

  // Initialize Theme Provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  // Keep screen awake while app is active
  await WakelockPlus.enable();

  // Connect to daemon
  final daemonService = DaemonService();
  try {
    await daemonService.connect();
    debugPrint('✅ Connected to daemon on startup');
  } catch (e) {
    debugPrint('⚠️ Failed to connect to daemon on startup: $e');
  }

  runApp(
    ChangeNotifierProvider.value(value: themeProvider, child: const MyApp()),
  );
}

Future<void> _startWindowsDaemon() async {
  try {
    // Standard location for daemon artifacts
    final possiblePaths = [
      'daemon/bin/hydra_daemon.exe', // Relative to project root
      '../daemon/bin/hydra_daemon.exe', // Relative to frontend/
      './hydra_daemon.exe', // Same directory as app
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

Future<void> _startMacOSDaemon() async {
  try {
    final possiblePaths = [
      'hydra_daemon', // Current directory
      'daemon/bin/hydra_daemon', // Relative to project root
      '../daemon/bin/hydra_daemon', // Relative to frontend/
      '../hydra_daemon', // Project root if running from frontend/
    ];

    String? foundPath;
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        foundPath = File(path).absolute.path;
        break;
      }
    }

    if (foundPath != null) {
      debugPrint('🚀 Starting Go Daemon on macOS: $foundPath');
      await Process.start(foundPath, [], mode: ProcessStartMode.detached);
    } else {
      debugPrint(
        '⚠️ hydra_daemon not found. Please ensure it is built and in the project root.',
      );
    }
  } catch (e) {
    debugPrint('❌ Failed to start macOS daemon: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'HydraShare',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF100d20),
        cardColor: const Color(0xFF1E1B2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF100d20),
          foregroundColor: Colors.white,
        ),
      ),
      home: HomeScreen(daemonService: DaemonService()),
    );
  }
}
