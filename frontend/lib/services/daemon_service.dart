import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Stream of responses from the daemon
  Stream<Map<String, dynamic>> get responses => _responseController.stream;

  /// Stream of currently connected peers
  Stream<List<Map<String, dynamic>>> get connectedPeers =>
      _connectedPeersController.stream;

  /// Current list of connected peers
  List<Map<String, dynamic>> get currentPeers =>
      List.unmodifiable(_connectedPeers);

  /// Check if currently connected to daemon
  bool get isConnected => _isConnected;

  /// Connect to the Go daemon and start listening for responses
  Future<void> connect({int retries = 5}) async {
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
        return; // Success!
      } catch (e) {
        debugPrint('⏳ Connection attempt ${i + 1} failed. Retrying in 1s...');
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
    if (!_isConnected || _socket == null) {
      throw Exception('Not connected to daemon');
    }

    try {
      final jsonString = jsonEncode(command);
      debugPrint('📤 Sending to daemon: $jsonString');

      _socket!.write('$jsonString\n');
      await _socket!.flush();
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

  /// Connect to a peer using the scanned code/IP
  Future<void> connectToPeer(String code) async {
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
    // Assuming code is "ip:port" or just IP
    // If it's a token, we might need a different command, but for now assuming direct IP for dev
    await sendCommand({'type': 'CONNECT_PEER', 'dest_ip': code});

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

  /// Close the connection to the daemon
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting from daemon...');

    await _socket?.close();
    _socket = null;
    _isConnected = false;

    debugPrint('✅ Disconnected');
  }

  void _addConnectedPeer(Map<String, dynamic> peer) {
    // Avoid duplicates based on IP
    final ip = peer['ip'] ?? peer['dest_ip'];
    if (ip != null &&
        !_connectedPeers.any((p) => (p['ip'] ?? p['dest_ip']) == ip)) {
      _connectedPeers.add(peer);
      _connectedPeersController.add(currentPeers);
    }
  }

  void _removeConnectedPeer(Map<String, dynamic> peer) {
    final ip = peer['ip'] ?? peer['dest_ip'];
    if (ip != null) {
      _connectedPeers.removeWhere((p) => (p['ip'] ?? p['dest_ip']) == ip);
      _connectedPeersController.add(currentPeers);
    }
  }

  /// Clean up resources
  void dispose() {
    _responseController.close();
    _connectedPeersController.close();
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
}
