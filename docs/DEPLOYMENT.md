# HydraShare Deployment Guide

## Desktop (Windows, macOS, Linux)

HydraShare on desktop uses a native Flutter frontend communicating with a standalone Go daemon executable.

### 1. Build the Daemon

First, compile the Go daemon for your target platform.

**Windows:**

```powershell
cd daemon/cmd/hydra_daemon
$env:GOOS="windows"
go build -o ../../../hydra_daemon.exe .
```

**macOS:**

```bash
cd daemon/cmd/hydra_daemon
GOOS=darwin go build -o ../../../hydra_daemon .
```

**Linux:**

```bash
cd daemon/cmd/hydra_daemon
GOOS=linux go build -o ../../../hydra_daemon .
```

### 2. Build the Frontend

Build the Flutter application relative to the `frontend/` directory.

**Windows:**

```powershell
cd frontend
flutter build windows
```

*Artifact:* `frontend/build/windows/runner/Release/hydra_share.exe`

### 3. Packaging

**Crucial Step:** You must place the compiled daemon executable (`hydra_daemon.exe` or `hydra_daemon`) in the same directory as the Flutter application binary.

For Windows distribution:

1. Create a `release` folder.
2. Copy `frontend/build/windows/runner/Release/*` to `release/`.
3. Copy `hydra_daemon.exe` to `release/`.
4. Use an installer generator like Inno Setup to package this folder.

---

## Mobile (Android)

On Android, the Go daemon is compiled as a shared library (`libhydra_daemon.so`) and accessed via FFI.

### 1. Setup Go Mobile

If not already configured:

```bash
# This is usually handled by the flutter build process if configured, 
# but for manual NDK verification:
export ANDROID_NDK_HOME=/path/to/ndk
```

### 2. Build & Run

The build process is automated via Gradle and Flutter.

```bash
cd frontend
flutter build apk --split-per-abi
```

or to run:

```bash
flutter run
```

*Note:* `go_daemon_ffi.dart` handles the initialization of the shared library on Android startup.

## Mobile (iOS)

### 1. Build Go Library

You must compile the Go code into an `.xcframework`.

```bash
cd daemon
gomobile bind -target=ios -o ../frontend/ios/Runner/Frameworks/HydraDaemon.xcframework ./cmd/hydra_daemon
```

*(Note: Requires `gomobile` tools)*

### 2. Build Flutter App

```bash
cd frontend
flutter build ios
```
