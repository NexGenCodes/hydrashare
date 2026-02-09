import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/daemon_service.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/chat_widgets.dart';

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
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _subscription;
  final Map<String, _TransferStat> _transferStats = {};

  String get _peerId => widget.peer['id'] ?? widget.peer['ip'] ?? '';
  String get _peerName => widget.peer['name'] ?? 'Unknown Peer';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.daemonService.markAsRead(_peerId);
    _setupSubscription();
  }

  Future<void> _loadMessages() async {
    final msgs = await widget.daemonService.getMessages(_peerId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
    });
    _scrollToBottom();
  }

  void _setupSubscription() {
    _subscription = widget.daemonService.responses.listen((response) {
      if (response['type'] == 'CHAT_MESSAGE' &&
          response['from_ip'] == _peerId) {
        _loadMessages();
        widget.daemonService.markAsRead(_peerId);
      } else if (response['type'] == 'FILE_TRANSFER_PROGRESS') {
        final payload = response['payload'];
        if (payload != null) {
          _updateTransferProgress(payload);
        }
      } else if (response['type'] == 'TRANSFER_COMPLETE') {
        final transferId = response['transfer_id'];
        final status = response['status'];
        if (transferId != null && status != null) {
          _updateTransferStatus(transferId, status);
        }
      }
    });
  }

  void _updateTransferProgress(Map<String, dynamic> progress) {
    final transferId = progress['transfer_id'];
    final bytesSent = progress['bytes_sent'] ?? 0;
    final totalBytes = progress['total_bytes'] ?? 1;
    final timestamp = DateTime.now();

    if (!_transferStats.containsKey(transferId)) {
      _transferStats[transferId] = _TransferStat(bytesSent, timestamp, 0.0);
    } else {
      final lastStat = _transferStats[transferId]!;
      final timeDiff =
          timestamp.difference(lastStat.lastTime).inMilliseconds / 1000.0;
      if (timeDiff > 0.5) {
        final bytesDiff = bytesSent - lastStat.lastBytes;
        final speed = (bytesDiff / (1024 * 1024)) / timeDiff; // MB/s
        _transferStats[transferId] = _TransferStat(bytesSent, timestamp, speed);
      }
    }

    setState(() {
      final msgIndex = _messages.indexWhere(
        (m) => m['transfer_id'] == transferId,
      );
      if (msgIndex != -1) {
        _messages[msgIndex]['progress'] = (bytesSent / totalBytes) * 100;
        _messages[msgIndex]['speed'] = _transferStats[transferId]!.currentSpeed;
        _messages[msgIndex]['total'] = totalBytes;
        _messages[msgIndex]['status'] = bytesSent >= totalBytes
            ? 'Completed'
            : 'Transferring...';
      } else {
        _loadMessages();
      }
    });
  }

  void _updateTransferStatus(String transferId, String status) {
    setState(() {
      final msgIndex = _messages.indexWhere(
        (m) => m['transfer_id'] == transferId,
      );
      if (msgIndex != -1) {
        _messages[msgIndex]['status'] = status;
        _messages[msgIndex]['speed'] = 0.0;
        if (status == 'Completed') {
          _messages[msgIndex]['progress'] = 100.0;
        }
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    widget.daemonService.sendMessage(_peerId, text);
    _messageController.clear();
    _loadMessages();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await widget.daemonService.sendFile(_peerId, path);
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveLayout(
      title: _peerName,
      leading: BackButton(onPressed: () => Navigator.pop(context)),
      actions: [
        IconButton(
          icon: const Icon(Icons.attach_file_rounded),
          onPressed: _pickFile,
        ),
      ],
      useScrollView: false,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    if (msg['type'] == 'file_transfer') {
                      return FileTransferBubble(
                        fileName: msg['file_name'] ?? 'Unknown File',
                        progress: (msg['progress'] ?? 0.0) / 100.0,
                        isMe: msg['isMe'] ?? false,
                        timestamp: msg['timestamp'],
                        status: msg['status'] ?? '',
                        speed: msg['speed'] ?? 0.0,
                        totalSize: msg['total'] ?? 0,
                        onCancel: () => widget.daemonService.cancelTransfer(
                          msg['transfer_id'],
                        ),
                      );
                    }
                    if (msg['type'] == 'file_offer' && !msg['isMe']) {
                      return FileOfferBubble(
                        fileName: msg['extra']?['file_name'] ?? 'File',
                        offerId: msg['extra']?['offer_id'] ?? '',
                        onAccept: () => widget.daemonService.acceptFile(
                          msg['extra']?['offer_id'],
                          _peerId,
                          msg['extra']?['file_size'] ?? 0,
                        ),
                        onReject: () => widget.daemonService.rejectFile(
                          msg['extra']?['offer_id'],
                          _peerId,
                        ),
                      );
                    }
                    return ChatBubble(
                      text: msg['text'] ?? '',
                      isMe: msg['isMe'] ?? false,
                      timestamp: msg['timestamp'],
                    );
                  },
                ),
              ),
            ),
          ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
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
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              child: IconButton(
                icon: Icon(Icons.send, color: theme.colorScheme.onPrimary),
                onPressed: _sendMessage,
              ),
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
