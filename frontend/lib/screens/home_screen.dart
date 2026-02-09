import 'package:flutter/material.dart';
import 'dart:io';
import '../services/daemon_service.dart';
import '../services/permission_service.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'qr_handshake_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/warning_banner.dart';
import '../widgets/scale_button.dart';

class HomeScreen extends StatefulWidget {
  final DaemonService daemonService;

  const HomeScreen({super.key, required this.daemonService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedPeer;
  final ScrollController _sidebarController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await PermissionService().requestAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.daemonService.connectedPeers,
      initialData: widget.daemonService.currentPeers,
      builder: (context, connectedSnapshot) {
        final connectedPeers = connectedSnapshot.data ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.daemonService.discoveredPeers,
          initialData: widget.daemonService.currentDiscoveredPeers,
          builder: (context, discoveredSnapshot) {
            final discoveredPeers = discoveredSnapshot.data ?? [];

            if (Platform.isWindows) {
              return _buildDesktopLayout(
                connectedPeers,
                discoveredPeers,
                theme,
                isDark,
              );
            }

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: _buildMobileLayout(
                connectedPeers,
                discoveredPeers,
                theme,
                isDark,
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you really want to leave HydraShare?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Yes',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildMobileLayout(
    List<Map<String, dynamic>> connectedPeers,
    List<Map<String, dynamic>> discoveredPeers,
    ThemeData theme,
    bool isDark,
  ) {
    return Scaffold(
      appBar: _buildAppBar(theme, isDark),
      body: Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: WarningBanner()),
              if (widget.daemonService.currentRole == 'host')
                SliverToBoxAdapter(child: _buildBroadcastItem(theme, isDark)),
              if (widget.daemonService.currentRole == 'host')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(height: 1, color: theme.dividerColor),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'CONNECTED DEVICES',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              if (connectedPeers.isEmpty && discoveredPeers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 64,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No devices connected',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Devices in your network will appear here.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildContactItem(connectedPeers[index], theme, isDark),
                    childCount: connectedPeers.length,
                  ),
                ),
                if (discoveredPeers.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'NEARBY DEVICES',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildContactItem(
                        discoveredPeers[index],
                        theme,
                        isDark,
                        isDiscovered: true,
                      ),
                      childCount: discoveredPeers.length,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAddDeviceFAB(theme),
    );
  }

  Widget _buildDesktopLayout(
    List<Map<String, dynamic>> connectedPeers,
    List<Map<String, dynamic>> discoveredPeers,
    ThemeData theme,
    bool isDark,
  ) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                right: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Column(
              children: [
                _buildAppBar(theme, isDark, isDesktop: true),
                const WarningBanner(),
                if (widget.daemonService.currentRole == 'host')
                  _buildBroadcastItem(theme, isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(height: 1, color: theme.dividerColor),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        'DEVICES',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      if (connectedPeers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            connectedPeers.length.toString(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _sidebarController,
                    thumbVisibility: false,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: ListView(
                      controller: _sidebarController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        ...connectedPeers.map(
                          (peer) => _buildContactItem(
                            peer,
                            theme,
                            isDark,
                            isSelected:
                                _selectedPeer != null &&
                                (_selectedPeer!['id'] ??
                                        _selectedPeer!['ip']) ==
                                    (peer['id'] ?? peer['ip']),
                            onTap: () => setState(() => _selectedPeer = peer),
                          ),
                        ),
                        if (discoveredPeers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
                            child: Text(
                              'NEARBY',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...discoveredPeers.map(
                            (peer) => _buildContactItem(
                              peer,
                              theme,
                              isDark,
                              isDiscovered: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildSidebarFooter(theme, isDark),
              ],
            ),
          ),
          // Main Chat Area
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: _selectedPeer == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.05,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 80,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Seamless File Sharing',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Select a device to start chatting and sharing files',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ChatScreen(
                      key: ValueKey(
                        _selectedPeer!['id'] ?? _selectedPeer!['ip'],
                      ),
                      peer: _selectedPeer!,
                      daemonService: widget.daemonService,
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildAddDeviceFAB(theme),
    );
  }

  Widget _buildSidebarFooter(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: InkWell(
        onTap: _showAddDeviceModal,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                spreadRadius: 0,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'ADD DEVICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDeviceFAB(ThemeData theme) {
    if (Platform.isWindows) return const SizedBox.shrink();
    return ScaleButton(
      onTap: () {
        _showAddDeviceModal();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              spreadRadius: 0,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Add Device',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDeviceModal() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Add New Device',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            _buildModalOption(
              icon: Icons.qr_code_2_rounded,
              title: 'Create Invitation',
              subtitle: 'Show a QR code for local pairing',
              color: Colors.blueAccent,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        QrHandshakeScreen(daemonService: widget.daemonService),
                  ),
                );
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildModalOption(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Join Network',
              subtitle: 'Scan a friend\'s QR code or enter PIN',
              color: Colors.cyanAccent,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QrScannerScreen(),
                  ),
                );
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme, bool isDark, {bool isDesktop = false}) {
    return AppBar(
      title: Text(
        'HydraShare',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: isDesktop ? 22 : 24,
          color: theme.colorScheme.primary,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SettingsScreen(daemonService: widget.daemonService),
              ),
            );
          },
        ),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return IconButton(
              icon: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              onPressed: () => themeProvider.toggleTheme(),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBroadcastItem(ThemeData theme, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.campaign_rounded, color: theme.colorScheme.primary),
      ),
      title: const Text(
        'Broadcast',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Message everyone in the mesh'),
      selected: _selectedPeer != null && _selectedPeer!['ip'] == 'broadcast',
      onTap: () {
        if (Platform.isWindows) {
          setState(
            () => _selectedPeer = {'ip': 'broadcast', 'name': 'Broadcast'},
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                peer: {'ip': 'broadcast', 'name': 'Broadcast'},
                daemonService: widget.daemonService,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildContactItem(
    Map<String, dynamic> peer,
    ThemeData theme,
    bool isDark, {
    bool isSelected = false,
    bool isDiscovered = false,
    VoidCallback? onTap,
  }) {
    final id = peer['id'] ?? peer['ip'] ?? 'Unknown Device';
    final name = peer['name'] ?? 'Nearby Device';
    final unreadCount = peer['unread_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        selected: isSelected,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Badge(
          label: Text(unreadCount.toString()),
          isLabelVisible: unreadCount > 0,
          backgroundColor: theme.colorScheme.secondary,
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.devices_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          id,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              )
            : widget.daemonService.currentRole == 'host'
            ? _buildAdminMenu(id, peer)
            : null,
        onTap:
            onTap ??
            () {
              if (isDiscovered) {
                _showConnectToDiscoveredDialog(peer);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    peer: peer,
                    daemonService: widget.daemonService,
                  ),
                ),
              );
            },
      ),
    );
  }

  Widget _buildAdminMenu(String id, Map<String, dynamic> peer) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
      onSelected: (value) async {
        if (value == 'kick') {
          await widget.daemonService.disconnectPeer(id);
        } else if (value == 'ban') {
          final confirm = await _showConfirmDialog(
            'Ban Device?',
            'This device will be blocked permanently.',
          );
          if (confirm) await widget.daemonService.banPeer(id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'kick',
          child: ListTile(
            leading: Icon(Icons.exit_to_app_rounded, color: Colors.orange),
            title: Text('Kick Device'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'ban',
          child: ListTile(
            leading: Icon(Icons.block_rounded, color: Colors.red),
            title: Text('Ban Device'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _showConnectToDiscoveredDialog(Map<String, dynamic> peer) async {
    final id = peer['id'] ?? peer['ip'] ?? 'Unknown';
    final name = peer['name'] ?? 'Nearby Device';

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connect to Device?'),
            content: Text(
              'Do you want to connect to $name ($id)?\nYou will need to enter the 6-digit PIN shown on their screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Connect',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      if (!mounted) return;
      // In a unified flow, "connecting" to a discovered peer means
      // entering their PIN. We'll navigate to the ManualPairingScreen
      // and potentially pre-fill the IP if the backend supported it,
      // but JOIN_SESSION usually only needs the PIN for discovery.

      // For now, let's just go to manual pairing screen
      // but in the future we could pass the IP to skip discovery.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const QrScannerScreen(), // Scanners permit PIN entry too
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
