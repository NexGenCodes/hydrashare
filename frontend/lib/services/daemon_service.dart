import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'device_info_service.dart';
import 'storage_service.dart';

/// Service class for managing persistent TCP connection to Go daemon
class DaemonService {
  static final DaemonService _instance = DaemonService._internal();
  factory DaemonService() => _instance;
  DaemonService._internal();

  Socket? _socket;
  String host = 'localhost';
  int port = 5050;
  bool _isConnected = false;

  static const _p2pChannel = MethodChannel('com.example.hydrashare/p2p');

  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();

  final _connectedPeersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _connectedPeers = [];
  Timer? _pingTimer;

  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileOfferController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _warningController = StreamController<Map<String, dynamic>>.broadcast();

  String _currentRole = 'none'; // 'host', 'guest', or 'none'

  /// Stream of responses from the daemon
  Stream<Map<String, dynamic>> get responses => _responseController.stream;

  /// Stream of currently connected peers
  Stream<List<Map<String, dynamic>>> get connectedPeers =>
      _connectedPeersController.stream;

  /// Current list of connected peers
  List<Map<String, dynamic>> get currentPeers =>
      List.unmodifiable(_connectedPeers);

  /// Stream of incoming chat messages
  Stream<Map<String, dynamic>> get messages => _chatController.stream;

  /// Stream of incoming file offers
  Stream<Map<String, dynamic>> get fileOffers => _fileOfferController.stream;

  /// Stream of network/proximity warnings
  Stream<Map<String, dynamic>> get warnings => _warningController.stream;

  /// Check if currently connected to daemon
  bool get isConnected => _isConnected;

  /// Get current role
  String get currentRole => _currentRole;

  /// Set current role and clear peers
  void setRole(String role) {
    _currentRole = role;
    _connectedPeers.clear();
    _connectedPeersController.add([]);
  }

  /// Connect to the Go daemon and start listening for responses
  Future<void> connect({int retries = 20}) async {
    if (_isConnected) {
      debugPrint('ℹ️ Already connected to Go daemon');
      return;
    }

    if (kIsWeb) {
      // Web support removed for native desktop migration
      return;
    }

    for (int i = 0; i < retries; i++) {
      try {
        debugPrint(
          '🔌 Connecting to Go daemon at $host:$port (Attempt ${i + 1}/$retries)...',
        );

        _socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 2),
        );
        _isConnected = true;

        debugPrint('✅ Connected to Go daemon');
        _startListening();
        _startPing();

        // Automatically register device name with daemon
        final deviceName = await DeviceInfoService.getDeviceName();
        await setDeviceName(deviceName);

        // Sync existing peers (in case daemon was already running)
        await sendCommand({'type': 'GET_PEERS'});

        // Start native foreground service for background survival
        if (Platform.isAndroid) {
          try {
            await _p2pChannel.invokeMethod('startForegroundService');
            debugPrint('🛡️ Android Foreground Service Started');
          } catch (e) {
            debugPrint('⚠️ Failed to start foreground service: $e');
          }
        }

        return; // Success!
      } catch (e) {
        debugPrint(
          '⏳ Connection attempt ${i + 1} failed: $e. Retrying in 1s...',
        );
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    _isConnected = false;
    throw Exception('Failed to connect to daemon after $retries attempts');
  }

  void _startListening() {
    if (_socket == null) return;

    _socket!.listen(
      (List<int> data) {
        final message = utf8.decode(data).trim();
        // Handle multiple JSON objects in one packet (common in TCP)
        final messages = message.split('\n');
        for (var msg in messages) {
          if (msg.isEmpty) continue;
          try {
            final response = jsonDecode(msg) as Map<String, dynamic>;
            _responseController.add(response);

            if (response['type'] == 'PEER_CONNECTED') {
              _addConnectedPeer(response);
            } else if (response['type'] == 'PEER_DISCONNECTED') {
              _removeConnectedPeer(response);
            } else if (response['type'] == 'WIFI_DIRECT_REQ') {
              _handleWiFiDirectRequest();
            } else if (response['type'] == 'PEER_DISCOVERED') {
              // Discovery Radar update:handled by the stream, but we can log it
              debugPrint(
                '🔭 Peer discovered on network: ${response['name']} (${response['ip']})',
              );
            } else if (response['type'] == 'PEER_DISCOVERY_CARD') {
              // G2G Mesh Introduction
              debugPrint(
                '🤝 Hub introduced us to new guest: ${response['name']}',
              );
              _handleMeshIntroduction(response);
            } else if (response['type'] == 'RECEIVE_STARTED') {
              debugPrint(
                '📥 Incoming transfer started from: ${response['ip']}',
              );
              // This can trigger a global snackbar or notification in higher-level widgets
            } else if (response['type'] == 'INCOMING_CHAT') {
              final peerIp = response['ip'] ?? 'Broadcast';
              StorageService().saveMessage(
                peerIp: peerIp,
                text: response['text'] ?? '',
                isMe: false,
              );
              _chatController.add(response);
              if (response['unread'] == true) {
                _incrementUnread(response['ip']);
              }
            } else if (response['type'] == 'FILE_OFFER') {
              final peerIp = response['ip'] ?? 'Broadcast';
              StorageService().saveMessage(
                peerIp: peerIp,
                text: '📎 Incoming file: ${response['file_name']}',
                isMe: false,
                type: 'file_offer',
                extra: {
                  'file_name': response['file_name'],
                  'offer_id': response['offer_id'],
                },
              );
              _fileOfferController.add(response);
            } else if (response['type'] == 'TRANSFER_REJECTED') {
              debugPrint('❌ File transfer rejected by peer');
            }
          } catch (e) {
            debugPrint('❌ Error parsing response: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Socket error: $error');
        _isConnected = false;
      },
      onDone: () {
        debugPrint('🔌 Connection closed');
        _isConnected = false;
      },
    );
  }

  /// Send a command to the daemon
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected) {
      throw Exception('Not connected to daemon');
    }

    try {
      final jsonString = jsonEncode(command);
      debugPrint('📤 Sending to daemon: $jsonString');

      if (kIsWeb) {
        // Web support removed
        return;
      } else {
        if (_socket == null) throw Exception('Socket unavailable');
        _socket!.write('$jsonString\n');
        await _socket!.flush();
      }
    } catch (e) {
      debugPrint('❌ Failed to send command: $e');
      rethrow;
    }
  }

  /// Send a ping command to test the connection
  Future<void> ping() async {
    await sendCommand({'type': 'ping'});
  }

  /// Start discovering peers on the network
  Future<void> startDiscovery() async {
    await sendCommand({'type': 'START_DISCOVERY'});
  }

  /// Stop discovering peers
  Future<void> stopDiscovery() async {
    await sendCommand({'type': 'STOP_DISCOVERY'});
  }

  /// Generate a secure AES encryption key for QR handshake
  Future<String> generateCode() async {
    final completer = Completer<String>();

    // Listen for the response
    final subscription = responses.listen((response) {
      if (response['type'] == 'CODE_GENERATED') {
        completer.complete(response['key'] as String);
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    // Send the command
    await sendCommand({'type': 'GENERATE_CODE'});

    // Wait for response with timeout
    try {
      final key = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Key generation timed out');
        },
      );
      await subscription.cancel();
      return key;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Generate a secure AES encryption key AND get host IP for QR handshake
  Future<Map<String, String>> generateCodeWithIP() async {
    final completer = Completer<Map<String, String>>();

    // Listen for the response
    final subscription = responses.listen((response) async {
      if (response['type'] == 'CODE_GENERATED') {
        String ip = response['ip'] as String? ?? '127.0.0.1';

        // If daemon reports loopback, try to find the real local IP
        if (ip == '127.0.0.1' || ip == 'localhost' || ip == '::1') {
          final localIp = await _getLocalIp();
          if (localIp != null) ip = localIp;
        }

        completer.complete({
          'key': response['key'] as String,
          'pin': response['pin'] as String? ?? '',
          'ip': ip,
        });
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    // Send the command
    await sendCommand({'type': 'GENERATE_CODE'});

    // Wait for response with timeout
    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Key generation timed out');
        },
      );
      await subscription.cancel();
      return result;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Connect to the host using a 6-digit PIN
  Future<void> connectWithPIN(String pin) async {
    final completer = Completer<void>();

    // Listen for the response
    final subscription = responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED') {
        completer.complete();
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    // Send the command
    await sendCommand({'type': 'CONNECT_WITH_PIN', 'key': pin});

    // Wait for response with timeout
    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out');
        },
      );
      await subscription.cancel();
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Set local device name in daemon
  Future<void> setDeviceName(String name) async {
    await sendCommand({'type': 'SET_DEVICE_NAME', 'name': name});
  }

  /// Connect to a peer using the scanned code/IP
  Future<void> connectToPeer(String code, {String? key}) async {
    final completer = Completer<void>();

    // Listen for the response
    final subscription = responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED') {
        completer.complete();
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    // Parse the code: format is "ip|key" or just "ip" if key is provided separately
    String targetIp;
    String? encryptionKey = key;

    if (code.contains('|') && key == null) {
      final parts = code.split('|');
      targetIp = parts[0];
      encryptionKey = parts.length > 1 ? parts[1] : null;
    } else {
      targetIp = code;
    }

    // Send the command
    await sendCommand({
      'type': 'CONNECT_PEER',
      'dest_ip': targetIp,
      if (encryptionKey != null) 'key': encryptionKey,
    });

    // Wait for response with timeout
    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out');
        },
      );
      await subscription.cancel();
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Send a private chat message to a peer
  Future<void> sendChat(String peerIp, String text) async {
    await StorageService().saveMessage(peerIp: peerIp, text: text, isMe: true);
    await sendCommand({'type': 'SEND_CHAT', 'dest_ip': peerIp, 'text': text});
  }

  /// Broadcast a chat message to all connected peers (Host only)
  Future<void> broadcastChat(String text) async {
    await StorageService().saveMessage(
      peerIp: 'broadcast',
      text: text,
      isMe: true,
    );
    await sendCommand({'type': 'BROADCAST_CHAT', 'text': text});
  }

  /// Close the connection to the daemon
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting from daemon...');

    await _socket?.close();
    _socket = null;
    _isConnected = false;
    _pingTimer?.cancel();

    debugPrint('✅ Disconnected');
  }

  /// Mark messages from a peer as read
  Future<void> markAsRead(String peerIdOrIp) async {
    await sendCommand({'type': 'MARK_AS_READ', 'dest_ip': peerIdOrIp});
    final index = _connectedPeers.indexWhere(
      (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == peerIdOrIp,
    );
    if (index != -1) {
      _connectedPeers[index]['unread_count'] = 0;
      _connectedPeersController.add(currentPeers);
    }
  }

  void _incrementUnread(String? idOrIp) {
    if (idOrIp == null) return;
    final index = _connectedPeers.indexWhere(
      (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == idOrIp,
    );
    if (index != -1) {
      final current = _connectedPeers[index]['unread_count'] ?? 0;
      _connectedPeers[index]['unread_count'] = current + 1;
      _connectedPeersController.add(currentPeers);
    }
  }

  void _handleMeshIntroduction(Map<String, dynamic> card) {
    final ips = card['ips'] as List<dynamic>?;
    final ip = (ips != null && ips.isNotEmpty)
        ? ips[0].toString()
        : card['peer_id'].toString();

    _responseController.add({
      'type': 'PEER_DISCOVERED',
      'ip': ip,
      'name': card['name'] ?? 'Mesh Guest',
      'port': 5051,
      'is_mesh_intro': true,
    });
  }

  void _addConnectedPeer(Map<String, dynamic> peer) {
    final id = peer['id'] ?? peer['ip'] ?? peer['dest_ip'];
    if (id == null) return;

    final index = _connectedPeers.indexWhere(
      (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == id,
    );

    if (index != -1) {
      // Update existing
      _connectedPeers[index] = {..._connectedPeers[index], ...peer};
    } else {
      // Add new
      _connectedPeers.add(peer);
    }
    _connectedPeersController.add(currentPeers);
  }

  void _removeConnectedPeer(Map<String, dynamic> peer) {
    final id = peer['id'] ?? peer['ip'] ?? peer['dest_ip'];
    if (id != null) {
      _connectedPeers.removeWhere(
        (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == id,
      );
      _connectedPeersController.add(currentPeers);
    }
  }

  /// Clean up resources
  void dispose() {
    _responseController.close();
    _connectedPeersController.close();
    _chatController.close();
    _fileOfferController.close();
    _warningController.close();
    _socket?.destroy();
  }

  Future<void> _handleWiFiDirectRequest() async {
    debugPrint('🌲 Forest Mode: Triggering native P2P invitation');
    try {
      await _p2pChannel.invokeMethod('openP2PInvitation');
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to open P2P invitation: ${e.message}');
    }
  }

  /// Send a file offer to a peer
  Future<void> sendFile(String filePath, String destIp) async {
    await sendCommand({
      'type': 'SEND_FILE',
      'file_path': filePath,
      'dest_ip': destIp,
    });
  }

  /// Accept a file offer
  Future<void> acceptFile(String offerId, String destIp) async {
    await sendCommand({
      'type': 'ACCEPT_FILE',
      'offer_id': offerId,
      'dest_ip': destIp,
    });
  }

  /// Reject a file offer
  Future<void> rejectFile(String offerId, String destIp) async {
    await sendCommand({
      'type': 'REJECT_FILE',
      'offer_id': offerId,
      'dest_ip': destIp,
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isConnected) {
        ping().catchError((e) {
          debugPrint('📡 Keep-alive ping failed: $e');
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Admin: Disconnect a peer (Kick)
  Future<void> disconnectPeer(String ip) async {
    await sendCommand({'type': 'DISCONNECT_PEER', 'dest_ip': ip});
  }

  /// Admin: Ban a peer (Block IP)
  Future<void> banPeer(String ip) async {
    await sendCommand({'type': 'BAN_PEER', 'dest_ip': ip});
  }

  /// Admin: Mute or Unmute a peer
  Future<void> mutePeer(String ip, bool mute) async {
    await sendCommand({
      'type': 'MUTE_PEER',
      'dest_ip': ip,
      'text': mute.toString(),
    });
  }

  /// Settings: Set Max File Size
  Future<void> setMaxFileSize(int bytes) async {
    await sendCommand({
      'type': 'SET_SETTINGS',
      'key': 'max_file_size',
      'text': bytes.toString(),
    });
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }
}
