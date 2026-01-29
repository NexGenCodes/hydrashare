package transfer

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"runtime/cgo"
	"sync"
	"time"
	"unsafe"
)

/*
#cgo LDFLAGS: -L${SRCDIR}/../../ -L${SRCDIR}/../../../ -lhydra_muscle
#include <stdint.h>
#include <stdlib.h>
#include "../../hydra_muscle/hydra_muscle.h"
#ifndef HYDRA_TYPES
#define HYDRA_TYPES
typedef int64_t hydra_i64;
#endif
extern void goProgressCallback(int64_t transferred, int64_t total, void* user_data);
*/
import "C"

var (
	transferSessions = make(map[string]*TransferSession)
	sessionsMu       sync.RWMutex
	receiveDir       string

	// Global encryption key for the session
	transferKey   string
	transferKeyMu sync.RWMutex

	// Track received files for post-transfer verification
	receivedFiles   = make(map[string]string) // Name -> Path
	receivedFilesMu sync.Mutex
)

// TransferSession manages an active file transfer
type TransferSession struct {
	ID                string
	FilePath          string
	DestIP            string
	FileSize          int64
	BytesTransferred  int64
	LastUpdate        time.Time
	Client            net.Conn
	Cancelled         *C.int32_t // Flag in C-allocated memory
	LastBytes         int64
	LastUpdateTime    time.Time
	StartOffset       int64
	LastRotationBytes int64
	mu                sync.Mutex
}

func init() {
	// Initialize receive directory in Downloads
	home, _ := os.UserHomeDir()
	receiveDir = filepath.Join(home, "Downloads", "HydraShare")
	os.MkdirAll(receiveDir, 0755)
}

// getAvailablePath returns a unique path by appending (1), (2), etc. if needed
func getAvailablePath(basePath string) string {
	if _, err := os.Stat(basePath); os.IsNotExist(err) {
		return basePath
	}

	ext := filepath.Ext(basePath)
	name := basePath[:len(basePath)-len(ext)]
	counter := 1

	for {
		newPath := fmt.Sprintf("%s (%d)%s", name, counter, ext)
		if _, err := os.Stat(newPath); os.IsNotExist(err) {
			return newPath
		}
		counter++
	}
}

// SetTransferKey sets the global encryption key for transfers
func SetTransferKey(key string) {
	transferKeyMu.Lock()
	defer transferKeyMu.Unlock()
	transferKey = key
	fmt.Printf("🔐 Transfer Key Set: %s... (len=%d)\n", key[:5], len(key))
}

// GetTransferKey retrieves the current transfer key safely
func GetTransferKey() string {
	transferKeyMu.RLock()
	defer transferKeyMu.RUnlock()
	return transferKey
}

const (
	rotationThreshold = 500 * 1024 * 1024 // Rotate key every 500MB
)

// Progress callback that Go exports to C
//
//export goProgressCallback
func goProgressCallback(transferred C.int64_t, total C.int64_t, userData unsafe.Pointer) {
	// Reconstruct the session from the handle
	h := cgo.Handle(userData)
	session := h.Value().(*TransferSession)

	session.mu.Lock()
	session.BytesTransferred = int64(transferred)
	session.LastUpdate = time.Now()
	session.mu.Unlock()
}

// GetFileInfo returns the file info for a given path
func GetFileInfo(filePath string) (os.FileInfo, error) {
	return os.Stat(filePath)
}

// StartTransfer initiates a file transfer to a destination IP
func StartTransfer(filePath, destIP string, uiConn net.Conn, ctrlConn net.Conn, startOffset int64) error {
	// Validate file exists
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		return fmt.Errorf("file not found: %w", err)
	}

	key := GetTransferKey()
	if key == "" {
		return fmt.Errorf("encryption key not set")
	}

	fileSize := fileInfo.Size()
	transferID := fmt.Sprintf("transfer_%d", time.Now().UnixNano())

	// Create session with C-allocated cancellation flag
	cancelPtr := (*C.int32_t)(C.malloc(C.size_t(unsafe.Sizeof(C.int32_t(0)))))
	*cancelPtr = 0

	session := &TransferSession{
		ID:             transferID,
		FilePath:       filePath,
		DestIP:         destIP,
		FileSize:       fileSize,
		LastUpdate:     time.Now(),
		Client:         uiConn,
		Cancelled:      cancelPtr,
		LastBytes:      0,
		LastUpdateTime: time.Now(),
		StartOffset:    startOffset,
	}

	sessionsMu.Lock()
	transferSessions[transferID] = session
	sessionsMu.Unlock()

	// Start transfer in goroutine
	go func() {
		defer func() {
			sessionsMu.Lock()
			delete(transferSessions, transferID)
			sessionsMu.Unlock()
		}()

		if err := performTransfer(session, key, ctrlConn, startOffset); err != nil {
			sendTransferError(session, err)
		} else {
			sendTransferComplete(session)
		}

		// Cleanup C memory
		C.free(unsafe.Pointer(session.Cancelled))
	}()

	// Send initial response
	response := map[string]interface{}{
		"type":        "TRANSFER_STARTED",
		"transfer_id": transferID,
		"file_size":   fileSize,
		"file_name":   filepath.Base(filePath),
	}
	encoder := json.NewEncoder(uiConn)
	return encoder.Encode(response)
}

func performTransfer(session *TransferSession, key string, ctrlConn net.Conn, startOffset int64) error {
	// Open source file
	sourceFile, err := os.Open(session.FilePath)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer sourceFile.Close()

	// Connect to destination
	destConn, err := net.Dial("tcp", fmt.Sprintf("%s:5051", session.DestIP))
	if err != nil {
		return fmt.Errorf("failed to connect to destination: %w", err)
	}
	defer destConn.Close()

	// Get file descriptors
	srcFd := int(sourceFile.Fd())

	// For network socket, we need the underlying fd
	destTCP, ok := destConn.(*net.TCPConn)
	if !ok {
		return fmt.Errorf("failed to cast connection to TCPConn")
	}
	destFile, err := destTCP.File()
	if err != nil {
		return fmt.Errorf("failed to get destination fd: %w", err)
	}
	defer destFile.Close()
	destFd := int(destFile.Fd())

	// Start progress updater
	stopProgress := make(chan bool)
	go progressUpdater(session, stopProgress)
	defer close(stopProgress)

	// Monitor session for key rotation
	go func() {
		for {
			select {
			case <-stopProgress:
				return
			case <-time.After(1 * time.Second):
				session.mu.Lock()
				// Delta-based rotation check
				if session.BytesTransferred-session.LastRotationBytes >= rotationThreshold {
					session.LastRotationBytes = session.BytesTransferred
					fmt.Printf("🔄 Key Rotation Threshold reached for %s at %d bytes\n", session.ID, session.BytesTransferred)

					// Send rotation signal direct to Peer's control plane
					if ctrlConn != nil {
						rotationMsg := map[string]interface{}{
							"type":        "ROTATE_KEY_SIGNAL",
							"transfer_id": session.ID,
							"at_bytes":    session.BytesTransferred,
						}
						json.NewEncoder(ctrlConn).Encode(rotationMsg)
					}
				}
				session.mu.Unlock()
			}
		}
	}()

	// Calculate Hash in Background to avoid blocking the transfer start
	var fileHash string
	hashDone := make(chan string, 1)
	go func() {
		h := sha256.New()
		f, err := os.Open(session.FilePath)
		if err == nil {
			io.Copy(h, f)
			f.Close()
			hashDone <- hex.EncodeToString(h.Sum(nil))
		} else {
			hashDone <- ""
		}
	}()

	// --- 1. Send Encrypted Header ---

	header := struct {
		FileName string `json:"file_name"`
		FileSize int64  `json:"file_size"`
		FileHash string `json:"file_hash,omitempty"` // Optional in first header
	}{
		FileName: filepath.Base(session.FilePath),
		FileSize: session.FileSize,
	}
	hBytes, err := json.Marshal(header)
	if err != nil {
		return fmt.Errorf("failed to marshal header: %w", err)
	}

	// Encrypt Header
	keyBytes, err := base64.StdEncoding.DecodeString(key)
	if err != nil {
		return fmt.Errorf("invalid key: %w", err)
	}
	block, err := aes.NewCipher(keyBytes)
	if err != nil {
		return fmt.Errorf("failed to create cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return fmt.Errorf("failed to create GCM: %w", err)
	}

	hNonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, hNonce); err != nil {
		return fmt.Errorf("failed to generate header nonce: %w", err)
	}

	hCipher := gcm.Seal(nil, hNonce, hBytes, nil)

	// Write Header: [Nonce (12)] + [Len (4)] + [Ciphertext]
	if _, err := destConn.Write(hNonce); err != nil {
		return fmt.Errorf("failed to write header nonce: %w", err)
	}

	if err := binary.Write(destConn, binary.BigEndian, uint32(len(hCipher))); err != nil {
		return fmt.Errorf("failed to write header length: %w", err)
	}

	if _, err := destConn.Write(hCipher); err != nil {
		return fmt.Errorf("failed to write header cipher: %w", err)
	}

	// --- 2. Call Rust for Encrypted File Body (Rust sends FNonce + Chunks) ---
	// Create a handle for the session to pass safely to C
	h := cgo.NewHandle(session)
	defer h.Delete()

	// Convert key to C pointer
	cKey := C.CBytes(keyBytes)
	defer C.free(cKey)

	// Call Rust transfer function
	result := C.transfer_data(
		C.intptr_t(srcFd),
		C.intptr_t(destFd),
		C.hydra_i64(session.FileSize),
		C.hydra_i64(startOffset),
		(*C.uint8_t)(cKey),
		C.uintptr_t(len(keyBytes)),
		session.Cancelled,
		(C.progress_callback_t)(C.goProgressCallback),
		unsafe.Pointer(h),
	)

	if result != C.SUCCESS {
		return fmt.Errorf("transfer failed with code: %d", result)
	}

	// --- 3. Send Verification Hash (Post-Transfer) ---
	fileHash = <-hashDone
	if fileHash != "" && ctrlConn != nil {
		fmt.Printf("🛡️  Sending verification hash for %s\n", session.ID)
		verifyMsg := map[string]interface{}{
			"type":        "VERIFY_HASH",
			"transfer_id": session.ID,
			"file_name":   filepath.Base(session.FilePath),
			"hash":        fileHash,
		}
		json.NewEncoder(ctrlConn).Encode(verifyMsg)
	}

	// Also notify local UI that we are done on our side
	if session.Client != nil {
		completeMsg := map[string]interface{}{
			"type":        "TRANSFER_COMPLETE",
			"transfer_id": session.ID,
			"file_name":   filepath.Base(session.FilePath),
		}
		json.NewEncoder(session.Client).Encode(completeMsg)
	}

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

			response := map[string]interface{}{
				"type":        "TRANSFER_PROGRESS",
				"transfer_id": session.ID,
				"transferred": current,
				"total":       total,
			}
			if session.Client != nil {
				json.NewEncoder(session.Client).Encode(response)
			}
		}
	}
}

func sendTransferComplete(session *TransferSession) {
	response := map[string]interface{}{
		"type":        "TRANSFER_COMPLETE",
		"transfer_id": session.ID,
		"status":      "success",
	}
	if session.Client != nil {
		json.NewEncoder(session.Client).Encode(response)
	}
}

func sendTransferError(session *TransferSession, err error) {
	response := map[string]interface{}{
		"type":        "TRANSFER_ERROR",
		"transfer_id": session.ID,
		"error":       err.Error(),
	}
	if session.Client != nil {
		json.NewEncoder(session.Client).Encode(response)
	}
}

// CancelTransfer sets the cancellation flag for a given transfer ID
func CancelTransfer(transferID string) {
	sessionsMu.RLock()
	session, ok := transferSessions[transferID]
	sessionsMu.RUnlock()

	if ok {
		*session.Cancelled = 1
	}
}

// StartReceiver starts the file receiving listener on port 5051
func StartReceiver(eventsChan chan<- map[string]interface{}) {
	ln, err := net.Listen("tcp", ":5051")
	if err != nil {
		fmt.Printf("❌ Failed to start receiver: %v\n", err)
		return
	}
	defer ln.Close()

	fmt.Println("📥 File receiver listening on :5051")

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Printf("❌ Failed to accept receiver connection: %v\n", err)
			continue
		}

		go handleIncomingTransfer(conn, eventsChan)
	}
}

func handleIncomingTransfer(conn net.Conn, eventsChan chan<- map[string]interface{}) {
	defer conn.Close()

	key := GetTransferKey()
	if key == "" {
		fmt.Printf("❌ No encryption key set, cannot receive file.\n")
		return
	}
	keyBytes, err := base64.StdEncoding.DecodeString(key)
	if err != nil {
		fmt.Printf("❌ Invalid key format: %v\n", err)
		return
	}

	block, err := aes.NewCipher(keyBytes)
	if err != nil {
		fmt.Printf("❌ Failed to create cipher: %v\n", err)
		return
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		fmt.Printf("❌ Failed to create GCM: %v\n", err)
		return
	}

	// --- 1. Read Encrypted Header ---
	// [Nonce (12)]
	hNonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(conn, hNonce); err != nil {
		fmt.Printf("❌ Failed to read header nonce: %v\n", err)
		return
	}

	// [Len (4)]
	var hLen uint32
	if err := binary.Read(conn, binary.BigEndian, &hLen); err != nil {
		fmt.Printf("❌ Failed to read header length: %v\n", err)
		return
	}

	// [Ciphertext]
	hCipher := make([]byte, hLen)
	if _, err := io.ReadFull(conn, hCipher); err != nil {
		fmt.Printf("❌ Failed to read header cipher: %v\n", err)
		return
	}

	// Decrypt
	hPlain, err := gcm.Open(nil, hNonce, hCipher, nil)
	if err != nil {
		fmt.Printf("❌ Failed to decrypt header: %v\n", err)
		return
	}

	var header struct {
		FileName string `json:"file_name"`
		FileSize int64  `json:"file_size"`
		FileHash string `json:"file_hash"`
	}
	if err := json.Unmarshal(hPlain, &header); err != nil {
		fmt.Printf("❌ Failed to decode header JSON: %v\n", err)
		return
	}

	// Sanitize file path
	header.FileName = filepath.Base(header.FileName)
	destPath := getAvailablePath(filepath.Join(receiveDir, header.FileName))
	fmt.Printf("📥 Receiving file: %s (%d bytes) -> %s\n", header.FileName, header.FileSize, destPath)

	// Check for resumption
	var startOffset int64 = 0
	if info, err := os.Stat(destPath); err == nil {
		startOffset = info.Size()
		fmt.Printf("🔄 Resuming from offset: %d\n", startOffset)
	}

	file, err := os.OpenFile(destPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		fmt.Printf("❌ Failed to open file: %v\n", err)
		return
	}
	defer file.Close()

	// Notify start
	eventsChan <- map[string]interface{}{
		"type":      "RECEIVE_STARTED",
		"file_name": header.FileName,
		"file_size": header.FileSize,
	}

	// --- 2. Read Encrypted File Body ---
	// Rust sends: [FNonce (12)] then Loop: [CLen (4)][CChunk]

	// Read FNonce
	fNonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(conn, fNonce); err != nil {
		fmt.Printf("❌ Failed to read file nonce: %v\n", err)
		return
	}

	start := time.Now()
	var totalTransferred int64 = 0

	// Hasher for verification
	hasher := sha256.New()

	// Read Loop
	// We reuse buffer. Max chunk size 1MB + overhead.
	// Rust chunk is 1024*1024. Ciphertext is Chunk + 16 (Tag).
	chunkBuf := make([]byte, 1024*1024+1024)

	for {
		var cLen uint32
		err := binary.Read(conn, binary.BigEndian, &cLen)
		if err == io.EOF {
			break // Transfer complete
		}
		if err != nil {
			fmt.Printf("❌ Failed to read chunk length: %v\n", err)
			break
		}

		if int(cLen) > len(chunkBuf) {
			// Resize if needed
			chunkBuf = make([]byte, cLen+1024)
		}

		// Read Ciphertext Chunk
		if _, err := io.ReadFull(conn, chunkBuf[:cLen]); err != nil {
			fmt.Printf("❌ Failed to read chunk cipher: %v\n", err)
			break
		}

		// Decrypt
		plain, err := gcm.Open(nil, fNonce, chunkBuf[:cLen], nil)
		if err != nil {
			fmt.Printf("❌ Failed to decrypt chunk: %v\n", err)
			break
		}

		// Write to File
		if _, err := file.Write(plain); err != nil {
			fmt.Printf("❌ Failed to write to file: %v\n", err)
			break
		}
		// Write to Hasher
		if _, err := hasher.Write(plain); err != nil {
			fmt.Printf("❌ Failed to write to hasher: %v\n", err)
			break
		}
		totalTransferred += int64(len(plain))
	}

	duration := time.Since(start)
	if totalTransferred == header.FileSize {
		// Verify Hash
		receivedHash := hex.EncodeToString(hasher.Sum(nil))
		if header.FileHash != "" {
			if receivedHash == header.FileHash {
				fmt.Printf("✅ Hash Verified: %s\n", receivedHash)
			} else {
				fmt.Printf("❌ Hash Mismatch! Expected: %s, Got: %s\n", header.FileHash, receivedHash)
				// Rename to .corrupted
				base := filepath.Base(destPath)
				os.Rename(destPath, filepath.Join(receiveDir, base+".corrupted"))

				eventsChan <- map[string]interface{}{
					"type":      "TRANSFER_ERROR",
					"file_name": header.FileName,
					"error":     "Hash mismatch - file corrupted",
				}
				return
			}
		}

		fmt.Printf("✅ Received %d bytes in %v for %s\n", totalTransferred, duration, header.FileName)

		// Store path for post-transfer verification if hash is missing in header
		if header.FileHash == "" {
			receivedFilesMu.Lock()
			receivedFiles[header.FileName] = destPath
			receivedFilesMu.Unlock()

			eventsChan <- map[string]interface{}{
				"type":      "RECEIVE_PENDING_VERIFICATION",
				"file_name": header.FileName,
			}
		} else {
			eventsChan <- map[string]interface{}{
				"type":      "RECEIVE_COMPLETE",
				"file_name": header.FileName,
				"path":      destPath,
			}
		}
	}
}

// VerifyReceivedFile checks the hash of a recently received file and finalizes its status
func VerifyReceivedFile(fileName, expectedHash string, eventsChan chan<- map[string]interface{}) {
	receivedFilesMu.Lock()
	path, ok := receivedFiles[fileName]
	delete(receivedFiles, fileName)
	receivedFilesMu.Unlock()

	if !ok {
		fmt.Printf("⚠️  Verification failed: No pending file found for %s\n", fileName)
		return
	}

	// Calculate local hash again to ensure disk integrity
	f, err := os.Open(path)
	if err != nil {
		fmt.Printf("❌ Failed to open file for verification: %v\n", err)
		return
	}
	defer f.Close()

	h := sha256.New()
	io.Copy(h, f)
	actualHash := hex.EncodeToString(h.Sum(nil))

	if actualHash == expectedHash {
		fmt.Printf("✅ Post-transfer Hash Verified for %s\n", fileName)
		eventsChan <- map[string]interface{}{
			"type":      "RECEIVE_COMPLETE",
			"file_name": fileName,
			"path":      path,
		}
	} else {
		fmt.Printf("❌ Post-transfer Hash Mismatch for %s\n", fileName)
		base := filepath.Base(path)
		os.Rename(path, filepath.Join(receiveDir, base+".corrupted"))

		eventsChan <- map[string]interface{}{
			"type":      "TRANSFER_ERROR",
			"file_name": fileName,
			"error":     "Post-transfer hash mismatch",
		}
	}
}
