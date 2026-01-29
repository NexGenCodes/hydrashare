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

  static void startDaemon() {
    if (_lib == null) return;

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
