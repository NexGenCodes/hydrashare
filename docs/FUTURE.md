# Future Enhancements Roadmap

This document tracks prioritized features for future implementation, ordered by importance.

## 🚧 Tier 2: Active Development (Phase 19 - Production Hardening)

Critical improvements needed before public release:

- **TURN Relay Deployment**: Self-hosted TURN servers for NAT traversal (currently relying on Google STUN only).
- **Error Recovery**: Robust reconnection logic for network failures mid-transfer.
- **Mobile Battery Optimization**: Real-world testing and tuning of adaptive throttling on iOS/Android.
- **Automated CI/CD**: Cross-platform build automation (Windows/macOS/Linux/Android/iOS).
- **User-Facing Metrics**: Expose connection quality, transfer speed, and system health to UI.

## ✨ Tier 3: Enhanced Mesh Capabilities

Features that directly impact the user experience and transfer speed.

### UX Improvements

- [ ] **Rich Notifications**: Progress bars in system notifications.
- [ ] **Transfer History**: Searchable history database.
- [ ] **File Preview**: Thumbnail generation before accepting.
- [ ] **Completion Sounds**: Audio feedback.

### Performance

- [ ] **Multipath QUIC (Draft)**: Future-proofing with experimental RFC 9221/9222 support.

## 📱 Tier 4: Mobile & Privacy Enhancements

Optimizations for mobile constraints and user privacy.

### Mobile-Specific

- [ ] **Background Scheduling**: Queue large transfers for WiFi-only.
- [ ] **Data Usage Controls**: Warnings for cellular transfers.

### Privacy

- [ ] **Incognito Mode**: Ephemeral pairing that doesn't save to the DB.
- [ ] **Metadata Minimization**: Hide transfer exact sizes/times from traffic analysis.

## 🔮 Tier 5: Strategic Goals (Long Term)

Major architectural shifts or platform expansions.

### Web & Cloud

- [ ] **WebRTC Gateway**: Browser-based transfers without app installation.
- [ ] **Public Volunteer Relays**: Trustless relay nodes for global connectivity.
- [ ] **Account System**: Optional keysync for multi-device owners.
- [ ] **Decentralized ID (DID)**: Self-sovereign identity verification.

---

## ✅ Completed Milestones

- **Pure Rust Engine Migration**: Successfully decommissioned the legacy Go daemon and ported all functionality (Discovery, Mesh, Auth, Transfer) to a unified Rust engine (`hydra_muscle`).
- **Hybrid QR/PIN Pairing**: Native multi-IP JSON QR handshake and secure PIN pairing implemented in the Rust core.
- **Direct FFI Command API**: 100% JSON-based (moving to binary) FFI bridge between Flutter and Rust, eliminating the Go layer.
- **Thread-Safe Engine Orchestration**: Introduced `EngineState` and `Database` wrappers using Rust's safety model to manage multi-threaded networking.
- **SQLite Optimization**: Migrated all persistence to high-performance SQLite via `rusqlite` with WAL mode and targeted indexing.
- **Cross-Platform Build System**: Standardized PowerShell and Bash scripts for native Rust builds on Windows and Android (NDK).
- **Long Distance Transfers (LDT)**: Implemented STUN-based public IP discovery and a direct UDP signaling relay for WAN-to-WAN connectivity.
- **Adaptive Connectivity (Multi-Path)**: Implemented "Happy Eyeballs" parallel dialing across LAN, USB, and Hotspot interfaces with automatic scoring and prioritization.
- **Bluetooth Signaling Fallback**: Integrated a WinSock RFCOMM transport as a low-level control plane for signaling when IP connectivity is lost.
- **Zero-Copy Binary FFI**: Migrated FFI communication to `rkyv` for high-performance, nanosecond-range cross-process serialization.
- **Post-Quantum Security (PQE)**: Integrated `aws-lc-rs` for hybrid Kyber/X25519 key exchange, protecting against quantum decrypt-later attacks.
- **Delta-Sync Protocol**: Implemented block-level transfers (rsync-style) with SHA-256 chunk hashing for efficient resumption and updates.
- **Authenticated Signaling**: Implemented HMAC-SHA256 signature verification for signaling payloads using SPAKE2 session keys, preventing MITM attacks during pairing.
- **Dynamic Port Binding**: Refactored Orchestrator to bind to random available ports and propagate the port dynamically via mDNS/Signaling, eliminating hardcoded port conflicts.
- **Parallel Chunk Transfers**: Simultaneous multi-stream Quinn implementation for massive throughput gains.
- **Adaptive Compression**: Integrated Zstd on-the-fly compression for text-based assets while skipping pre-compressed media.
- **Asynchronous Disk Assembly**: High-performance chunked file assembly using non-blocking I/O and atomic progress tracking.
- **Send-Compliant Quinn Core**: Full refactor of the QUIC transport layer to ensure thread-safety and compatibility with multi-threaded runtimes.
- **Connection Bonding**: Multi-path QUIC implementation aggregating WiFi + Ethernet + Cellular bandwidth for maximum throughput.
- **BBR Congestion Control**: Integrated Google's BBR (Bottleneck Bandwidth and Round-trip time) for superior performance on high-latency/lossy links.
- **System Intelligence (Smarts)**: Integrated `sysinfo` for real-time battery, thermal, and CPU monitoring.
- **Adaptive Throttling**: Automatic transfer scaling based on device health (Heat/Battery/Resource pressure).
- **Dijkstra-Lite Pathfinding**: Dynamic link scoring based on RTT, packet loss, and link type (WiFi vs Ethernet vs Hotspot).
- **Smart Mesh Forwarding**: Implemented multi-hop signaling and chat relaying, enabling communication through restricted NATs.
- **Cooperative Health**: Neighbors share system health via smart heartbeats to optimize network-wide energy usage.
- **Async Connection Timing Fix**: Implemented robust polling logic for multi-hop connection verification, ensuring test reliability.

---

## 📋 Long-Term Feature Roadmap

### Phase 20: Multi-User Collaborative Folders

- Real-time folder synchronization across mesh peers
- Conflict resolution for simultaneous edits
- Selective sync and bandwidth management

### Phase 21: Browser-Based Lightweight Client

- WebAssembly build of core transfer engine
- WebRTC data channels for browser-to-native transfers
- Progressive Web App for installation-free access

### Phase 22: Decentralized Discovery (DHT)

- Distributed hash table for global peer registry
- Zero-trust relay selection via reputation system
- End-to-end encrypted metadata exchange
