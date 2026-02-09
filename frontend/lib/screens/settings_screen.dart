import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/daemon_service.dart';
import '../widgets/adaptive_layout.dart';

class SettingsScreen extends StatefulWidget {
  final DaemonService daemonService;

  const SettingsScreen({super.key, required this.daemonService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _deviceNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final name = await widget.daemonService.getSetting('device_name');
    if (name.isNotEmpty && mounted) {
      setState(() {
        _deviceNameController.text = name;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: 'Settings',
      scrollController: _scrollController,
      maxWidth: 600,
      child: Column(
        children: [
          _buildSection(theme, 'Appearance', [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme Mode'),
              subtitle: Text(
                themeProvider.themeMode == ThemeMode.light
                    ? 'Light'
                    : themeProvider.themeMode == ThemeMode.dark
                    ? 'Dark'
                    : 'System',
              ),
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
              onTap: () => themeProvider.toggleTheme(),
            ),
          ]),
          const SizedBox(height: 32),
          _buildSection(theme, 'Device', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.laptop_chromebook),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _deviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Device Name',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          widget.daemonService.setDeviceName(value.trim());
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Device name set to $value'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () {
                      final value = _deviceNameController.text.trim();
                      if (value.isNotEmpty) {
                        widget.daemonService.setDeviceName(value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Device name set to $value')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 32),
          _buildSection(theme, 'Network', [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Daemon Status'),
              subtitle: Text(
                DaemonService().isConnected ? 'Connected' : 'Disconnected',
              ),
              trailing: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DaemonService().isConnected
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Restart Daemon'),
              onTap: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Restarting daemon...')),
                );
                await widget.daemonService.disconnect();
                await Future.delayed(const Duration(seconds: 1));
                await widget.daemonService.connect();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Daemon restarted')),
                );
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 32),
          _buildSection(theme, 'About', [
            const ListTile(
              leading: Icon(Icons.code_rounded),
              title: Text('Version'),
              trailing: Text('1.0.0'),
            ),
            const ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Licenses'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
