# HydraShare Daemon API Documentation

The HydraShare daemon communicates with the frontend via a TCP connection (localhost:5050). Messages are newline-delimited JSON objects.

## Commands (Frontend -> Daemon)

### `ping`

Checks connection status.

```json
{ "type": "ping" }
```

### `SET_DEVICE_NAME`

Sets the visible name of the local device.

```json
{
  "type": "SET_DEVICE_NAME",
  "name": "My Device"
}
```

### `START_DISCOVERY`

Starts scanning for local peers.

```json
{ "type": "START_DISCOVERY" }
```

### `STOP_DISCOVERY`

Stops the peer scanner.

```json
{ "type": "STOP_DISCOVERY" }
```

### `GENERATE_CODE`

Generates a 6-digit PIN and encryption key for pairing.

```json
{ "type": "GENERATE_CODE" }
```

### `CONNECT_WITH_PIN`

Connects to a peer using their 6-digit PIN.

```json
{
  "type": "CONNECT_WITH_PIN",
  "key": "123456"
}
```

### `CONNECT_PEER`

Connects to a peer directly by IP (and optional key).

```json
{
  "type": "CONNECT_PEER",
  "dest_ip": "192.168.1.5",
  "key": "optional-key"
}
```

### `SEND_FILE`

Initiates a file transfer offer.

```json
{
  "type": "SEND_FILE",
  "file_path": "/path/to/file",
  "dest_ip": "192.168.1.5"
}
```

### `ACCEPT_FILE`

Accepts a specific file offer.

```json
{
  "type": "ACCEPT_FILE",
  "offer_id": "12345",
  "dest_ip": "192.168.1.5"
}
```

### `REJECT_FILE`

Rejects a file offer.

```json
{
  "type": "REJECT_FILE",
  "offer_id": "12345",
  "dest_ip": "192.168.1.5"
}
```

### `SEND_CHAT`

Sends a direct chat message.

```json
{
  "type": "SEND_CHAT",
  "dest_ip": "192.168.1.5",
  "text": "Hello!"
}
```

### `BROADCAST_CHAT`

Sends a message to all connected peers.

```json
{
  "type": "BROADCAST_CHAT",
  "text": "Hello everyone!"
}
```

### `SET_SETTINGS`

Updates daemon configuration.

```json
{
  "type": "SET_SETTINGS",
  "key": "max_file_size",
  "text": "104857600"
}
```

### Administration

- `DISCONNECT_PEER`: `{ "type": "DISCONNECT_PEER", "dest_ip": "..." }`
- `BAN_PEER`: `{ "type": "BAN_PEER", "dest_ip": "..." }`
- `MUTE_PEER`: `{ "type": "MUTE_PEER", "dest_ip": "...", "text": "true" }`

---

## Responses (Daemon -> Frontend)

### `pong`

Response to ping.

```json
{ "type": "pong", "status": "ready" }
```

### `PEER_DISCOVERED`

Emitted when a peer is found via mDNS/UDP.

```json
{
  "type": "PEER_DISCOVERED",
  "ip": "192.168.1.5",
  "name": "Another Device",
  "port": 5051
}
```

### `PEER_CONNECTED`

Emitted when a TCP connection is established.

```json
{
  "type": "PEER_CONNECTED",
  "ip": "192.168.1.5",
  "name": "Friend's PC",
  "status": "connected"
}
```

### `CODE_GENERATED`

Result of `GENERATE_CODE`.

```json
{
  "type": "CODE_GENERATED",
  "key": "aes-key-base64",
  "pin": "123456",
  "ip": "192.168.1.10",
  "name": "My Device"
}
```

### `INCOMING_CHAT`

Received chat message.

```json
{
  "type": "INCOMING_CHAT",
  "text": "Hello!",
  "ip": "192.168.1.5"
}
```

### `FILE_OFFER`

Incoming file request.

```json
{
  "type": "FILE_OFFER",
  "offer_id": "12345",
  "file_name": "image.jpg",
  "file_size": 10240,
  "ip": "192.168.1.5"
}
```

### `ERROR`

Generic error message.

```json
{
  "type": "ERROR",
  "error": "Something went wrong"
}
```
