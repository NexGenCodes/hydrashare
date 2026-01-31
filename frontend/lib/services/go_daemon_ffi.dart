import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef InitDaemonFunc = Void Function();
typedef InitDaemon = void Function();

typedef SendDaemonCommandFunc = Void Function(Pointer<Utf8>);
typedef SendDaemonCommand = void Function(Pointer<Utf8>);

class GoDaemonFfi {
  static DynamicLibrary? _lib;
  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      try {
        // Load the Rust dependency first
        DynamicLibrary.open('libhydra_muscle.so');
        _lib = DynamicLibrary.open('libhydra_daemon.so');
        _isInitialized = true;
        debugPrint('✅ Loaded Go Daemon and Hydra Muscle libraries via FFI');
      } catch (e) {
        debugPrint('❌ Failed to load libraries: $e');
      }
    }
  }

  static Future<void> startDaemon() async {
    if (_lib == null) return;

    // Check if daemon is already running (e.g. from previous hot restart)
    try {
      final socket = await Socket.connect(
        'localhost',
        5050,
        timeout: const Duration(milliseconds: 500),
      );
      debugPrint('ℹ️ Daemon already running on port 5050. Skipping init.');
      socket.destroy();
      return;
    } catch (e) {
      // Port is free (or at least not accepting connections), proceed with init
    }

    final initDaemon = _lib!
        .lookup<NativeFunction<InitDaemonFunc>>('InitDaemon')
        .asFunction<InitDaemon>();

    debugPrint('🚀 Initializing Go Daemon via FFI...');
    initDaemon();
  }

  static void sendCommand(String jsonCommand) {
    if (_lib == null) return;

    final sendCmd = _lib!
        .lookup<NativeFunction<SendDaemonCommandFunc>>('SendDaemonCommand')
        .asFunction<SendDaemonCommand>();

    final jsonPtr = jsonCommand.toNativeUtf8();
    try {
      sendCmd(jsonPtr);
    } finally {
      malloc.free(jsonPtr);
    }
  }
}
