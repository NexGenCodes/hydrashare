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
              onTap: () {
                // TODO: Implement restart
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title.toUpperCase(),
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
