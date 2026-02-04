import 'dart:async';

/// Mock implementation of HydraMuscleFfi for testing without native library
class MockHydraMuscleFfi {
  static final StreamController<String> _eventController =
      StreamController.broadcast();
  static Stream<String> get events => _eventController.stream;

  static void init() {
    // No-op
  }

  static int startEngine(String dbPath) {
    return 0; // Success
  }

  static void stopEngine() {
    // No-op
  }

  static void sendCommand(String jsonCommand) {
    // Echo back a success response or mock behavior based on command
    if (jsonCommand.contains("START_DISCOVERY")) {
      // Simulate finding a peer
      _eventController.add(
        '{"type": "PEER_DISCOVERED", "ip": "192.168.1.50", "name": "Mock Peer", "port": 5051}',
      );
    }
  }
}
