# Connection Lifecycle

This document describes the state machine and lifecycle of a peer connection in HydraShare.

## State Machine

```mermaid
state_machine
    [*] --> Discovered
    Discovered --> Connecting : Start Handshake
    Connecting --> Connected : QUIC Est / Auth Started
    Connected --> Authenticated : SPAKE2 / PIN Verified
    Authenticated --> Active : Session Ready
    Active --> Disconnected : Timeout / Closed
    Disconnected --> [*]
```

## State Definitions

| State | Description |
| :--- | :--- |
| **Discovered** | Peer found via mDNS or manual IP entry. Only basic metadata (ID, Name, IP) is known. |
| **Connecting** | Transport layer (QUIC) is attempting to establish a secure stream. |
| **Connected** | Secure transport is established. The daemon is now performing authentication (SPAKE2/PIN). |
| **Authenticated** | Peer identity is verified. Ready to exchange commands, chat, and file offers. |
| **Active** | Connection is fully established and actively used. |
| **Disconnected** | Connection closed gracefully or due to timeout/error. |

## Parameter Standardization

We standardize on `peer_id` (HydraID) as the primary identifier for all API calls.

* **Rust**: Use `peer_id` in `DaemonCommand` and `MeshMessage`.
* **Dart**: Use `peerId` in service methods.
* **IP Addresses**: Treated as transient attributes used for initial dialing, but never as the primary key for a peer.
