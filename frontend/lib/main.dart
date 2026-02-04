import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/theme_provider.dart';
import 'services/daemon_service.dart';
import 'screens/onboarding_screen.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
