package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"sync"
	"time"

	"golang.org/x/crypto/pbkdf2"
)

// Service handles all secure pairing and authentication logic
type Service struct {
	mu                sync.RWMutex
	pinToSessionKey   map[string]string
	pinToSalt         map[string]string
	failedPinAttempts map[string]int
	blockedIPs        map[string]time.Time
}

// NewService creates a new instance of the authentication service
func NewService() *Service {
	return &Service{
		pinToSessionKey:   make(map[string]string),
		pinToSalt:         make(map[string]string),
		failedPinAttempts: make(map[string]int),
		blockedIPs:        make(map[string]time.Time),
	}
}

// GenerateCredentials creates a new PIN and Session Key pair
func (s *Service) GenerateCredentials() (string, string, string, string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// 1. Generate 6-digit PIN
	pin := fmt.Sprintf("%06d", time.Now().UnixNano()%1000000)

	// 2. Generate Random Salt (16 bytes)
	saltBytes := make([]byte, 16)
	rand.Read(saltBytes)
	salt := base64.StdEncoding.EncodeToString(saltBytes)

	// 3. Compute Discovery Hash (PBKDF2)
	pinHash := s.HashPIN(pin, salt)

	// 4. Generate Strong Session Key (AES-256)
	keyBytes := make([]byte, 32)
	rand.Read(keyBytes)
	sessionKey := base64.StdEncoding.EncodeToString(keyBytes)

	// 5. Store in Vault
	s.pinToSessionKey[pin] = sessionKey
	s.pinToSalt[pin] = salt

	return pin, sessionKey, pinHash, salt
}

// VerifyPinProof checks if a provided hash matches any registered PIN
func (s *Service) VerifyPinProof(remoteIP, pinProof string) (string, string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// 1. Rate Limiting Check
	if until, banned := s.blockedIPs[remoteIP]; banned && time.Now().Before(until) {
		return "", "", false
	}

	// 2. Validate Proof
	for pin, sessionKey := range s.pinToSessionKey {
		salt := s.pinToSalt[pin]
		expectedHash := s.HashPIN(pin, salt)
		if expectedHash == pinProof {
			// Success! Reset penalties
			delete(s.failedPinAttempts, remoteIP)
			delete(s.blockedIPs, remoteIP)

			// Rotation: Invalidate this PIN immediately (One-Time Use)
			delete(s.pinToSessionKey, pin)
			delete(s.pinToSalt, pin)

			return pin, sessionKey, true
		}
	}

	// 3. Increment Failures
	s.failedPinAttempts[remoteIP]++
	if s.failedPinAttempts[remoteIP] >= 3 {
		s.blockedIPs[remoteIP] = time.Now().Add(5 * time.Minute)
	}

	return "", "", false
}

// HashPIN computes the PBKDF2 hash of the PIN using the provided salt
func (s *Service) HashPIN(pin, salt string) string {
	saltBytes, _ := base64.StdEncoding.DecodeString(salt)
	if len(saltBytes) == 0 {
		saltBytes = []byte(salt) // Fallback
	}
	// Iterations: 100,000 (Slow enough to stop brute-force, fast enough for UX)
	dk := pbkdf2.Key([]byte(pin), saltBytes, 100000, 32, sha256.New)
	return base64.StdEncoding.EncodeToString(dk)
}

// DeriveInitialKey creates a temporary key for initial handshakes if needed
func (s *Service) DeriveInitialKey(pin string) []byte {
	hash := sha256.Sum256([]byte(pin))
	return hash[:]
}
