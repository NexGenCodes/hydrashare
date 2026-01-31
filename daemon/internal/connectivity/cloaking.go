package connectivity

import (
	"crypto/sha256"
	"encoding/hex"
	"time"
)

// CloakIP generates a 3-day sliding window hash for an IP address.
// This allows peers to recognize each other without leaking absolute IPs.
func CloakIP(ip string, secretSalt string) []string {
	var cloaks []string
	now := time.Now()

	// Sliding window: Yesterday, Today, Tomorrow
	for i := -1; i <= 1; i++ {
		dateStr := now.AddDate(0, 0, i).Format("2006-01-02")
		hash := sha256.Sum256([]byte(ip + dateStr + secretSalt))
		cloaks = append(cloaks, hex.EncodeToString(hash[:8])) // Short 8-char hash
	}

	return cloaks
}

// VerifyCloak checks if a given cloak matches the IP for the current 3-day window
func VerifyCloak(ip, cloak, secretSalt string) bool {
	validCloaks := CloakIP(ip, secretSalt)
	for _, v := range validCloaks {
		if v == cloak {
			return true
		}
	}
	return false
}
