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
import 'connectivity_bridge.dart';
import 'mpc_bridge.dart';

// Import generated FRB bindings
import '../rust/api.dart' as rust_api;
import '../rust/frb_generated.dart';
import '../rust/ffi.dart';

/// Service class for managing the native Rust engine via FRB
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

  // Flag to ensure FRB is only initialized once
  static bool _frbInitialized = false;

  /// Stream of responses from the daemon (mapped from DaemonEvent)
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

  /// Connect to the Rust engine via FRB and start listening for events
  Future<void> connect({int retries = 5}) async {
    if (_isConnected) {
      debugPrint('ℹ️ Already connected to Hydra Muscle engine');
      return;
    }

    if (kIsWeb) return;

    try {
      debugPrint('🔌 Initializing Hydra Muscle engine via FRB...');

      if (!_frbInitialized) {
        await RustLib.init();
        _frbInitialized = true;
      }

      _startListening();

      final appDir = await getApplicationSupportDirectory();
      if (!await appDir.exists()) {
        print('DEBUG_HYDRA: 📁 Creating support directory...');
        await appDir.create(recursive: true);
      }
      print('DEBUG_HYDRA: 📂 Data Directory (Support): ${appDir.path}');

      // Initialize the daemon (sets up DB, logging, etc.)
      const dbName = 'hydra.db';
      final dbPath = p.join(appDir.path, dbName);
      print('DEBUG_HYDRA: 🗄️ Expected Database Path: $dbPath');

      // Verify write access to the directory
      try {
        final testFile = File(p.join(appDir.path, '.write_test'));
        await testFile.writeAsString('test');
        await testFile.delete();
        print('DEBUG_HYDRA: ✅ Write access confirmed');
      } catch (e) {
        print('DEBUG_HYDRA: ❌ No write access to directory: $e');
      }

      final initResult = await rust_api.initDaemon(dataDir: appDir.path);

      if (initResult != 0) {
        throw Exception('Failed to initialize daemon: $initResult');
      }

      // Start the engine (orchestrator, discovery loop)
      final startResult = await rust_api.startEngine();
      if (startResult != 0) {
        throw Exception('Failed to start Rust engine: $startResult');
      }

      _isConnected = true;
      debugPrint('✅ Hydra Muscle engine started');

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
    rust_api.createEventStream().listen(
      (DaemonEvent event) {
        try {
          // Map DaemonEvent to the generic Map structure expected by existing UI
          final response = _mapEventToMap(event);
          _responseController.add(response);

          final type = response['type'];

          if (type == 'PEER_CONNECTED') {
            _addConnectedPeer(response);
          } else if (type == 'PEER_DISCONNECTED') {
            _removeConnectedPeer(response);
          } else if (type == 'WIFI_DIRECT_REQ') {
            // Not currently sent by Rust, but kept for future/legacy
            _handleWiFiDirectRequest();
          } else if (type == 'SESSION_CODE_GENERATED') {
            debugPrint('🔗 Session Code Generated: ${response['code']}');
          } else if (type == 'SIGNALING_STARTED') {
            debugPrint('📡 MFR Signaling started for: ${response['id']}');
          } else if (type == 'PEER_DISCOVERED') {
            _addDiscoveredPeer(response);
          } else if (type == 'PEER_DISCOVERY_CARD') {
            // Handling mesh introductions if mapped
            _handleMeshIntroduction(response);
          } else if (type == 'RECEIVE_STARTED') {
            debugPrint('📥 Incoming transfer started from: ${response['ip']}');
          } else if (type == 'INCOMING_CHAT') {
            // Already saved by Rust backend in new version
            _chatController.add(response);
            _incrementUnread(response['ip']);
          } else if (type == 'FILE_OFFER') {
            final peerIp = response['ip'] ?? 'Broadcast';
            StorageService().saveMessage(
              peerIp: peerIp,
              text: '📎 Incoming file: ${response['file_name']}',
              isMe: false,
              type: 'file_offer',
              extra: {
                'file_name': response['file_name'],
                'file_size': response['file_size'],
                'offer_id': response['offer_id'],
              },
            );
            _fileOfferController.add(response);
            _incrementUnread(response['ip'], isTransfer: true);
          } else if (type == 'TRANSFER_REJECTED') {
            debugPrint('❌ File transfer rejected by peer');
          } else if (type == 'TRANSFER_COMPLETE') {
            debugPrint('✅ Transfer complete: ${response['transfer_id']}');
          } else if (type == 'QR_PAYLOAD_GENERATED') {
            debugPrint('📱 QR Payload Generated');
          }
          // Note: TRANSFER_PROGRESS is forwarded via _responseController automatically
        } catch (e) {
          debugPrint('❌ Error mapping/handling FRB event: $e');
        }
      },
      onError: (error) {
        debugPrint('❌ FRB Event Stream error: $error');
      },
    );
  }

  /// Maps typed DaemonEvent to legacy `Map<String, dynamic>`
  Map<String, dynamic> _mapEventToMap(DaemonEvent event) {
    return event.when(
      peerDiscovered: (peerId, name, ip, port) => {
        'type': 'PEER_DISCOVERED',
        'id': peerId,
        'name': name,
        'ip': ip,
        'port': port,
      },
      peerLost: (peerId) => {
        'type': 'PEER_DISCONNECTED', // Mapping loss to disconnected for UI
        'id': peerId,
      },
      transferProgress: (transferId, bytesTransferred, totalBytes, speed) => {
        'type': 'TRANSFER_PROGRESS',
        'transfer_id': transferId,
        'bytes_transferred': bytesTransferred.toInt(),
        'total_bytes': totalBytes.toInt(),
        'speed': speed,
      },
      transferComplete: (transferId, status) => {
        'type': 'TRANSFER_COMPLETE',
        'transfer_id': transferId,
        'status': status,
      },
      pairingRequest: (peerId, pin) => {
        'type': 'PAIRING_REQUEST',
        'peer_id': peerId,
        'pin': pin,
      },
      transferOffer: (peerId, transferId, fileName, fileSize, thumbnail) => {
        'type': 'FILE_OFFER',
        'ip': peerId, // Mapping peerId to ip/id for consistency with old code
        'peer_id': peerId,
        'offer_id': transferId,
        'file_name': fileName,
        'file_size': fileSize,
        'thumbnail': thumbnail,
      },
      logMessage: (level, message) {
        if (level == 'CHAT') {
          return {
            'type': 'INCOMING_CHAT',
            'text': message,
            'ip': 'Unknown',
            'unread': true,
          };
        }
        return {'type': 'LOG_MESSAGE', 'level': level, 'message': message};
      },
      credentialsGenerated: (pin, sessionKey) => {
        'type': 'CREDENTIALS_GENERATED',
        'pin': pin,
        'session_key': sessionKey,
      },
      qrPayloadGenerated: (payloadJson) => {
        'type': 'QR_PAYLOAD_GENERATED',
        'payload_json': payloadJson,
      },
      settingReported: (key, value) => {
        'type': 'SETTING_REPORTED',
        'key': key,
        'value': value,
      },
      sessionCodeGenerated: (code) => {
        'type': 'SESSION_CODE_GENERATED',
        'code': code,
      },
      signalingStarted: (id) => {'type': 'SIGNALING_STARTED', 'id': id},
      codeGenerated: (key, pin, ip) => {
        'type': 'CODE_GENERATED',
        'key': key,
        'pin': pin,
        'ip': ip,
      },
      peerDisconnected: (peerId) => {'type': 'PEER_DISCONNECTED', 'id': peerId},
      peerConnected: (peerId, name, address, port) => {
        'type': 'PEER_CONNECTED',
        'id': peerId,
        'name': name,
        'ip': address,
        'port': port,
      },
      incomingChat: (peerId, text) => {
        'type': 'INCOMING_CHAT',
        'ip': peerId, // ip field used for peer identification in legacy UI
        'text': text,
        'unread': true,
      },
    );
  }

  /// Start discovering peers on the network
  Future<void> startDiscovery() async {
    if (!_frbInitialized) {
      debugPrint('⚠️ Skipping startDiscovery: FRB not initialized');
      return;
    }

    await rust_api.startDiscovery(); // FRB

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
    if (!_frbInitialized) return;

    await rust_api.stopDiscovery(); // FRB
    _discoveryTimer?.cancel();
    if (Platform.isIOS) {
      await MpcBridge.stopMpc();
    }
  }

  Future<void> _pollNativePeers() async {
    try {
      final wifiPeers = await WiFiDirectBridge.getPeers();
      for (final p in wifiPeers) {
        _emitNativePeer(p, 'wifi-direct', 5052);
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
      'ip': peer['id'],
      'name': peer['name'] ?? 'Unknown Peer',
      'port': port,
      'protocol': type,
      'is_native': true,
    });
  }

  /// Generate a secure AES encryption key for QR handshake
  Future<String> generateCode() async {
    final completer = Completer<String>();

    final subscription = responses.listen((response) {
      if (response['type'] == 'CODE_GENERATED') {
        completer.complete(response['key'] as String);
      } else if (response['type'] == 'ERROR') {
        completer.completeError(response['error'] ?? 'Unknown error');
      }
    });

    try {
      await rust_api.generateCode(); // FRB
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }

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

    final subscription = responses.listen((response) async {
      if (response['type'] == 'CODE_GENERATED') {
        String ip = response['ip'] as String? ?? '127.0.0.1';

        if (ip == '127.0.0.1' || ip == 'localhost' || ip == '::1') {
          final localIp = await _getLocalIp();
          if (localIp != null) ip = localIp;
        }

        completer.complete({
          'key': response['key'] as String,
          'pin': response['pin'] as String? ?? '',
          'ip': ip,
        });
      }
    });

    try {
      await rust_api.generateCode();
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }

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
    final subscription = responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED') {
        completer.complete();
      }
    });

    await rust_api.joinSession(pin: pin); // FRB

    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timed out'),
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
      }
    });

    await rust_api.generateQrPayload(); // FRB

    try {
      final payload = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('QR payload generation timed out'),
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
      }
    });

    await rust_api.generateSessionCode(); // FRB

    try {
      final code = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Session code generation timed out'),
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
      }
    });

    await rust_api.joinSessionCode(text: code); // FRB

    try {
      final status = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Session joining timed out'),
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
    // Store as setting for easy retrieval
    await rust_api.setSettings(key: 'device_name', text: name);
    // Also notify backend logic
    await rust_api.setDeviceName(name: name);
  }

  /// Connect to a peer using the scanned code/IP (Universal Join)
  Future<void> connectToPeer(String code, {String? key}) async {
    final completer = Completer<void>();

    final subscription = responses.listen((response) {
      if (response['type'] == 'PEER_CONNECTED') {
        if (!completer.isCompleted) completer.complete();
      }
    });

    try {
      // 1. Try to parse as JSON (Smart QR Payload)
      if (code.trim().startsWith('{')) {
        try {
          final Map<String, dynamic> payload = jsonDecode(code);
          final List<dynamic> addrs = payload['addrs'] ?? [];
          final int port = payload['port'] ?? 5051;
          final String? key = payload['key'];

          if (addrs.isEmpty) {
            throw Exception('Invalid Smart QR: No addresses found');
          }

          debugPrint('🧠 Smart QR: Connecting to ${addrs.length} addresses...');

          // Attempt to connect to ALL advertised addresses
          // The mesh orchestrator will handle deduplication
          for (final rawAddr in addrs) {
            String addr = rawAddr.toString();

            // Wrap IPv6 in brackets if not already wrapped
            if (addr.contains(':') && !addr.startsWith('[')) {
              addr = '[$addr]';
            }

            final String connectString = '$addr:$port|${key ?? ""}';
            debugPrint('Trying to connect: $connectString'); // Added logging
            await rust_api.joinSessionCode(text: connectString);
          }
        } catch (e) {
          debugPrint('❌ Failed to parse Smart QR JSON: $e');
          // Fallback to raw string just in case
          await rust_api.joinSessionCode(text: code);
        }
      } else {
        // 2. Legacy/Manual Logic (IP|Key or PIN)
        String finalCode = code;
        if (key != null && !code.contains('|')) {
          finalCode = '$code|$key';
        }
        await rust_api.joinSessionCode(text: finalCode);
      }

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Don't throw if we are just starting to connect to multiple IPs,
          // but do throw if absolutely nothing happened.
          // actually, for UI feedback, timeout is good.
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
    await rust_api.sendMessage(peerId: peerIp, text: text);
  }

  /// Alias for sendChat to maintain backward compatibility
  Future<void> sendMessage(String peerIp, String text) =>
      sendChat(peerIp, text);

  /// Broadcast a chat message to all connected peers (Host only)
  Future<void> broadcastChat(String text) async {
    debugPrint('❌ BROADCAST_CHAT not implemented in Rust backend yet.');
  }

  /// Get message history for a peer
  Future<List<Map<String, dynamic>>> getMessages(String peerIp) async {
    return await StorageService().getHistory(peerIp);
  }

  /// Close the connection to the daemon
  Future<void> disconnect() async {
    debugPrint('🔌 Stopping Hydra Muscle engine...');
    await rust_api.stopEngine();
    _isConnected = false;
    debugPrint('✅ Engine stopped');
  }

  /// Mark messages from a peer as read
  Future<void> markAsRead(String peerIdOrIp) async {
    await rust_api.markMessagesRead(peerId: peerIdOrIp); // FRB
    final index = _connectedPeers.indexWhere(
      (p) => (p['id'] ?? p['ip']) == peerIdOrIp,
    );
    if (index != -1) {
      // Only clear chat unread count
      _connectedPeers[index]['chat_unread'] = 0;
      _recalcTotalUnread(index);
    }
  }

  void _incrementUnread(String? idOrIp, {bool isTransfer = false}) {
    if (idOrIp == null) return;
    final index = _connectedPeers.indexWhere(
      (p) => (p['id'] ?? p['ip']) == idOrIp,
    );
    if (index != -1) {
      if (isTransfer) {
        final current = _connectedPeers[index]['transfer_unread'] ?? 0;
        _connectedPeers[index]['transfer_unread'] = current + 1;
      } else {
        final current = _connectedPeers[index]['chat_unread'] ?? 0;
        _connectedPeers[index]['chat_unread'] = current + 1;
      }
      _recalcTotalUnread(index);
    }
  }

  void _decrementTransferUnread(String? idOrIp) {
    if (idOrIp == null) return;
    final index = _connectedPeers.indexWhere(
      (p) => (p['id'] ?? p['ip']) == idOrIp,
    );
    if (index != -1) {
      final current = _connectedPeers[index]['transfer_unread'] ?? 0;
      if (current > 0) {
        _connectedPeers[index]['transfer_unread'] = current - 1;
        _recalcTotalUnread(index);
      }
    }
  }

  void _recalcTotalUnread(int index) {
    final chat = _connectedPeers[index]['chat_unread'] ?? 0;
    final transfer = _connectedPeers[index]['transfer_unread'] ?? 0;
    _connectedPeers[index]['unread_count'] = chat + transfer;
    _connectedPeersController.add(currentPeers);
  }

  void _handleMeshIntroduction(Map<String, dynamic> card) {
    // Logic kept from old service
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
    final id = peer['id'] ?? peer['ip'];
    if (id == null) return;

    _discoveredPeers.removeWhere((p) => (p['id'] ?? p['ip']) == id);
    _discoveredPeersController.add(currentDiscoveredPeers);

    final index = _connectedPeers.indexWhere((p) => (p['id'] ?? p['ip']) == id);

    if (index != -1) {
      _connectedPeers[index] = {..._connectedPeers[index], ...peer};
    } else {
      _connectedPeers.add(peer);
    }
    _connectedPeersController.add(currentPeers);
  }

  void _addDiscoveredPeer(Map<String, dynamic> peer) {
    final id = peer['id'] ?? peer['ip'];
    if (id == null) return;

    final isConnected = _connectedPeers.any((p) => (p['id'] ?? p['ip']) == id);
    if (isConnected) return;

    final index = _discoveredPeers.indexWhere(
      (p) => (p['id'] ?? p['ip']) == id,
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
    final id = peer['id'] ?? peer['ip'];
    if (id != null) {
      _connectedPeers.removeWhere((p) => (p['id'] ?? p['ip']) == id);
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
    rust_api.stopEngine();
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
  Future<void> sendFile(String peerId, String filePath) async {
    await rust_api.sendFile(peerId: peerId, filePath: filePath);
  }

  /// Accept a file offer
  Future<void> acceptFile(
    String offerId,
    String peerId,
    BigInt fileSize,
  ) async {
    final downloadDir = await getApplicationDocumentsDirectory();
    final destPath = p.join(downloadDir.path, 'downloaded_file');

    _decrementTransferUnread(peerId);

    await rust_api.acceptFile(
      offerId: offerId,
      peerId: peerId,
      fileSize: fileSize,
      destPath: destPath,
    );
  }

  /// Reject a file offer
  Future<void> rejectFile(String offerId, String peerId) async {
    _decrementTransferUnread(peerId);
    await rust_api.rejectFile(offerId: offerId, peerId: peerId);
  }

  /// Cancel an active transfer
  Future<void> cancelTransfer(String transferId) async {
    await rust_api.cancelTransfer(transferId: transferId);
  }

  /// Admin: Disconnect a peer (Kick)
  Future<void> disconnectPeer(String ip) async {
    await rust_api.disconnectPeer(peerId: ip);
  }

  /// Admin: Ban a peer (Block IP)
  Future<void> banPeer(String ip) async {
    debugPrint('❌ BAN_PEER not implemented in Rust backend yet.');
  }

  /// Admin: Mute or Unmute a peer
  Future<void> mutePeer(String ip, bool mute) async {
    debugPrint('❌ MUTE_PEER not implemented in Rust backend yet.');
  }

  /// Settings: Set Max File Size
  Future<void> setMaxFileSize(int bytes) async {
    await rust_api.setSettings(key: 'max_file_size', text: bytes.toString());
  }

  /// Settings: Get a setting value
  Future<String> getSetting(String key) async {
    final completer = Completer<String>();
    final subscription = responses.listen((response) {
      if (response['type'] == 'SETTING_REPORTED' && response['key'] == key) {
        completer.complete(response['value'] as String);
      }
    });

    await rust_api.getSettings(key: key);

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
