import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/daemon_service.dart';
import 'package:file_picker/file_picker.dart';

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
      } else if (response['type'] == 'TRANSFER_COMPLETE' ||
          response['type'] == 'RECEIVE_COMPLETE' ||
          response['type'] == 'TRANSFER_ERROR') {
        _removeTransfer(response['transfer_id'] ?? response['file_name']);
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
    });
  }

  Future<void> _sendFile(String destIp) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      try {
        await widget.daemonService.sendCommand({
          'type': 'START_TRANSFER',
          'file_path': result.files.single.path,
          'dest_ip': destIp,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'HydraShare',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
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
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._activeTransfers
                            .map((t) => _buildTransferCard(t))
                            .toList(),
                      ],
                    ),
                  ),
                ),

              // Connected Devices Section
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Text(
                        'Connected Devices',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: widget.daemonService.connectedPeers,
                        initialData: widget.daemonService.currentPeers,
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count Active',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                              color: Colors.white10,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No devices connected',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Connect New Device'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
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
                      (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 8.0,
                        ),
                        child: _buildDeviceCard(peers[index]),
                      ),
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

  Widget _buildDeviceCard(Map<String, dynamic> peer) {
    final ip = peer['ip'] ?? peer['dest_ip'] ?? 'Unknown IP';
    final name = peer['name'] ?? 'Nearby Device';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _sendFile(ip),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.laptop_mac_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF16213E),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ip,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
