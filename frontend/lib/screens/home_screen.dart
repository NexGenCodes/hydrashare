import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import '../services/daemon_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/notification_service.dart';
import 'role_selection_screen.dart';
import 'chat_screen.dart';
import 'qr_handshake_screen.dart';

class HomeScreen extends StatefulWidget {
  final DaemonService daemonService;

  const HomeScreen({super.key, required this.daemonService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _activeTransfers = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    widget.daemonService.responses.listen((response) {
      if (!mounted) return;

      if (response['type'] == 'TRANSFER_STARTED' ||
          response['type'] == 'RECEIVE_STARTED' ||
          response['type'] == 'TRANSFER_PROGRESS') {
        _updateTransfer(response);
      } else if (response['type'] == 'TRANSFER_ERROR') {
        _removeTransfer(response['transfer_id'] ?? response['file_name']);
      } else if (response['type'] == 'INCOMING_CHAT') {
        NotificationService().showNotification(
          id: (response['ip'] ?? 'msg').hashCode,
          title: 'New Message',
          body: response['text'] ?? '',
        );
      } else if (response['type'] == 'RECEIVE_STARTED') {
        NotificationService().showNotification(
          id: (response['file_name'] ?? 'file').hashCode,
          title: 'Receiving File',
          body: 'Started receiving ${response['file_name']}',
        );
      }
    });
  }

  void _updateTransfer(Map<String, dynamic> data) {
    setState(() {
      final id = data['transfer_id'] ?? data['file_name'];
      final index = _activeTransfers.indexWhere(
        (t) => (t['transfer_id'] ?? t['file_name']) == id,
      );
      if (index >= 0) {
        _activeTransfers[index] = {..._activeTransfers[index], ...data};
      } else {
        if (_activeTransfers.isEmpty) {
          WakelockPlus.enable();
          debugPrint('🔆 Wake Lock Enabled');
        }
        _activeTransfers.add(data);
      }
    });
  }

  void _removeTransfer(String? id) {
    if (id == null) return;
    setState(() {
      _activeTransfers.removeWhere(
        (t) => (t['transfer_id'] ?? t['file_name']) == id,
      );
      if (_activeTransfers.isEmpty) {
        WakelockPlus.disable();
        debugPrint('🌑 Wake Lock Disabled');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'HydraShare',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        actions: [
          if (widget.daemonService.currentRole == 'host')
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Add Device',
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
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSendFile,
        icon: const Icon(Icons.send_rounded),
        label: const Text('Send File'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Active Transfers Section
              if (_activeTransfers.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Transfers',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._activeTransfers.map((t) => _buildTransferCard(t)),
                      ],
                    ),
                  ),
                ),

              // Host Broadcast Row
              if (widget.daemonService.currentRole == 'host')
                SliverToBoxAdapter(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.campaign_rounded, color: Colors.white),
                    ),
                    title: Text(
                      'Broadcast Message',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Send to all connected guests'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            peer: {'ip': 'broadcast', 'name': 'Broadcast'},
                            daemonService: widget.daemonService,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (widget.daemonService.currentRole == 'host')
                const SliverToBoxAdapter(child: Divider()),

              // Connected Devices Header
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

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: widget.daemonService.connectedPeers,
                initialData: widget.daemonService.currentPeers,
                builder: (context, snapshot) {
                  final peers = snapshot.data ?? [];
                  if (peers.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.devices_other_rounded,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No devices connected',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (widget.daemonService.currentRole == 'none')
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RoleSelectionScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Connect New Device'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildContactItem(peers[index]),
                      childCount: peers.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendFile() async {
    final peers = widget.daemonService.currentPeers;
    if (peers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No peers connected to send file')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;

        if (!mounted) return;

        // If only one peer, send directly (well, send offer)
        if (peers.length == 1) {
          final peerIp = peers.first['ip'] ?? peers.first['dest_ip'];
          widget.daemonService.sendFile(filePath, peerIp);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sending file offer to $peerIp...')),
          );
        } else {
          // Show dialog to select peer
          _showPeerSelectionDialog(filePath, peers);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  void _showPeerSelectionDialog(
    String filePath,
    List<Map<String, dynamic>> peers,
  ) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Recipient'),
        children: peers.map((peer) {
          final ip = peer['ip'] ?? peer['dest_ip'];
          final name = peer['name'] ?? 'Unknown';
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              widget.daemonService.sendFile(filePath, ip);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sending file offer to $name...')),
              );
            },
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(name),
              subtitle: Text(ip),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer) {
    final fileName = transfer['file_name'] ?? 'Unknown File';
    final progress = (transfer['percentage'] ?? 0.0) / 100.0;
    final speed = transfer['speed_mbps'] ?? 0.0;
    final isReceiving =
        transfer['type']?.toString().contains('RECEIVE') ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isReceiving
                      ? Colors.green.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReceiving ? Icons.download_rounded : Icons.upload_rounded,
                  color: isReceiving ? Colors.greenAccent : Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${speed.toStringAsFixed(1)} MB/s',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                isReceiving ? Colors.greenAccent : Colors.blueAccent,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(Map<String, dynamic> peer) {
    final ip = peer['ip'] ?? peer['dest_ip'] ?? 'Unknown IP';
    final name = peer['name'] ?? 'Nearby Device';
    final unreadCount = peer['unread_count'] ?? 0;

    return ListTile(
      leading: Badge(
        label: Text(unreadCount.toString()),
        isLabelVisible: unreadCount > 0,
        backgroundColor: Colors.redAccent,
        child: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.person, color: Colors.blue),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(ip),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
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
}
