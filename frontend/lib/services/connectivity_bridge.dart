import 'package:flutter/services.dart';

/// Platform channel for WiFi-Direct connectivity (Android only)
class WiFiDirectBridge {
  static const platform = MethodChannel('com.hydrashare/wifi_direct');

  /// Initiate WiFi-Direct connection to a peer
  static Future<bool> connectToPeer(String peerID) async {
    try {
      final result = await platform.invokeMethod('connectWiFiDirect', {
        'peerId': peerID,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('WiFi-Direct connection failed: ${e.message}');
      return false;
    }
  }

  /// Start WiFi-Direct discovery (results available via getPeers)
  static Future<void> startDiscovery() async {
    try {
      await platform.invokeMethod('startWiFiDirectDiscovery');
    } on PlatformException catch (_) {
      print('WiFi-Direct discovery failed');
    }
  }

  /// Get currently discovered WiFi-Direct peers
  static Future<List<Map<String, dynamic>>> getPeers() async {
    try {
      final result = await platform.invokeMethod('getWiFiDirectPeers');
      return List<Map<String, dynamic>>.from(result ?? []);
    } on PlatformException {
      return [];
    }
  }

  /// Check if WiFi-Direct is available on this device
  static Future<bool> isAvailable() async {
    try {
      final result = await platform.invokeMethod('isWiFiDirectAvailable');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}

/// Platform channel for Bluetooth connectivity
class BluetoothBridge {
  static const platform = MethodChannel('com.hydrashare/bluetooth');

  /// Initiate Bluetooth connection to a peer
  static Future<bool> connectToPeer(String peerID) async {
    try {
      final result = await platform.invokeMethod('connectBluetooth', {
        'peerId': peerID,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Bluetooth connection failed: ${e.message}');
      return false;
    }
  }

  /// Start Bluetooth discovery
  static Future<void> startDiscovery() async {
    try {
      await platform.invokeMethod('startBluetoothDiscovery');
    } on PlatformException catch (e) {
      print('Bluetooth discovery failed: ${e.message}');
    }
  }

  /// Get currently discovered Bluetooth peers
  static Future<List<Map<String, dynamic>>> getPeers() async {
    try {
      final result = await platform.invokeMethod('getBluetoothPeers');
      return List<Map<String, dynamic>>.from(result ?? []);
    } on PlatformException {
      return [];
    }
  }

  /// Check if Bluetooth is available and enabled
  static Future<bool> isAvailable() async {
    try {
      final result = await platform.invokeMethod('isBluetoothAvailable');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
