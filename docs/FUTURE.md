# Future Enhancements (TODO)

This document tracks features that are intentionally deferred for future implementation.

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

- **Hybrid Rust-Go Architecture**: Seamless integration of Go for control logic and Rust for high-speed QUIC data planes.
- **FFI-Gate System**: Implemented blocking consent gates in FFI to allow Go to control Rust's socket reception.
- **Stealth Background Mode**: Secured the daemon as a silent background process on Windows by hiding child-process console windows.
- **Unified QUIC Transport**: Migrated entire control path (handshakes, heartbeats, signaling) from KCP to QUIC, creating a single unified protocol for all peer-to-peer communication.
- **QUIC Session Reuse**: Multi-file transfers to the same peer now reuse persistent QUIC sessions, reducing latency by 200-500ms per file.
- **KCP Removal**: Eliminated KCP dependency and complexity, simplifying codebase and NAT traversal.
- **Hardened QUIC Security**: Implemented HydraID-based certificate pinning and deterministic certificate generation, preventing MITM attacks across all platforms.
- **Type-Safe FFI Bridge**: Migrated all Go-Rust callbacks to `cgo.Handle`, ensuring memory safety and absolute stability of the cross-language interface.
- **QUIC 0-RTT Handshakes**: Implemented handshake resumption via persistent TLS tickets, achieving 0ms connection overhead for repeat peers.
- **Cross-Platform Parity**: Verified full daemon functionality and FFI parity on both Windows and Android (aarch64).
- **Vectored I/O Optimization**: Implemented single-syscall writes for encrypted QUIC chunks, maximizing throughput stability.
- **Technical Debt Elimination**: Resolved all persistent compiler warnings and `go vet` safety flags project-wide.
- **QUIC Connection Migration**: Enabled seamless WiFi→Cellular handoff via `ServerConfig::migration(true)`.
- **Full IPv6 Support**: All listeners use dual-stack `[::]` bindings for IPv6-ready networking.
- **Unit Test Suite**: Established foundational unit tests for Rust core (hashing, error mapping) and Go daemon (transfer logic, discovery).
- **iOS Platform Scaffolding**: Prepared build scripts, updated FFI bridge, and cleaned up iOS project structure for future macOS deployment.
- **Refactored Core Network Main Loop**: Slayed the "God Object" `quic.rs` by splitting it into modular components (`server.rs`, `client.rs`, `cert.rs`, `session.rs`), significantly improving maintainability and safety.
- **Zero-Latency FFI Bridge**: Replaced the legacy TCP/JSON bridge with a direct memory-mapped FFI layer, eliminating network stack overhead for local engine communication.
- **Database Performance Tuning**: Optimized SQLite storage with Write-Ahead Logging (WAL) and targeted indices for concurrent transfer tracking.
- **FFI Event Orchestration**: Implemented a thread-safe event queue in Rust with a non-blocking Dart poller for real-time UI updates.

---

**Note:** Items in this file are NOT blocking current functionality. HydraShare works fully without these features. Prioritize based on user feedback.
