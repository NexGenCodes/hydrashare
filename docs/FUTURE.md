# Future Roadmap

This document outlines prioritized features and architectural improvements for HydraShare, ordered by their strategic importance to the codebase's stability, performance, and user experience.

## 🚀 Priority 1: High-Impact Infrastructure (Stability & Connectivity)

Critical technical improvements required for production-readiness.

- **Recursive Delta-Sync**: Block-level synchronization for entire directory structures (rsync-style) using the established SHA-256 chunking engine.
- **TURN Relay Deployment**: Implementation of self-hosted TURN servers to ensure 100% connectivity for peers behind restrictive symmetric NATs.
- **Automated Network Bonding**: Proactive aggregation of all available network interfaces (WiFi + Ethernet + Cellular) for maximum link utilization.
- **Robust Error Recovery**: Advanced session resumption logic for network migrations (e.g., switching from WiFi to Cellular mid-transfer).
- **Dynamic System Throttling**: Enhance `Intelligence` to monitor real battery levels and thermal sensors, dynamically scaling speeds to prevent overheating and power drain.
- **Mobile Battery Optimization**: fine-tuning adaptive throttling and system intelligence for aggressive OS backgrounding policies.

## 📡 Priority 2: Enhanced P2P Capabilities (Performance & Intelligence)

Features that leverage the Rust core to improve the sharing experience.

- **Streaming Media Preview**: Enable real-time playback of audio/video files while the transfer is still in progress.
- **Recursive Folder Transfers**: Implement directory tree traversal to support sending entire folders using the existing delta-sync/chunking engine.
- **Peer Trust Matrix**: Connection reliability scoring system that intelligently selects the fastest/most stable path based on historical RTT and packet loss.
- **Cooperative Health Expansion**: Enhanced neighborhood heartbeats to synchronize system resource allocation across the entire mesh.
- **Multipath QUIC (RFC 9221/9222)**: Future-proofing the transport layer with experimental support for aggregated stream reliability.

## 🎨 Priority 3: User Experience & Intelligence (Engagement)

Polishing the interface and adding smart interaction features.

- **User-Facing Metrics**: Real-time cockpit showing connection quality, throughput graphs, and system pressure (Thermal/CPU/Battery).
- **FFI Diagnostic Dashboard**: Expose internal Rust `Intelligence` metrics to the Flutter UI for detailed real-time monitoring of transfer health and system constraints.
- **Rich Notifications**: Native system-level press bars and interactive "Accept/Decline" actions for incoming file requests.
- **File Preview Generation**: Secure, sandboxed thumbnail generation for media files before a user accepts a transfer.

## 🔐 Priority 4: Privacy & Strategic Goals (Long Term)

Advanced security features and platform expansion.

- **Incognito Pairing**: Ephemeral sessions that leave no trace in the local database for high-privacy environments.
- **Metadata Minimization**: Traffic analysis protection by padding transfer sizes/timings.
- **WebRTC Gateway**: Enable browser-to-app transfers without installation via a WebAssembly build of the core engine.
- **Decentralized ID (DID)**: Self-sovereign identity verification for trustless global peer registries.

---

For implementations already completed, see [COMPLETED_MILESTONES.md](./COMPLETED_MILESTONES.md).
