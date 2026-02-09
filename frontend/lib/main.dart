import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/theme_provider.dart';
import 'services/daemon_service.dart';
import 'screens/onboarding_screen.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  await StorageService().init();

  // Initialize notification service
  await NotificationService().init();

  // Initialize Theme Provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  // Keep screen awake while app is active
  await WakelockPlus.enable();

  // Check and request permissions on Android
  if (Platform.isAndroid) {
    await _requestAndroidPermissions();
  }

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

Future<void> _requestAndroidPermissions() async {
  // Request multiple permissions at once
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.nearbyWifiDevices,
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.notification,
  ].request();

  debugPrint('🔒 Permission Statuses: $statuses');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final daemon = DaemonService();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        debugPrint('⏸️ App backgrounded: Stopping discovery to save battery');
        daemon.stopDiscovery();
        break;
      case AppLifecycleState.resumed:
        debugPrint('▶️ App resumed: Restarting discovery');
        daemon.startDiscovery();
        break;
      case AppLifecycleState.inactive:
        // Do nothing for inactive (e.g. notification shade)
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'HydraShare',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: FutureBuilder<bool>(
        future: _shouldShowOnboarding(DaemonService()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF100d20),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) {
            return const OnboardingScreen();
          } else {
            return HomeScreen(daemonService: DaemonService());
          }
        },
      ),
    );
  }

  Future<bool> _shouldShowOnboarding(DaemonService daemon) async {
    // Wait for connection if not connected
    if (!daemon.isConnected) {
      try {
        await daemon.connect().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    // Give daemon plenty of time to sync peers from DB and discovery
    // Using a more generous delay for startup to avoid onboarding flicker
    await Future.delayed(const Duration(seconds: 1));

    // Also check if we have any paired peers in our local DB as a backup
    // But for now, relying on the daemon's GET_PEERS response
    debugPrint(
      '📊 Sync check: Found ${daemon.currentPeers.length} active peers',
    );

    return daemon.currentPeers.isEmpty;
  }
}
