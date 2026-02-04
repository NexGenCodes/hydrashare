import 'dart:async';
import 'package:flutter/services.dart';

/// Bridge for iOS Multipeer Connectivity
class MpcBridge {
  static const platform = MethodChannel('com.hydrashare/mpc');

  static final _peerController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get peerFound => _peerController.stream;

  static bool _isInitialized = false;

  static void _init() {
    if (_isInitialized) return;
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onPeerFound') {
        final args = Map<String, dynamic>.from(call.arguments);
        _peerController.add(args);
      }
    });
    _isInitialized = true;
  }

  /// Start advertising and browsing for peers
  static Future<void> startMpc() async {
    _init();
    try {
      await platform.invokeMethod('startMPC');
    } on PlatformException catch (e) {
      print('MPC Start failed: ${e.message}');
    }
  }

  /// Stop advertising and browsing
  static Future<void> stopMpc() async {
    try {
      await platform.invokeMethod('stopMPC');
    } on PlatformException catch (_) {
      // Ignore
    }
  }

  /// Send data to a peer (Not yet fully implemented on Swift side)
  static Future<void> sendData(String peerId, List<int> data) async {
    try {
      await platform.invokeMethod('sendData', {'peerId': peerId, 'data': data});
    } on PlatformException catch (e) {
      print('MPC Send failed: ${e.message}');
    }
  }
}
