import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/daemon_service.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  final DaemonService daemonService;
  const SettingsScreen({super.key, required this.daemonService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _maxFileSizeGB = 0; // 0 = Unlimited
  double _autoAcceptLimitMB = 10; // Default 10MB

  @override
  void initState() {
    super.initState();
    // TODO: Load current max file size from storage if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Preference'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return ListTile(
                leading: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: Colors.deepPurpleAccent,
                ),
                title: const Text('Theme Mode'),
                subtitle: Text(
                  themeProvider.themeMode == ThemeMode.system
                      ? 'System Default'
                      : themeProvider.themeMode == ThemeMode.dark
                      ? 'Dark'
                      : 'Light',
                ),
                trailing: Switch(
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (value) => themeProvider.toggleTheme(),
                  activeThumbColor: Colors.deepPurpleAccent,
                ),
              );
            },
          ),
          const Divider(height: 40, color: Colors.white10),
          _buildSectionHeader('Transfers'),
          ListTile(
            leading: const Icon(Icons.speed, color: Colors.blueAccent),
            title: const Text('Max Incoming File Size'),
            subtitle: Text(
              _maxFileSizeGB == 0
                  ? 'Unlimited'
                  : '${_maxFileSizeGB.toInt()} GB',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Slider(
              value: _maxFileSizeGB,
              min: 0,
              max: 100,
              divisions: 20,
              label: _maxFileSizeGB == 0
                  ? 'Unlimited'
                  : '${_maxFileSizeGB.toInt()} GB',
              activeColor: Colors.deepPurpleAccent,
              onChanged: (value) {
                setState(() {
                  _maxFileSizeGB = value;
                });
                // Convert GB to bytes and send to daemon
                final bytes = (value * 1024 * 1024 * 1024).toInt();
                widget.daemonService.setMaxFileSize(bytes);
              },
            ),
          ),
          const Divider(height: 40, color: Colors.white10),
          _buildSectionHeader('Automated Governance'),
          ListTile(
            leading: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.amberAccent,
            ),
            title: const Text('Auto-accept Limit'),
            subtitle: Text(
              _autoAcceptLimitMB == 0
                  ? 'Disabled'
                  : '${_autoAcceptLimitMB.toInt()} MB',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Slider(
              value: _autoAcceptLimitMB,
              min: 0,
              max: 500,
              divisions: 10,
              label: _autoAcceptLimitMB == 0
                  ? 'Disabled'
                  : '${_autoAcceptLimitMB.toInt()} MB',
              activeColor: Colors.amberAccent,
              onChanged: (value) {
                setState(() {
                  _autoAcceptLimitMB = value;
                });
                // TODO: Send to daemon
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Files below this size from trusted peers will be accepted automatically.',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ),
          const Divider(height: 40, color: Colors.white10),
          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.grey),
            title: Text('HydraShare'),
            subtitle: Text('v1.0.0 - Advanced Agentic Edition'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.deepPurpleAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
