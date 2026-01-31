package transfer

import (
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"hydra_share/daemon/internal/muscle"
	"io"
	"log"
	"net"
	"os"
	"path/filepath"
	"time"
)

// StartReceiver starts the file receiving listener on a dynamic port
func StartReceiver(emitter Emitter) (int, error) {
	ln, err := net.Listen("tcp", ":0") // Dynamic port
	if err != nil {
		return 0, err
	}
	port := ln.Addr().(*net.TCPAddr).Port

	go func() {
		defer ln.Close()
		for {
			conn, err := ln.Accept()
			if err != nil {
				continue
			}
			go handleIncomingTransfer(conn, conn.RemoteAddr().(*net.TCPAddr).IP.String(), emitter)
		}
	}()

	return port, nil
}

func handleIncomingTransfer(conn net.Conn, remoteIP string, emitter Emitter) {
	defer conn.Close()

	// 1. Read Header Size
	var headerSize int32
	if err := binary.Read(conn, binary.LittleEndian, &headerSize); err != nil {
		return
	}

	// 2. Read Header
	headerJSON := make([]byte, headerSize)
	if _, err := io.ReadFull(conn, headerJSON); err != nil {
		return
	}

	var header map[string]interface{}
	json.Unmarshal(headerJSON, &header)

	fileName := header["file_name"].(string)
	fileSize := int64(header["file_size"].(float64))
	startOffset := int64(header["start_offset"].(float64))

	// 3. Setup Session
	transferID := fmt.Sprintf("rx_%d", time.Now().UnixNano())
	if tid, ok := header["transfer_id"].(string); ok {
		transferID = tid
	}

	session := &TransferSession{
		ID:               transferID,
		FilePath:         filepath.Join(GetReceiveDir(), fileName),
		FileSize:         fileSize,
		BytesTransferred: 0,
		Emitter:          emitter,
		Direction:        "download",
		DestIP:           remoteIP,
		StartOffset:      startOffset,
		CancelFlag:       new(int32),
	}

	registerSession(session)
	defer unregisterSession(session.ID)

	// 4. Open File (Append if resuming)
	flags := os.O_CREATE | os.O_WRONLY
	if startOffset > 0 {
		flags = os.O_APPEND | os.O_WRONLY
	}

	finalPath := getAvailablePath(session.FilePath)
	out, err := os.OpenFile(finalPath, flags, 0644)
	if err != nil {
		sendTransferError(session, err)
		return
	}
	defer out.Close()

	// Notify Start
	if emitter != nil {
		emitter.Emit(map[string]interface{}{
			"type":      "RECEIVE_STARTED",
			"file_name": fileName,
			"total":     fileSize,
			"ip":        remoteIP,
		})
	}

	// 5. Start Progress Monitoring
	stopChan := make(chan bool)
	go progressUpdater(session, stopChan)
	defer close(stopChan)

	// --- Receive Body via RUST MUSCLE (Hybrid) ---
	key := GetTransferKey()
	if len(key) == 0 {
		err := fmt.Errorf("secure transfer requires encryption key")
		sendTransferError(session, err)
		return
	}

	keyBytes, err := base64.StdEncoding.DecodeString(key)
	if err != nil {
		sendTransferError(session, err)
		return
	}

	if len(keyBytes) != 32 {
		err := fmt.Errorf("invalid key length: %d (expected 32)", len(keyBytes))
		sendTransferError(session, err)
		return
	}

	tcpConn, ok := conn.(*net.TCPConn)
	if !ok {
		err := fmt.Errorf("connection is not TCP")
		sendTransferError(session, err)
		return
	}

	connFile, err := tcpConn.File() // Duplicate FD
	if err != nil {
		sendTransferError(session, err)
		return
	}
	defer connFile.Close()

	// Call Rust to receive (Muscle Phase 2: Streaming Hash + Throttling)
	hash, err := muscle.ReceiveData(connFile, out, fileSize, keyBytes, GetThrottle(), session.CancelFlag, func(transferred, total int64) {
		session.mu.Lock()
		isCancelled := session.Cancelled
		session.BytesTransferred = transferred
		session.mu.Unlock()

		if isCancelled {
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
		return
	}

	actualHashHex := fmt.Sprintf("%x", hash)
	log.Printf("🛡️ Receive finalized safely. SHA-256: %s", actualHashHex)

	if exHash, ok := header["expected_hash"].(string); ok {
		if actualHashHex != exHash {
			log.Printf("⚠️  Integrity Warning: Hash mismatch for %s! Expected: %s, Actual: %s", fileName, exHash, actualHashHex)
			if emitter != nil {
				emitter.Emit(map[string]interface{}{
					"type":        "VERIFICATION_RESULT",
					"file_name":   fileName,
					"status":      "failure",
					"actual_hash": actualHashHex,
					"expected":    exHash,
				})
			}
		} else {
			log.Printf("✅ Integrity Verified for %s", fileName)
		}
	}

	sendTransferComplete(session)
}
