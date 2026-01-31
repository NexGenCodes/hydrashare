package transfer

import (
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"hydra_share/daemon/internal/muscle"
	"net"
	"os"
	"path/filepath"
	"time"
)

// StartTransfer initiates a file transfer to a destination IP
func StartTransfer(filePath, destIP string, destPort int, emitter Emitter, ctrlConn net.Conn, startOffset int64) error {
	fileInfo, err := GetFileInfo(filePath)
	if err != nil {
		return err
	}

	session := &TransferSession{
		ID:          fmt.Sprintf("tx_%d", time.Now().UnixNano()),
		FilePath:    filePath,
		DestIP:      destIP,
		FileSize:    fileInfo.Size(),
		LastUpdate:  time.Now(),
		Emitter:     emitter,
		Direction:   "upload",
		StartOffset: startOffset,
		CancelFlag:  new(int32),
	}

	sessionsMu.Lock()
	transferSessions[session.ID] = session
	sessionsMu.Unlock()

	go performTransfer(session, destPort, GetTransferKey(), ctrlConn, startOffset)
	return nil
}

func performTransfer(session *TransferSession, destPort int, key string, ctrlConn net.Conn, startOffset int64) error {
	registerSession(session)
	defer unregisterSession(session.ID)

	// Transfer channel (Standard TCP for data)
	conn, err := net.DialTimeout("tcp", net.JoinHostPort(session.DestIP, fmt.Sprintf("%d", destPort)), 5*time.Second)
	if err != nil {
		sendTransferError(session, err)
		return err
	}
	defer conn.Close()

	file, err := os.Open(session.FilePath)
	if err != nil {
		sendTransferError(session, err)
		return err
	}
	defer file.Close()

	if startOffset > 0 {
		file.Seek(startOffset, 0)
	}

	// Calculate hash for verification (Real Hashing: Muscle Phase 5)
	fileHash, _ := muscle.CalculateFileHash(session.FilePath)
	fileHashHex := fmt.Sprintf("%x", fileHash)

	// --- Transfer Header (Unencrypted for routing, or partially encrypted) ---
	header := map[string]interface{}{
		"file_name":     filepath.Base(session.FilePath),
		"file_size":     session.FileSize,
		"transfer_id":   session.ID,
		"start_offset":  startOffset,
		"expected_hash": fileHashHex,
	}
	headerJSON, _ := json.Marshal(header)

	// Send header size and header
	binary.Write(conn, binary.LittleEndian, int32(len(headerJSON)))
	conn.Write(headerJSON)

	// --- Start Progress Monitoring ---
	stopChan := make(chan bool)
	go progressUpdater(session, stopChan)
	defer close(stopChan)

	// --- Stream Body via RUST MUSCLE (Hybrid) ---
	// If the key is empty, we cannot encrypt. Fail for now as per secure requirements.
	if len(key) == 0 {
		err := fmt.Errorf("secure transfer requires encryption key")
		sendTransferError(session, err)
		return err
	}

	// Decode Base64 Key
	keyBytes, err := base64.StdEncoding.DecodeString(key)
	if err != nil {
		fmt.Printf("Key decode failed: %v\n", err)
		// Try using raw if possible or fail?
		// We'll trust util generation which is base64
		sendTransferError(session, err)
		return err
	}

	if len(keyBytes) != 32 {
		err := fmt.Errorf("invalid key length: %d (expected 32)", len(keyBytes))
		sendTransferError(session, err)
		return err
	}

	// Get *os.File from net.Conn
	tcpConn, ok := conn.(*net.TCPConn)
	if !ok {
		err := fmt.Errorf("connection is not TCP")
		sendTransferError(session, err)
		return err
	}

	connFile, err := tcpConn.File() // Duplicate FD
	if err != nil {
		sendTransferError(session, err)
		return err
	}
	defer connFile.Close()

	// Call Rust to transfer (Muscle Phase 2: Streaming Hash + Throttling)
	hash, err := muscle.TransferData(file, connFile, session.FileSize, startOffset, keyBytes, GetThrottle(), session.CancelFlag, func(transferred, total int64) {
		session.mu.Lock()
		isCancelled := session.Cancelled
		session.BytesTransferred = transferred
		session.mu.Unlock()

		if isCancelled {
			// Note: We need a way to kill the Rust thread.
			// For now, returning from callback doesn't stop Rust, but we can close the FD.
			connFile.Close()
			return
		}

		// Save resumption token every 5MB or at the end
		if transferred%(5*1024*1024) == 0 || transferred == total {
			if d := getDB(); d != nil {
				d.SaveResumptionToken(session.ID, session.FilePath, transferred+startOffset, total, "")
			}
		}
	})
	if err != nil {
		sendTransferError(session, err)
		return err
	}

	fmt.Printf("✅ Transfer finalized safely. SHA-256: %x\n", hash)

	sendTransferComplete(session)
	return nil
}

func progressUpdater(session *TransferSession, stopChan chan bool) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-stopChan:
			return
		case <-ticker.C:
			session.mu.Lock()
			current := session.BytesTransferred
			total := session.FileSize
			session.mu.Unlock()

			if session.Emitter != nil {
				session.Emitter.Emit(map[string]interface{}{
					"type":        "TRANSFER_PROGRESS",
					"transfer_id": session.ID,
					"transferred": current + session.StartOffset,
					"total":       total,
					"percentage":  float64(current+session.StartOffset) / float64(total) * 100,
					"direction":   session.Direction,
					"ip":          session.DestIP,
					"file_name":   filepath.Base(session.FilePath),
				})
			}
		}
	}
}
