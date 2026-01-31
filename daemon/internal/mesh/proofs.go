package mesh

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"time"
)

type RoutingProof struct {
	HydraID   string // Public Key (Base64)
	IP        string
	Port      int
	Timestamp int64
	Signature string // Base64 signature
}

// GenerateProof creates a signed routing record for the local node
func GenerateProof(hydraID string, privateKeyB64 string, ip string, port int) (*RoutingProof, error) {
	privBytes, err := base64.StdEncoding.DecodeString(privateKeyB64)
	if err != nil {
		return nil, err
	}
	priv := ed25519.PrivateKey(privBytes)

	timestamp := time.Now().Unix()
	msg := fmt.Sprintf("%s|%s|%d|%d", hydraID, ip, port, timestamp)
	sig := ed25519.Sign(priv, []byte(msg))

	return &RoutingProof{
		HydraID:   hydraID,
		IP:        ip,
		Port:      port,
		Timestamp: timestamp,
		Signature: base64.StdEncoding.EncodeToString(sig),
	}, nil
}

// VerifyProof validates that a routing record was signed by the claimed owner
func VerifyProof(proof *RoutingProof) bool {
	pubBytes, err := base64.StdEncoding.DecodeString(proof.HydraID)
	if err != nil {
		return false
	}
	pub := ed25519.PublicKey(pubBytes)

	sigBytes, err := base64.StdEncoding.DecodeString(proof.Signature)
	if err != nil {
		return false
	}

	// Prevent replay attacks (records older than 1 hour are rejected)
	if time.Now().Unix()-proof.Timestamp > 3600 {
		return false
	}

	msg := fmt.Sprintf("%s|%s|%d|%d", proof.HydraID, proof.IP, proof.Port, proof.Timestamp)
	return ed25519.Verify(pub, []byte(msg), sigBytes)
}
