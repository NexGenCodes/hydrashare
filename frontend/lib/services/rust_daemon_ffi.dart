import 'dart:ffi';
import 'dart:io';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef StartEngineFunc = Int32 Function(Pointer<Utf8>);
typedef StartEngine = int Function(Pointer<Utf8>);

typedef StopEngineFunc = Void Function();
typedef StopEngine = void Function();

typedef PollEventFunc = Pointer<Utf8> Function();
typedef PollEvent = Pointer<Utf8> Function();

typedef FreeStringFunc = Void Function(Pointer<Utf8>);
typedef FreeString = void Function(Pointer<Utf8>);

typedef SendCommandFunc = Int32 Function(Pointer<Utf8>);
typedef SendCommand = int Function(Pointer<Utf8>);

class HydraMuscleFfi {
  static DynamicLibrary? _lib;
  static bool _isInitialized = false;
  static Timer? _eventTimer;
  static final _eventController = StreamController<String>.broadcast();

  static Stream<String> get events => _eventController.stream;

  static void init() {
    if (_isInitialized) return;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libhydra_muscle.so');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('hydra_muscle.dll');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libhydra_muscle.dylib');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      }

      if (_lib != null) {
        _isInitialized = true;
        debugPrint('✅ Loaded Hydra Muscle library via FFI');
        _startPolling();
      }
    } catch (e) {
      debugPrint('❌ Failed to load Hydra Muscle library: $e');
    }
  }

  static int startEngine(String dbPath) {
    if (_lib == null) return -1;

    final start = _lib!
        .lookup<NativeFunction<StartEngineFunc>>('start_engine')
        .asFunction<StartEngine>();

    final pathPtr = dbPath.toNativeUtf8();
    try {
      return start(pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  static int sendCommand(String json) {
    if (_lib == null) return -1;

    final send = _lib!
        .lookup<NativeFunction<SendCommandFunc>>('send_command')
        .asFunction<SendCommand>();

    final jsonPtr = json.toNativeUtf8();
    try {
      return send(jsonPtr);
    } finally {
      malloc.free(jsonPtr);
    }
  }

  static void stopEngine() {
    if (_lib == null) return;
    _eventTimer?.cancel();

    final stop = _lib!
        .lookup<NativeFunction<StopEngineFunc>>('stop_engine')
        .asFunction<StopEngine>();
    stop();
  }

  static void _startPolling() {
    _eventTimer?.cancel();
    _eventTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _poll();
    });
  }

  static void _poll() {
    if (_lib == null) return;

    final poll = _lib!
        .lookup<NativeFunction<PollEventFunc>>('poll_event')
        .asFunction<PollEvent>();

    final freeStr = _lib!
        .lookup<NativeFunction<FreeStringFunc>>('free_string')
        .asFunction<FreeString>();

    final eventPtr = poll();
    if (eventPtr.address != 0) {
      final eventJson = eventPtr.toDartString();
      _eventController.add(eventJson);
      freeStr(eventPtr);
    }
  }
}
