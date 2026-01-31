package transfer

import (
	"fmt"
	"hydra_share/daemon/internal/connectivity"
	"hydra_share/daemon/internal/muscle"
	"hydra_share/daemon/internal/storage"
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type Emitter interface {
	Emit(event interface{})
}

type Messenger interface {
	CoordinateG2GTransfer(senderID, receiverID, fileName, transferID string, startOffset int64) error
}

var (
	transferSessions = make(map[string]*TransferSession)
	sessionsMu       sync.RWMutex
	receiveDir       string
	transferKey      string
	transferKeyMu    sync.RWMutex
	receivedFiles    = make(map[string]string)
	receivedFilesMu  sync.Mutex
	maxFileSize      int64 = 0
	maxFileSizeMu    sync.RWMutex
	throttleMs       int = 0
	throttleMu       sync.RWMutex

	db   *storage.Database
	dbMu sync.RWMutex

	meshMessenger Messenger
	meshMu        sync.RWMutex

	// TelemetryCallback allows injecting a logger for transfer stats
	TelemetryCallback func(transferID string, success bool, bytes int64, err string)
)

func SetTelemetryCallback(cb func(transferID string, success bool, bytes int64, err string)) {
	TelemetryCallback = cb
}

func SetDB(d *storage.Database) {
	dbMu.Lock()
	defer dbMu.Unlock()
	db = d
}

func getDB() *storage.Database {
	dbMu.RLock()
	defer dbMu.RUnlock()
	return db
}

func SetMessenger(m Messenger) {
	meshMu.Lock()
	defer meshMu.Unlock()
	meshMessenger = m
}

func getMessenger() Messenger {
	meshMu.RLock()
	defer meshMu.RUnlock()
	return meshMessenger
}

func registerSession(session *TransferSession) {
	sessionsMu.Lock()
	defer sessionsMu.Unlock()
	transferSessions[session.ID] = session
}

func unregisterSession(id string) {
	sessionsMu.Lock()
	defer sessionsMu.Unlock()
	delete(transferSessions, id)
}

type TransferSession struct {
	ID               string
	FilePath         string
	DestIP           string
	FileSize         int64
	BytesTransferred int64
	LastUpdate       time.Time
	Emitter          Emitter
	StartOffset      int64
	Direction        string
	Cancelled        bool
	CancelFlag       *int32
	mu               sync.Mutex
}

func init() {
	userHome, _ := os.UserHomeDir()
	receiveDir = filepath.Join(userHome, "Downloads", "HydraShare")
	os.MkdirAll(receiveDir, 0755)
}

func SetTransferKey(key string) {
	transferKeyMu.Lock()
	defer transferKeyMu.Unlock()
	transferKey = key
}

func GetTransferKey() string {
	transferKeyMu.RLock()
	defer transferKeyMu.Unlock()
	return transferKey
}

func SetMaxFileSize(size int64) {
	maxFileSizeMu.Lock()
	defer maxFileSizeMu.Unlock()
	maxFileSize = size
}

func GetMaxFileSize() int64 {
	maxFileSizeMu.RLock()
	defer maxFileSizeMu.RUnlock()
	return maxFileSize
}

func GetReceiveDir() string {
	return receiveDir
}

func SetThrottle(ms int) {
	throttleMu.Lock()
	defer throttleMu.Unlock()
	throttleMs = ms
}

func GetThrottle() int {
	throttleMu.RLock()
	defer throttleMu.RUnlock()
	return throttleMs
}

// StartAdaptiveThrottler periodically checks network type and updates the global throttle
func StartAdaptiveThrottler() {
	ticker := time.NewTicker(10 * time.Second)
	go func() {
		for range ticker.C {
			suggested := connectivity.GetBandwidthSuggestion()
			current := GetThrottle()
			if suggested != current {
				log.Printf("⚖️ Adaptive Throttling: Network change detected. Updating throttle to %d ms", suggested)
				SetThrottle(suggested)
			}
		}
	}()
}

func GetFileInfo(filePath string) (os.FileInfo, error) {
	return os.Stat(filePath)
}

func CancelTransfer(transferID string) {
	sessionsMu.RLock()
	defer sessionsMu.RUnlock()
	if session, ok := transferSessions[transferID]; ok {
		session.mu.Lock()
		session.Cancelled = true
		if session.CancelFlag != nil {
			*session.CancelFlag = 1 // Signal Rust to stop
		}
		session.mu.Unlock()
		log.Printf("🛑 Transfer cancelled: %s (%s)", transferID, session.FilePath)
	}
}

// Resume attempts to restart a transfer from its last known state
func Resume(transferID string, database *storage.Database, emitter Emitter) error {
	transfer, err := database.GetTransferByID(transferID)
	if err != nil {
		return err
	}

	direction := transfer["direction"].(string)
	peerIP := transfer["ip"].(string)
	filePath := transfer["file"].(string)

	if direction == "send" {
		// Look for resumption token
		_, offset, _, err := database.GetResumptionToken(transferID)
		if err != nil {
			offset = 0 // Start from beginning if token not found
		}

		log.Printf("🚀 Resuming upload for %s from byte %d", filePath, offset)
		return StartTransfer(filePath, peerIP, 5051, emitter, nil, offset)
	}

	if direction == "download" {
		// For downloads, we need to tell the other side to start sending from offset
		_, offset, _, err := database.GetResumptionToken(transferID)
		if err != nil {
			offset = 0
		}

		log.Printf("🚀 Resuming download for %s from byte %d", filePath, offset)
		if m := getMessenger(); m != nil {
			// We need the IDs. For now, assume we use IDs for transferID tracking or look them up.
			// Simplified: In direct P2P, we might just need to signal the peer at the IP.
			// But the CoordinateG2GTransfer takes IDs.
			// Ideally, transfers table should have stored sender/receiver IDs.
			// For now, we reuse transferID as a fallback or assume it contains info.
			m.CoordinateG2GTransfer("", "", filePath, transferID, offset)
		}
	}

	return nil
}

func getAvailablePath(basePath string) string {
	if _, err := os.Stat(basePath); os.IsNotExist(err) {
		return basePath
	}
	ext := filepath.Ext(basePath)
	name := basePath[:len(basePath)-len(ext)]
	for i := 1; ; i++ {
		newPath := fmt.Sprintf("%s (%d)%s", name, i, ext)
		if _, err := os.Stat(newPath); os.IsNotExist(err) {
			return newPath
		}
	}
}

func VerifyReceivedFile(fileName, expectedHash string, emitter Emitter) {
	fullPath := filepath.Join(GetReceiveDir(), fileName)
	log.Printf("🛡️ Verifying %s against expected hash %s", fileName, expectedHash)

	go func() {
		actualHash, err := muscle.CalculateFileHash(fullPath)
		if err != nil {
			log.Printf("❌ Hash calculation failed for %s: %v", fileName, err)
			return
		}

		actualHashHex := fmt.Sprintf("%x", actualHash)
		status := "success"
		if actualHashHex != expectedHash {
			status = "failure"
			log.Printf("⚠️ Hash mismatch for %s! Expected: %s, Actual: %s", fileName, expectedHash, actualHashHex)
		} else {
			log.Printf("✅ %s verified successfully", fileName)
		}

		if emitter != nil {
			emitter.Emit(map[string]interface{}{
				"type":        "VERIFICATION_RESULT",
				"file_name":   fileName,
				"status":      status,
				"actual_hash": actualHashHex,
			})
		}
	}()
}

func sendTransferComplete(session *TransferSession) {
	if session.Emitter != nil {
		session.Emitter.Emit(map[string]interface{}{
			"type":        "TRANSFER_COMPLETE",
			"transfer_id": session.ID,
			"file_name":   filepath.Base(session.FilePath),
			"status":      "success",
			"direction":   session.Direction,
		})
	}
	if TelemetryCallback != nil {
		TelemetryCallback(session.ID, true, session.BytesTransferred, "")
	}
}

func sendTransferError(session *TransferSession, err error) {
	if session.Emitter != nil {
		session.Emitter.Emit(map[string]interface{}{
			"type":        "TRANSFER_ERROR",
			"transfer_id": session.ID,
			"error":       err.Error(),
			"direction":   session.Direction,
		})
	}
	if TelemetryCallback != nil {
		TelemetryCallback(session.ID, false, session.BytesTransferred, err.Error())
	}
}
