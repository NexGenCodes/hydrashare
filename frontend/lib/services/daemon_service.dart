import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'device_info_service.dart';
import 'storage_service.dart';
import 'rust_daemon_ffi.dart';
import 'connectivity_bridge.dart';
import 'mpc_bridge.dart';

/// Service class for managing the native Rust engine via FFI
class DaemonService {
  static final DaemonService _instance = DaemonService._internal();
  factory DaemonService() => _instance;
  DaemonService._internal();

  bool _isConnected = false;

  static const _p2pChannel = MethodChannel('com.example.hydrashare/p2p');

  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();

  final _connectedPeersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _connectedPeers = [];

  final _discoveredPeersController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final List<Map<String, dynamic>> _discoveredPeers = [];

  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _fileOfferController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _warningController = StreamController<Map<String, dynamic>>.broadcast();

  Timer? _discoveryTimer;

  String _currentRole = 'none'; // 'host', 'guest', or 'none'

  /// Stream of responses from the daemon
  Stream<Map<String, dynamic>> get responses => _responseController.stream;

  /// Stream of currently connected peers
  Stream<List<Map<String, dynamic>>> get connectedPeers =>
      _connectedPeersController.stream;

  /// Current list of connected peers
  List<Map<String, dynamic>> get currentPeers =>
      List.unmodifiable(_connectedPeers);

  /// Stream of discovered (but not yet connected) peers
  Stream<List<Map<String, dynamic>>> get discoveredPeers =>
      _discoveredPeersController.stream;

  /// Current list of discovered peers
  List<Map<String, dynamic>> get currentDiscoveredPeers =>
      List.unmodifiable(_discoveredPeers);

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

  /// Connect to the Rust engine via FFI and start listening for events
  Future<void> connect({int retries = 5}) async {
    if (_isConnected) {
      debugPrint('ℹ️ Already connected to Hydra Muscle engine');
      return;
    }

    if (kIsWeb) return;

    try {
      debugPrint('🔌 Initializing Hydra Muscle engine via FFI...');
      HydraMuscleFfi.init();

      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(appDir.path, 'hydra.db');

      final result = HydraMuscleFfi.startEngine(dbPath);
      if (result != 0) {
        throw Exception('Failed to start Rust engine: $result');
      }

      _isConnected = true;
      debugPrint('✅ Hydra Muscle engine started');

      _startListening();
      // _startPing(); // No longer needed with FFI

      // Sync device name
      final deviceName = await DeviceInfoService.getDeviceName();
      await setDeviceName(deviceName);

      // Start discovery by default
      await startDiscovery();

      return;
    } catch (e) {
      debugPrint('❌ Failed to start engine: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void _startListening() {
    HydraMuscleFfi.events.listen(
      (String eventJson) {
        try {
          final response = jsonDecode(eventJson) as Map<String, dynamic>;
          _responseController.add(response);

          if (response['type'] == 'PEER_CONNECTED') {
            _addConnectedPeer(response);
          } else if (response['type'] == 'PEER_DISCONNECTED') {
            _removeConnectedPeer(response);
          } else if (response['type'] == 'WIFI_DIRECT_REQ') {
            _handleWiFiDirectRequest();
          } else if (response['type'] == 'SESSION_CODE_GENERATED') {
            debugPrint('🔗 Session Code Generated: ${response['code']}');
          } else if (response['type'] == 'SIGNALING_STARTED') {
            debugPrint('📡 MFR Signaling started for: ${response['id']}');
          } else if (response['type'] == 'PEER_DISCOVERED') {
            _addDiscoveredPeer(response);
          } else if (response['type'] == 'PEER_DISCOVERY_CARD') {
            _handleMeshIntroduction(response);
          } else if (response['type'] == 'RECEIVE_STARTED') {
            debugPrint('📥 Incoming transfer started from: ${response['ip']}');
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
          } else if (response['type'] == 'TRANSFER_PROGRESS') {
            // Forward to response controller (handled by UI)
          } else if (response['type'] == 'TRANSFER_COMPLETE') {
            debugPrint('✅ Transfer complete: ${response['transfer_id']}');
          } else if (response['type'] == 'QR_PAYLOAD_GENERATED') {
            debugPrint('📱 QR Payload Generated');
          } else if (response['type'] == 'SETTING_REPORTED') {
            // Handled via getSetting completer
          }
          // Add other event types as needed
        } catch (e) {
          debugPrint('❌ Error parsing FFI event: $e');
        }
      },
      onError: (error) {
        debugPrint('❌ FFI Event error: $error');
      },
    );
  }

  /// Send a command to the Rust engine
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected) {
      throw Exception('Not connected to Hydra Muscle engine');
    }

    try {
      final jsonString = jsonEncode(command);
      debugPrint('📤 Sending command via FFI: $jsonString');

      HydraMuscleFfi.sendCommand(jsonString);
    } catch (e) {
      debugPrint('❌ Failed to send command: $e');
      rethrow;
    }
  }

  /// Start discovering peers on the network
  Future<void> startDiscovery() async {
    await sendCommand({'type': 'START_DISCOVERY'});

    if (!kIsWeb && Platform.isAndroid) {
      debugPrint('🌲 Starting Native Discovery (WiFi-Direct/Bluetooth)...');
      await WiFiDirectBridge.startDiscovery();
      await BluetoothBridge.startDiscovery();

      _discoveryTimer?.cancel();
      _discoveryTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _pollNativePeers(),
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      debugPrint('🍏 Starting iOS Native Discovery (MPC)...');
      await MpcBridge.startMpc();
      MpcBridge.peerFound.listen((peer) {
        _emitNativePeer(peer, 'mpc', 0);
      });
    }
  }

  /// Stop discovering peers
  Future<void> stopDiscovery() async {
    await sendCommand({'type': 'STOP_DISCOVERY'});
    _discoveryTimer?.cancel();
    if (Platform.isIOS) {
      await MpcBridge.stopMpc();
    }
  }

  Future<void> _pollNativePeers() async {
    try {
      final wifiPeers = await WiFiDirectBridge.getPeers();
      for (final p in wifiPeers) {
        _emitNativePeer(
          p,
          'wifi-direct',
          5052,
        ); // Assuming standard port or negotiation
      }

      final btPeers = await BluetoothBridge.getPeers();
      for (final p in btPeers) {
        _emitNativePeer(p, 'bluetooth', 0);
      }
    } catch (e) {
      debugPrint('Error polling native peers: $e');
    }
  }

  void _emitNativePeer(Map<String, dynamic> peer, String type, int port) {
    if (peer['id'] == null) return;

    _responseController.add({
      'type': 'PEER_DISCOVERED',
      'ip': peer['id'], // Using ID as IP/Address for native connection
      'name': peer['name'] ?? 'Unknown Peer',
      'port': port,
      'protocol': type,
      'is_native': true,
    });
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
    await sendCommand({'type': 'JOIN_SESSION', 'pin': pin});

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

  /// Generate a QR payload for instant mobile pairing
  Future<Map<String, dynamic>> generateQrPayload() async {
    final completer = Completer<Map<String, dynamic>>();

    final subscription = responses.listen((response) {
      if (response['type'] == 'QR_PAYLOAD_GENERATED') {
        completer.complete(jsonDecode(response['payload_json'] as String));
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    await sendCommand({'type': 'GENERATE_QR_PAYLOAD'});

    try {
      final payload = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('QR payload generation timed out');
        },
      );
      await subscription.cancel();
      return payload;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Generate a Long-Distance Transfer (LDT) session code
  Future<String> generateSessionCode() async {
    final completer = Completer<String>();

    final subscription = responses.listen((response) {
      if (response['type'] == 'SESSION_CODE_GENERATED') {
        completer.complete(response['code'] as String);
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    await sendCommand({'type': 'GENERATE_SESSION_CODE'});

    try {
      final code = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Session code generation timed out');
        },
      );
      await subscription.cancel();
      return code;
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }
  }

  /// Join a session using an LDT session code (hydra://...)
  Future<String> joinWithSessionCode(String code) async {
    final completer = Completer<String>();

    final subscription = responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED') {
        completer.complete('connected');
      } else if (response['type'] == 'SIGNALING_STARTED') {
        completer.complete('signaling');
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    await sendCommand({'type': 'JOIN_SESSIONCODE', 'text': code});

    try {
      final status = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Session joining timed out');
        },
      );
      await subscription.cancel();
      return status;
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

  /// Alias for sendChat to maintain backward compatibility
  Future<void> sendMessage(String peerIp, String text) =>
      sendChat(peerIp, text);

  /// Broadcast a chat message to all connected peers (Host only)
  Future<void> broadcastChat(String text) async {
    await StorageService().saveMessage(
      peerIp: 'broadcast',
      text: text,
      isMe: true,
    );
    await sendCommand({'type': 'BROADCAST_CHAT', 'text': text});
  }

  /// Get message history for a peer
  Future<List<Map<String, dynamic>>> getMessages(String peerIp) async {
    return await StorageService().getHistory(peerIp);
  }

  /// Close the connection to the daemon
  Future<void> disconnect() async {
    debugPrint('🔌 Stopping Hydra Muscle engine...');

    HydraMuscleFfi.stopEngine();
    _isConnected = false;

    debugPrint('✅ Engine stopped');
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

    // Remove from discovered list if it was there
    _discoveredPeers.removeWhere(
      (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == id,
    );
    _discoveredPeersController.add(currentDiscoveredPeers);

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

  void _addDiscoveredPeer(Map<String, dynamic> peer) {
    final id = peer['id'] ?? peer['ip'] ?? peer['dest_ip'];
    if (id == null) return;

    // Don't add if already connected
    final isConnected = _connectedPeers.any(
      (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == id,
    );
    if (isConnected) return;

    final index = _discoveredPeers.indexWhere(
      (p) => (p['id'] ?? p['ip'] ?? p['dest_ip']) == id,
    );

    if (index != -1) {
      _discoveredPeers[index] = {..._discoveredPeers[index], ...peer};
    } else {
      debugPrint('🔭 Peer discovered: ${peer['name']} ($id)');
      _discoveredPeers.add(peer);
    }
    _discoveredPeersController.add(currentDiscoveredPeers);
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
    HydraMuscleFfi.stopEngine();
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
  Future<void> sendFile(String peerId, String filePath, String destIp) async {
    await sendCommand({
      'type': 'SEND_FILE',
      'peer_id': peerId,
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

  /// Settings: Get a setting value
  Future<String> getSetting(String key) async {
    final completer = Completer<String>();
    final subscription = responses.listen((response) {
      if (response['type'] == 'SETTING_REPORTED' && response['key'] == key) {
        completer.complete(response['value'] as String);
      }
    });

    await sendCommand({'type': 'GET_SETTINGS', 'key': key});

    try {
      final value = await completer.future.timeout(const Duration(seconds: 3));
      await subscription.cancel();
      return value;
    } catch (e) {
      await subscription.cancel();
      return '';
    }
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
