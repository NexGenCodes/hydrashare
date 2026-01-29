# HydraShare Daemon

High-performance file transfer daemon for the HydraShare project, powered by Go and a Rust core (`hydra_muscle`).

## Structure

- `cmd/hydra_daemon`: Entry point and JSON command handler.
- `internal/transfer`: Core transfer management logic and CGo bindings.
- `hydra_muscle`: Rust implementation of platform-specific fast I/O (sendfile/TransmitFile).
- `scripts`: Automation and testing scripts.
- `bin`: Compiled binaries and libraries.
- `testdata`: Local test files.

## Getting Started

### Prerequisites

- Go 1.25+
- Rust (Cargo)
- C Compiler (GCC/MSVC)

### Building

Use the provided PowerShell script:

```powershell
.\scripts\build.ps1
```

This will compile the Rust core and the Go daemon into the `bin/` directory.

### Running Tests

1. **Start the Daemon**:

    ```powershell
    .\bin\hydra_daemon.exe
    ```

2. **Start the Receiver** (in another terminal):

    ```powershell
    .\scripts\test_receive.ps1
    ```

3. **Trigger a Transfer**:

    ```powershell
    .\scripts\test_trigger.ps1
    ```

## API Commands

The daemon listens on `localhost:5050` for JSON commands:

- `START_TRANSFER`: `{"type": "START_TRANSFER", "file_path": "...", "dest_ip": "..."}`
- `CANCEL_TRANSFER`: `{"type": "CANCEL_TRANSFER", "transfer_id": "..."}`
- `ping`: `{"type": "ping"}`
