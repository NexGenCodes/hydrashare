package transfer

import (
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

// Forward declaration for the progress callback
extern void goProgressCallback(int64_t transferred, int64_t total, void* user_data);
*/
import "C"

var (
	transferSessions = make(map[string]*TransferSession)
	sessionsMu       sync.RWMutex
	receiveDir       string
)

// TransferSession manages an active file transfer
type TransferSession struct {
	ID               string
	FilePath         string
	DestIP           string
	FileSize         int64
	BytesTransferred int64
	LastUpdate       time.Time
	Client           net.Conn
	Cancelled        *C.int32_t // Flag in C-allocated memory
	LastBytes        int64
	LastUpdateTime   time.Time
	mu               sync.Mutex
}

func init() {
	// Initialize receive directory in Downloads
	home, _ := os.UserHomeDir()
	receiveDir = filepath.Join(home, "Downloads", "HydraShare")
	os.MkdirAll(receiveDir, 0755)
}

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

	fmt.Printf("📊 [%s] Progress: %d / %d bytes (%.1f%%)\n",
		session.ID,
		int64(transferred),
		int64(total),
		float64(transferred)/float64(total)*100.0)
}

// StartTransfer initiates a file transfer to a destination IP
func StartTransfer(filePath, destIP string, conn net.Conn) error {
	// Validate file exists
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		return fmt.Errorf("file not found: %w", err)
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
		Client:         conn,
		Cancelled:      cancelPtr,
		LastBytes:      0,
		LastUpdateTime: time.Now(),
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

		if err := performTransfer(session); err != nil {
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
	encoder := json.NewEncoder(conn)
	return encoder.Encode(response)
}

func performTransfer(session *TransferSession) error {
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
	sourceFd := int(sourceFile.Fd())

	// For network socket, we need the underlying fd
	destTCP := destConn.(*net.TCPConn)
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

	// Create a handle for the session to pass safely to C
	h := cgo.NewHandle(session)
	defer h.Delete()

	// Call Rust transfer function
	result := C.transfer_data(
		C.intptr_t(sourceFd),
		C.intptr_t(destFd),
		C.int64_t(session.FileSize),
		session.Cancelled,
		C.progress_callback_t(C.goProgressCallback),
		unsafe.Pointer(h),
	)

	if result != C.SUCCESS {
		return fmt.Errorf("transfer failed with code: %d", result)
	}

	return nil
}

func progressUpdater(session *TransferSession, stop chan bool) {
	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()

	encoder := json.NewEncoder(session.Client)

	for {
		select {
		case <-ticker.C:
			session.mu.Lock()
			transferred := session.BytesTransferred
			total := session.FileSize
			lastBytes := session.LastBytes
			lastTime := session.LastUpdateTime
			now := time.Now()

			// Calculate interval speed
			bytesDiff := transferred - lastBytes
			timeDiff := now.Sub(lastTime).Seconds()

			session.LastBytes = transferred
			session.LastUpdateTime = now
			session.mu.Unlock()

			percentage := float64(transferred) / float64(total) * 100.0

			var speed float64
			if timeDiff > 0 {
				speed = float64(bytesDiff) / timeDiff / 1024 / 1024 // MB/s
			}

			response := map[string]interface{}{
				"type":              "TRANSFER_PROGRESS",
				"transfer_id":       session.ID,
				"percentage":        percentage,
				"bytes_transferred": transferred,
				"total_bytes":       total,
				"speed_mbps":        speed,
			}

			encoder.Encode(response)

		case <-stop:
			return
		}
	}
}

func sendTransferComplete(session *TransferSession) {
	response := map[string]interface{}{
		"type":        "TRANSFER_COMPLETE",
		"transfer_id": session.ID,
		"status":      "success",
	}
	encoder := json.NewEncoder(session.Client)
	encoder.Encode(response)
}

func sendTransferError(session *TransferSession, err error) {
	response := map[string]interface{}{
		"type":        "TRANSFER_ERROR",
		"transfer_id": session.ID,
		"error":       err.Error(),
	}
	encoder := json.NewEncoder(session.Client)
	encoder.Encode(response)
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

	// 1. Receive file metadata (first 4KB or until newline)
	// For simplicity in this protocol, we'll wait for a JSON header
	reader := json.NewDecoder(conn)
	var header struct {
		FileName string `json:"file_name"`
		FileSize int64  `json:"file_size"`
	}

	if err := reader.Decode(&header); err != nil {
		fmt.Printf("❌ Failed to decode transfer header: %v\n", err)
		return
	}

	destPath := filepath.Join(receiveDir, header.FileName)
	fmt.Printf("📥 Receiving file: %s (%d bytes) -> %s\n", header.FileName, header.FileSize, destPath)

	file, err := os.Create(destPath)
	if err != nil {
		fmt.Printf("❌ Failed to create file: %v\n", err)
		return
	}
	defer file.Close()

	// Notify start
	eventsChan <- map[string]interface{}{
		"type":      "RECEIVE_STARTED",
		"file_name": header.FileName,
		"file_size": header.FileSize,
	}

	// 2. Stream data from connection to file
	// We use io.CopyN if we want to be precise based on header
	start := time.Now()
	transferred, err := io.CopyN(file, conn, header.FileSize)
	if err != nil && err != io.EOF {
		fmt.Printf("❌ Transfer interrupted: %v\n", err)
		eventsChan <- map[string]interface{}{
			"type":  "RECEIVE_ERROR",
			"error": err.Error(),
		}
		return
	}

	duration := time.Since(start)
	fmt.Printf("✅ Received %d bytes in %v\n", transferred, duration)

	// Notify complete
	eventsChan <- map[string]interface{}{
		"type":      "RECEIVE_COMPLETE",
		"file_name": header.FileName,
		"path":      destPath,
	}
}
