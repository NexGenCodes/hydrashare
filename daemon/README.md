# HydraShare Engine (Rust)

High-performance file transfer engine for the HydraShare project, powered by Rust (`hydra_muscle`).

## Structure

- **hydra_muscle**: Main Rust library implementing:
  - `auth`: 6-digit PIN pairing with PBKDF2-HMAC-SHA256.
  - `core`: Engine lifecycle and thread-safe state management.
  - `db`: Persistence layer using SQLite (via `rusqlite`).
  - `discovery`: mDNS-based local network peer discovery.
  - `mesh`: P2P signaling, heartbeats, and G2G orchestration.
  - `quic`: Encrypted high-speed data plane using `quinn`.
  - `ffi`: JSON-based command API for Flutter integration.

- **bin**: Compiled artifacts (libraries and standalone test binaries).

## Getting Started

### Prerequisites

- Rust (Latest stable)
- C Compiler (MSVC on Windows, GCC/Clang elsewhere)

### Building

Use the scripts in the project root's `scripts/` directory, or compile directly with Cargo:

```bash
cd hydra_muscle
cargo build --release --target x86_64-pc-windows-gnu
```

### Standalone Daemon

You can run a standalone test daemon if needed:

```bash
cargo run --bin hydra_daemon
```

## FFI API Commands

The engine receives JSON commands via the `send_command` FFI function:

- `INIT`: `{"type": "INIT", "data_dir": "..."}`
- `START_ENGINE`: `{"type": "START_ENGINE"}`
- `GENERATE_CREDENTIALS`: `{"type": "GENERATE_CREDENTIALS"}`
- `SEND_FILE`: `{"type": "SEND_FILE", "file_path": "...", "dest_ip": "..."}`

## Security

HydraShare uses a zero-config security model:

1. **Identity**: Each device generates a persistent Ed25519 keypair.
2. **Channel**: All communication is encrypted via TLS 1.3 (QUIC default).
3. **Pairing**: Out-of-band PIN verification prevents MITM during initial introduction.
