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
import 'manual_pairing_screen.dart';
import '../widgets/warning_banner.dart';

class HomeScreen extends StatefulWidget {
  final DaemonService daemonService;

  const HomeScreen({super.key, required this.daemonService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedPeer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    await PermissionService().requestAllPermissions();
  }

  // Removed _setupListeners, _updateTransfer, _removeTransfer
  // Transfers now handled in ChatScreen

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.daemonService.connectedPeers,
      initialData: widget.daemonService.currentPeers,
      builder: (context, snapshot) {
        final peers = snapshot.data ?? [];

        // Auto-navigation on total disconnect
        if (peers.isEmpty && widget.daemonService.currentRole != 'none') {
          // Disconnected state handled in-place on Home
        }

        if (Platform.isWindows) {
          return _buildDesktopLayout(peers);
        }

        return WillPopScope(
          onWillPop: _onWillPop,
          child: _buildMobileLayout(peers),
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
                child: const Text('No', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Yes',
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildMobileLayout(List<Map<String, dynamic>> peers) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: WarningBanner()),
              if (widget.daemonService.currentRole == 'host')
                SliverToBoxAdapter(child: _buildBroadcastItem()),
              if (widget.daemonService.currentRole == 'host')
                const SliverToBoxAdapter(child: Divider()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'CONNECTED DEVICES',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              if (peers.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Connecting...')),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildContactItem(peers[index]),
                    childCount: peers.length,
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAddDeviceFAB(),
    );
  }

  Widget _buildDesktopLayout(List<Map<String, dynamic>> peers) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 300,
            color: Colors.grey[100],
            child: Column(
              children: [
                _buildAppBar(isDesktop: true),
                const WarningBanner(),
                if (widget.daemonService.currentRole == 'host')
                  _buildBroadcastItem(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: peers.length,
                    itemBuilder: (context, index) => _buildContactItem(
                      peers[index],
                      isSelected:
                          _selectedPeer != null &&
                          (_selectedPeer!['ip'] ?? _selectedPeer!['dest_ip']) ==
                              (peers[index]['ip'] ?? peers[index]['dest_ip']),
                      onTap: () => setState(() => _selectedPeer = peers[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Chat Area
          Expanded(
            child: _selectedPeer == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select a device to start chatting',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : ChatScreen(
                    key: ValueKey(
                      _selectedPeer!['ip'] ?? _selectedPeer!['dest_ip'],
                    ),
                    peer: _selectedPeer!,
                    daemonService: widget.daemonService,
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildAddDeviceFAB(),
    );
  }

  FloatingActionButton _buildAddDeviceFAB() {
    return FloatingActionButton.extended(
      onPressed: _showAddDeviceModal,
      label: const Text('Add Device'),
      icon: const Icon(Icons.add_rounded),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    );
  }

  void _showAddDeviceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add New Device',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildModalOption(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Create Invitation',
              subtitle: 'Generate QR/PIN for a nearby friend',
              color: Colors.deepPurple,
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
            ),
            const SizedBox(height: 16),
            _buildModalOption(
              icon: Icons.vpn_key_rounded,
              title: 'Join Friendship',
              subtitle: 'Enter PIN or Locator Token from a friend',
              color: Colors.teal,
              onTap: () {
                Navigator.pop(context);
                // On desktop, go direct to PIN. On mobile, scanner.
                if (Platform.isWindows ||
                    Platform.isMacOS ||
                    Platform.isLinux) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManualPairingScreen(),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QrScannerScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
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
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  AppBar _buildAppBar({bool isDesktop = false}) {
    return AppBar(
      title: Text(
        'HydraShare',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isDesktop ? 20 : 24,
          color: Colors.black87,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: isDesktop,
      actions: [
        if (widget.daemonService.currentRole == 'host')
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      QrHandshakeScreen(daemonService: widget.daemonService),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
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
        // Theme Toggler
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return IconButton(
              icon: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () => themeProvider.toggleTheme(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBroadcastItem() {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.campaign_rounded, color: Colors.white),
      ),
      title: const Text(
        'Broadcast Message',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('All guests'),
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

  // Removed _pickAndSendFile as per requirement: move file sending to individual private chat

  // Removed _buildTransferCard

  Widget _buildContactItem(
    Map<String, dynamic> peer, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final ip = peer['ip'] ?? peer['dest_ip'] ?? 'Unknown IP';
    final name = peer['name'] ?? 'Nearby Device';
    final unreadCount = peer['unread_count'] ?? 0;

    final id = peer['id'] ?? '...';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;

    return ListTile(
      selected: isSelected,
      selectedTileColor: Colors.deepPurple.withOpacity(0.05),
      leading: Badge(
        label: Text(unreadCount.toString()),
        isLabelVisible: unreadCount > 0,
        backgroundColor: Colors.redAccent,
        child: CircleAvatar(
          backgroundColor: isSelected
              ? Colors.deepPurple
              : Colors.deepPurple.withOpacity(0.1),
          child: Icon(
            Icons.person,
            color: isSelected ? Colors.white : Colors.deepPurple,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('ID: $shortId'),
      trailing: widget.daemonService.currentRole == 'host'
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                if (value == 'kick') {
                  await widget.daemonService.disconnectPeer(ip);
                } else if (value == 'ban') {
                  final confirm = await _showConfirmDialog(
                    'Ban Device?',
                    'This device will be blocked permanently.',
                  );
                  if (confirm) await widget.daemonService.banPeer(ip);
                } else if (value == 'mute') {
                  final isMuted = peer['is_muted'] ?? false;
                  await widget.daemonService.mutePeer(ip, !isMuted);
                }
              },
              itemBuilder: (context) {
                final isMuted = peer['is_muted'] ?? false;
                return [
                  const PopupMenuItem(
                    value: 'kick',
                    child: ListTile(
                      leading: Icon(Icons.exit_to_app, color: Colors.orange),
                      title: Text('Kick Device'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ban',
                    child: ListTile(
                      leading: Icon(Icons.block, color: Colors.red),
                      title: Text('Ban Device'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'mute',
                    child: ListTile(
                      leading: Icon(
                        isMuted ? Icons.volume_up : Icons.volume_off,
                        color: Colors.grey,
                      ),
                      title: Text(isMuted ? 'Unmute' : 'Mute'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ];
              },
            )
          : Platform.isWindows
          ? null
          : const Icon(Icons.chevron_right, color: Colors.grey),
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatScreen(peer: peer, daemonService: widget.daemonService),
              ),
            );
          },
    );
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
