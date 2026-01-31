package mesh

import (
	"encoding/base64"
	"fmt"
	"strings"
)

// GenerateLocatorToken creates a compact Base64 string for manual peer pairing
func GenerateLocatorToken(hydraID, ip string, port int) string {
	raw := fmt.Sprintf("%s|%s|%d", hydraID, ip, port)
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// DecodeLocatorToken parses a token string back into HydraID, IP, and Port
func DecodeLocatorToken(token string) (hydraID, ip string, port int, err error) {
	decoded, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		return "", "", 0, fmt.Errorf("invalid token encoding")
	}

	parts := strings.Split(string(decoded), "|")
	if len(parts) != 3 {
		return "", "", 0, fmt.Errorf("invalid token format")
	}

	hydraID = parts[0]
	ip = parts[1]
	fmt.Sscanf(parts[2], "%d", &port)

	return hydraID, ip, port, nil
}
