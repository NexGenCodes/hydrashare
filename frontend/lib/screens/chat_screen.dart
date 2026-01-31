import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/daemon_service.dart';
import '../services/storage_service.dart';
import '../widgets/warning_banner.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> peer;
  final DaemonService daemonService;

  const ChatScreen({
    super.key,
    required this.peer,
    required this.daemonService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  late StreamSubscription _messageSubscription;
  late StreamSubscription _daemonSubscription;

  late String peerIp;
  late String peerName;

  // Track transfer stats for speed calculation
  final Map<String, _TransferStat> _transferStats = {};

  @override
  void initState() {
    super.initState();
    peerIp = widget.peer['ip'] ?? widget.peer['dest_ip'];
    peerName = widget.peer['name'] ?? 'Peer';

    _loadHistory();

    _messageSubscription = widget.daemonService.messages.listen((msg) {
      if (msg['ip'] == peerIp ||
          (peerIp == 'broadcast' &&
              (msg['ip'] == 'Broadcast' || msg['ip'] == 'broadcast'))) {
        setState(() {
          _messages.add({
            'text': msg['text'],
            'isMe': false,
            'timestamp':
                DateTime.tryParse(msg['timestamp'] ?? '') ?? DateTime.now(),
          });
        });
        _scrollToBottom();
      }
    });

    _daemonSubscription = widget.daemonService.responses.listen((response) {
      if (!mounted) return;

      final type = response['type'];
      final respIp = response['ip'] ?? response['dest_ip'];

      // Filter for this peer or broadcast
      if (respIp != peerIp && peerIp != 'broadcast') return;

      if (type == 'TRANSFER_STARTED' ||
          type == 'RECEIVE_STARTED' ||
          type == 'TRANSFER_PROGRESS') {
        _handleTransferUpdate(response);
      }
    });
  }

  Future<void> _loadHistory() async {
    final history = await StorageService().getHistory(peerIp);
    if (mounted) {
      setState(() {
        _messages.addAll(
          history.map(
            (m) => {
              ...m,
              'timestamp':
                  DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
            },
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _handleTransferUpdate(Map<String, dynamic> data) {
    final transferId =
        data['transfer_id']?.toString() ??
        data['file_name']?.toString() ??
        'unknown';
    final fileName = data['file_name'] ?? 'Unknown File';
    final progress = (data['percentage'] ?? 0.0);
    final transferred = (data['transferred'] ?? 0);
    final total = (data['total'] ?? 0);
    final isMe = data['direction'] == 'upload';

    // Calculate speed
    double speed = 0;
    final now = DateTime.now();
    if (_transferStats.containsKey(transferId)) {
      final prev = _transferStats[transferId]!;
      final deltaBytes = transferred - prev.lastBytes;
      final deltaTime = now.difference(prev.lastTime).inMilliseconds;
      if (deltaTime > 0) {
        speed = (deltaBytes / 1024 / 1024) / (deltaTime / 1000); // MB/s
      }
      _transferStats[transferId] = _TransferStat(transferred, now, speed);
    } else {
      _transferStats[transferId] = _TransferStat(transferred, now, 0);
    }

    setState(() {
      final index = _messages.indexWhere(
        (m) =>
            m['transfer_id'] == transferId ||
            (m['type'] == 'file_transfer' && m['file_name'] == fileName),
      );

      if (index != -1) {
        _messages[index]['transfer_id'] = transferId;
        _messages[index]['progress'] = progress;
        _messages[index]['transferred'] = transferred;
        _messages[index]['total'] = total;
        _messages[index]['speed'] = speed;
        _messages[index]['status'] = progress >= 100
            ? 'Completed'
            : 'Transferring...';
        _messages[index]['direction'] = data['direction'];
        if (data['type'] == 'TRANSFER_COMPLETE') {
          _messages[index]['status'] = 'Completed';
        }
        if (data['type'] == 'TRANSFER_ERROR') {
          _messages[index]['status'] = 'Error: ${data['error']}';
        }
      } else {
        _messages.add({
          'type': 'file_transfer',
          'transfer_id': transferId,
          'file_name': fileName,
          'progress': progress,
          'transferred': transferred,
          'total': total,
          'speed': 0.0,
          'isMe': isMe,
          'direction': data['direction'],
          'timestamp': DateTime.now(),
          'status': 'Starting...',
        });
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _daemonSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (peerIp == 'broadcast') {
      widget.daemonService.broadcastChat(text);
    } else {
      widget.daemonService.sendChat(peerIp, text);
    }

    setState(() {
      _messages.add({'text': text, 'isMe': true, 'timestamp': DateTime.now()});
    });

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;

      try {
        if (peerIp == 'broadcast') {
          await widget.daemonService.sendCommand({
            'type': 'BROADCAST_FILE',
            'file_path': filePath,
          });
        } else {
          await widget.daemonService.sendCommand({
            'type': 'SEND_FILE',
            'file_path': filePath,
            'dest_ip': peerIp,
          });
        }

        setState(() {
          _messages.add({
            'text': '📎 Sent file: $fileName',
            'isMe': true,
            'timestamp': DateTime.now(),
          });
        });
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending file: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(peerName),
            Text(
              peerIp == 'broadcast' ? 'Broadcasting to all' : peerIp,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          const WarningBanner(),
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  if (msg['type'] == 'file_transfer') {
                    return _FileTransferBubble(
                      fileName: msg['file_name'] ?? 'Unknown File',
                      progress: (msg['progress'] ?? 0.0) / 100.0,
                      isMe: msg['isMe'] ?? false,
                      timestamp: msg['timestamp'],
                      status: msg['status'] ?? '',
                      speed: msg['speed'] ?? 0.0,
                      totalSize: msg['total'] ?? 0,
                    );
                  }
                  if (msg['type'] == 'file_offer' && !msg['isMe']) {
                    return _FileOfferBubble(
                      fileName: msg['extra']?['file_name'] ?? 'File',
                      offerId: msg['extra']?['offer_id'] ?? '',
                      onAccept: () => widget.daemonService.acceptFile(
                        msg['extra']?['offer_id'],
                        peerIp,
                      ),
                      onReject: () => widget.daemonService.rejectFile(
                        msg['extra']?['offer_id'],
                        peerIp,
                      ),
                    );
                  }
                  return _ChatBubble(
                    text: msg['text'] ?? '',
                    isMe: msg['isMe'] ?? false,
                    timestamp: msg['timestamp'],
                  );
                },
              ),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.deepPurple,
              ),
              onPressed: _sendFile,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Colors.grey[100],
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.deepPurple,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black45,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTransferBubble extends StatelessWidget {
  final String fileName;
  final double progress;
  final bool isMe;
  final DateTime timestamp;
  final String status;
  final double speed;
  final int totalSize;

  const _FileTransferBubble({
    required this.fileName,
    required this.progress,
    required this.isMe,
    required this.timestamp,
    required this.status,
    this.speed = 0,
    this.totalSize = 0,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMe
                      ? Icons.upload_file_rounded
                      : Icons.download_for_offline_rounded,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.deepPurple,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    if (progress > 0 && progress < 1)
                      Text(
                        '${speed.toStringAsFixed(1)} MB/s • ${_formatSize(totalSize)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey,
                        ),
                      ),
                  ],
                ),
                Text(
                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FileOfferBubble extends StatelessWidget {
  final String fileName;
  final String offerId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FileOfferBubble({
    required this.fileName,
    required this.offerId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.file_present_rounded, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  'File Offer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(fileName, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferStat {
  final int lastBytes;
  final DateTime lastTime;
  final double currentSpeed;
  _TransferStat(this.lastBytes, this.lastTime, this.currentSpeed);
}
