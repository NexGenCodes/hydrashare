import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service class for managing persistent TCP connection to Go daemon
class DaemonService {
  Socket? _socket;
  final String host;
  final int port;
  bool _isConnected = false;

  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of responses from the daemon
  Stream<Map<String, dynamic>> get responses => _responseController.stream;

  /// Check if currently connected to daemon
  bool get isConnected => _isConnected;

  DaemonService({this.host = 'localhost', this.port = 5050});

  /// Connect to the Go daemon and start listening for responses
  Future<void> connect() async {
    try {
      debugPrint('🔌 Connecting to Go daemon at $host:$port...');

      _socket = await Socket.connect(host, port);
      _isConnected = true;

      debugPrint('✅ Connected to Go daemon');

      // Listen for responses from the daemon
      _socket!.listen(
        (List<int> data) {
          final message = utf8.decode(data).trim();
          debugPrint('📥 Received from daemon: $message');

          try {
            final response = jsonDecode(message) as Map<String, dynamic>;
            _responseController.add(response);
          } catch (e) {
            debugPrint('❌ Error parsing response: $e');
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
    } catch (e) {
      debugPrint('❌ Failed to connect: $e');
      _isConnected = false;
      rethrow;
    }
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

  /// Close the connection to the daemon
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting from daemon...');

    await _socket?.close();
    _socket = null;
    _isConnected = false;

    debugPrint('✅ Disconnected');
  }

  /// Clean up resources
  void dispose() {
    _responseController.close();
    _socket?.destroy();
  }
}
