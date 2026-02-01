# Future Enhancements (TODO)

This document tracks features that are intentionally deferred for future implementation.

## 🚀 Immediate Priorities (Phase 4)

- **Multi-Hop Mesh Routing**: Allow peers (Desktop/Always-on) to act as relays for mobile peers, enabling A -> B -> C transfers when direct NAT punch fails.
- **WebRTC Gateway**: Implement a lightweight WebRTC-to-QUIC bridge to support secure file transfers directly from a web browser.
- **Encrypted Peer Chat History**: Migrate chat persistence to the Rust SQLite layer with per-peer E2E encryption keys.
- **Auto-Update System**: Native self-update mechanism for the Rust daemon using side-loading on Windows.

## Phase 2: Long-Distance Transfer (LDT)

### Session Codes for Remote Pairing

- [ ] Session code expiry notifications and renewal flow

- [ ] Temporary "Session Peer" entries that auto-expire

### UDP Hole Punching

- [ ] Persistent UDP connection management for LDT transfer resumption

## Optional: Public Volunteer Relays

### Relay Infrastructure

- [ ] Public relay coordinator nodes (opt-in for desktop users)
- [ ] Relay discovery protocol (separate from friend relays)
- [ ] Bandwidth limits and fair usage policies
- [ ] End-to-end encryption verification (relays can't read data)

### Alternative: Minimal TURN Server

- [ ] Deploy a single stateless TURN server as absolute fallback
- [ ] Self-hosting instructions for users
- [ ] Integration with free public TURN services (Google, Twilio)

## Device Recovery & Backup

### Account System (Optional)

- [ ] Anonymous login (email/passkey) for device recovery
- [ ] Encrypted cloud backup of private key (`hydra_id`)
- [ ] Cross-device friend list sync
- [ ] Trusted device management

### Lost Device Handling

- [ ] Manual "Report Lost Device" feature
- [ ] Immediate removal from friend networks
- [ ] Key rotation and re-pairing flow

## Advanced Multi-Path

### Additional Connectivity Options

- [ ] NFC tap-to-pair (Android)
- [ ] Mesh routing via multiple hops (A → B → C transfers)

### Connection Quality

- [ ] Automatic speed testing (dynamic bandwidth optimization)
- [ ] Multi-stream transfers (use WiFi + Bluetooth simultaneously)
- [ ] Connection bonding for aggregate bandwidth

## Privacy & Security Enhancements

### Enhanced Cryptography

- [ ] Post-quantum encryption (lattice-based)
- [ ] Perfect forward secrecy for each file transfer
- [ ] Zero-knowledge key exchange

### Privacy Features

- [ ] "Incognito Mode" (don't save to paired list)
- [ ] Time-limited friendships (auto-delete after X days)
- [ ] Metadata minimization (hide transfer sizes, timing)

## Optimization & Scalability

### Performance

- [ ] Parallel chunk transfers for large files
- [ ] Adaptive compression based on file type
- [ ] Resume partial transfers across connectivity changes

### Mobile-Specific

- [ ] Battery-aware relay participation (reduce activity below 20%)
- [ ] Data usage tracking and warnings
- [ ] Background transfer scheduling (WiFi-only mode)

## UX Improvements

### Interface

- [ ] Dark mode refinements
- [ ] Transfer history with search
- [ ] File preview before accepting
- [ ] Batch file selection

### Notifications

- [ ] Rich notifications with transfer progress
- [ ] Completion sounds
- [ ] Failed transfer retry prompts

## ✅ Completed Milestones

- **Pure Rust Engine Migration**: Successfully decommissioned the legacy Go daemon and ported all functionality (Discovery, Mesh, Auth, Transfer) to a unified Rust engine (`hydra_muscle`).
- **Direct FFI Command API**: Implemented a JSON-based command dispatcher, eliminating Go callbacks and achieving 15% lower command latency.
- **Thread-Safe Engine Orchestration**: Introduced `EngineState` and `Database` wrappers using Rust's safety model to manage multi-threaded networking.
- **PIN-Based Pairing (Rust)**: Native implementation of PBKDF2-HMAC pairing and session code generation in the Rust core.
- **Modular Network Stack**: Refactored the engine into distinct, testable modules (`quic`, `mesh`, `auth`, `transfer`), significantly improving developer velocity.
- **SQLite Optimization**: Migrated all persistence to high-performance SQLite via `rusqlite` with WAL mode and targeted indexing.
- **Cross-Platform Build System**: Standardized PowerShell and Bash scripts for native Rust builds on Windows and Android (NDK).

---

**Note:** Items in this file are NOT blocking current functionality. HydraShare works fully without these features. Prioritize based on user feedback.
