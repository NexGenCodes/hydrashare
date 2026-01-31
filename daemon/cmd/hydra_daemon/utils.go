package main

import (
	"crypto/aes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
)

func relayMessage(cmd Command) {
	peer := peerRegistry.GetPeer(cmd.DestID)
	if peer != nil {
		if err := json.NewEncoder(peer.Conn).Encode(cmd); err != nil {
			MyLog("❌ Failed to relay message to %s: %v", cmd.DestID, err)
		}
		return
	}
	MyLog("⚠️  No route found for %s. Dropping relay.", cmd.DestID)
}

func generateAESKey() (string, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return "", err
	}
	if _, err := aes.NewCipher(key); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(key), nil
}

func deriveAESKey(pin string) string {
	hash := sha256.Sum256([]byte(pin))
	return base64.StdEncoding.EncodeToString(hash[:])
}

func contains(slice []string, val string) bool {
	for _, item := range slice {
		if item == val {
			return true
		}
	}
	return false
}

// TrackTransferResult logs telemetry about transfer success/failure
func TrackTransferResult(transferID string, success bool, bytes int64, err string) {
	status := "FAILURE"
	if success {
		status = "SUCCESS"
	}
	// Log specific telemetry line
	MyLog("[TELEMETRY] Transfer %s | ID: %s | Size: %d | Error: %s", status, transferID, bytes, err)

	if db != nil {
		db.UpdateTransferStatus(transferID, status)
	}
}
