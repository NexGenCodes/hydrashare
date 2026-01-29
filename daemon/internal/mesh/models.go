package mesh

import "time"

// DiscoveryCard is sent by the Host to introduce Guests to each other
type DiscoveryCard struct {
	Type                string    `json:"type"`
	PeerID              string    `json:"peer_id"`
	Name                string    `json:"name"`
	IPs                 []string  `json:"ips"`
	SupportedTransports []string  `json:"transports"`
	PublicKey           string    `json:"public_key"`
	Timestamp           time.Time `json:"timestamp"`
}

// HandshakeV2Request is sent by the Guest to the Host
type HandshakeV2Request struct {
	Type                string       `json:"type"`
	Name                string       `json:"name"`
	SupportedTransports []string     `json:"supported_transports"`
	Capabilities        Capabilities `json:"capabilities"`
}

// Capabilities defines what a device can do on the mesh
type Capabilities struct {
	CanHostHotspot bool   `json:"can_host_hotspot"`
	CanDoP2P       bool   `json:"can_do_p2p"`
	Version        string `json:"version"`
}

// ResumptionToken is used to resume transfers after IP migration
type ResumptionToken struct {
	Type           string    `json:"type"`
	TokenID        string    `json:"token_id"`
	FilePath       string    `json:"file_path"`
	BytesCompleted int64     `json:"bytes_completed"`
	TotalSize      int64     `json:"total_size"`
	PeerPublicKey  string    `json:"peer_public_key"`
	ExpiresAt      time.Time `json:"expires_at"`
}
