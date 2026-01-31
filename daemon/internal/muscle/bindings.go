package muscle

/*
#cgo windows LDFLAGS: -lhydra_muscle -lws2_32 -luserenv -lbcrypt
#include <stdlib.h>
#include <stdint.h>

// Forward declaration of callback
void progressCallback(int64_t transferred, int64_t total, void* user_data);

// Declare C functions exported by Rust
extern int32_t transfer_data(
    intptr_t source_fd,
    intptr_t dest_fd,
    int64_t file_size,
    int64_t start_offset,
    const uint8_t* key_ptr,
    size_t key_len,
    uint8_t* hash_output,
    int32_t throttle_ms,
    const int32_t* cancel_flag,
    void* callback,
    void* user_data
);

extern int32_t receive_data(
    intptr_t source_fd,
    intptr_t dest_fd,
    int64_t expected_size,
    const uint8_t* key_ptr,
    size_t key_len,
    uint8_t* hash_output,
    int32_t throttle_ms,
    const int32_t* cancel_flag,
    void* callback,
    void* user_data
);

extern int32_t transfer_data_quic(
    const char* target_addr,
    const char* file_path,
    int64_t file_size,
    int64_t start_offset,
    const uint8_t* key_ptr,
    size_t key_len,
    uint8_t* hash_output,
    int32_t throttle_ms,
    const int32_t* cancel_flag,
    void* callback,
    void* user_data
);

extern int32_t receive_data_quic(
    const char* listen_addr,
    const char* dest_path,
    int64_t expected_size,
    const uint8_t* key_ptr,
    size_t key_len,
    uint8_t* hash_output,
    int32_t throttle_ms,
    const int32_t* cancel_flag,
    void* callback,
    void* user_data
);
extern int32_t calculate_file_hash(
    const char* file_path,
    uint8_t* hash_output,
    size_t hash_len
);
*/
import "C"

import (
	"errors"
	"fmt"
	"os"
	"sync"
	"unsafe"
)

var (
	cbMu     sync.Mutex
	cbMap            = make(map[uintptr]func(int64, int64))
	nextCbID uintptr = 1
)

// ProgressCallback defines the signature for update events
type ProgressCallback func(transferred, total int64)

//export progressCallback
func progressCallback(transferred, total C.int64_t, userData unsafe.Pointer) {
	id := uintptr(userData)
	cbMu.Lock()
	cb := cbMap[id]
	cbMu.Unlock()
	if cb != nil {
		cb(int64(transferred), int64(total))
	}
}

func registerCallback(cb func(int64, int64)) uintptr {
	cbMu.Lock()
	defer cbMu.Unlock()
	id := nextCbID
	nextCbID++
	cbMap[id] = cb
	return id
}

func unregisterCallback(id uintptr) {
	cbMu.Lock()
	defer cbMu.Unlock()
	delete(cbMap, id)
}

// TransferData bridges the Go call to Rust's transfer_data
func TransferData(sourceFile *os.File, destConnFile *os.File, fileSize, startOffset int64, key []byte, throttleMs int, cancelFlag *int32, onProgress func(int64, int64)) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("invalid key length, must be 32 bytes")
	}

	keyPtr := (*C.uint8_t)(unsafe.Pointer(&key[0]))
	hashOut := make([]byte, 32)
	hashPtr := (*C.uint8_t)(unsafe.Pointer(&hashOut[0]))

	// Register Callback
	var cbID uintptr
	var cbPtr unsafe.Pointer
	if onProgress != nil {
		cbID = registerCallback(onProgress)
		cbPtr = unsafe.Pointer(cbID)
		defer unregisterCallback(cbID)
	}

	// Get FD
	srcFd := C.intptr_t(sourceFile.Fd())
	dstFd := C.intptr_t(destConnFile.Fd())

	ret := C.transfer_data(
		srcFd,
		dstFd,
		C.int64_t(fileSize),
		C.int64_t(startOffset),
		keyPtr,
		C.size_t(len(key)),
		hashPtr,
		C.int32_t(throttleMs),
		(*C.int32_t)(cancelFlag),
		C.progressCallback, // The C function pointer
		cbPtr,              // user_data
	)

	if ret == 0 {
		return hashOut, nil
	}
	return nil, fmt.Errorf("rust transfer failed with code %d", ret)
}

// ReceiveData bridges the Go call to Rust's receive_data
func ReceiveData(sourceConnFile *os.File, destFile *os.File, expectedSize int64, key []byte, throttleMs int, cancelFlag *int32, onProgress func(int64, int64)) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("invalid key length, must be 32 bytes")
	}

	keyPtr := (*C.uint8_t)(unsafe.Pointer(&key[0]))
	hashOut := make([]byte, 32)
	hashPtr := (*C.uint8_t)(unsafe.Pointer(&hashOut[0]))

	// Register Callback
	var cbID uintptr
	var cbPtr unsafe.Pointer
	if onProgress != nil {
		cbID = registerCallback(onProgress)
		cbPtr = unsafe.Pointer(cbID)
		defer unregisterCallback(cbID)
	}

	srcFd := C.intptr_t(sourceConnFile.Fd())
	dstFd := C.intptr_t(destFile.Fd())

	ret := C.receive_data(
		srcFd,
		dstFd,
		C.int64_t(expectedSize),
		keyPtr,
		C.size_t(len(key)),
		hashPtr,
		C.int32_t(throttleMs),
		(*C.int32_t)(cancelFlag),
		C.progressCallback,
		cbPtr,
	)

	if ret == 0 {
		return hashOut, nil
	}
	return nil, fmt.Errorf("rust receive failed with code %d", ret)
}

// TransferDataQuic bridges the Go call to Rust's transfer_data_quic
func TransferDataQuic(targetAddr, filePath string, fileSize, startOffset int64, key []byte, throttleMs int, cancelFlag *int32, onProgress func(int64, int64)) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("invalid key length, must be 32 bytes")
	}

	cTargetAddr := C.CString(targetAddr)
	defer C.free(unsafe.Pointer(cTargetAddr))
	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))

	keyPtr := (*C.uint8_t)(unsafe.Pointer(&key[0]))
	hashOut := make([]byte, 32)
	hashPtr := (*C.uint8_t)(unsafe.Pointer(&hashOut[0]))

	var cbID uintptr
	var cbPtr unsafe.Pointer
	if onProgress != nil {
		cbID = registerCallback(onProgress)
		cbPtr = unsafe.Pointer(cbID)
		defer unregisterCallback(cbID)
	}

	ret := C.transfer_data_quic(
		cTargetAddr,
		cFilePath,
		C.int64_t(fileSize),
		C.int64_t(startOffset),
		keyPtr,
		C.size_t(len(key)),
		hashPtr,
		C.int32_t(throttleMs),
		(*C.int32_t)(cancelFlag),
		C.progressCallback,
		cbPtr,
	)

	if ret == 0 {
		return hashOut, nil
	}
	return nil, fmt.Errorf("rust quic transfer failed with code %d", ret)
}

// ReceiveDataQuic bridges the Go call to Rust's receive_data_quic
func ReceiveDataQuic(listenAddr, destPath string, expectedSize int64, key []byte, throttleMs int, cancelFlag *int32, onProgress func(int64, int64)) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("invalid key length, must be 32 bytes")
	}

	cListenAddr := C.CString(listenAddr)
	defer C.free(unsafe.Pointer(cListenAddr))
	cDestPath := C.CString(destPath)
	defer C.free(unsafe.Pointer(cDestPath))

	keyPtr := (*C.uint8_t)(unsafe.Pointer(&key[0]))
	hashOut := make([]byte, 32)
	hashPtr := (*C.uint8_t)(unsafe.Pointer(&hashOut[0]))

	var cbID uintptr
	var cbPtr unsafe.Pointer
	if onProgress != nil {
		cbID = registerCallback(onProgress)
		cbPtr = unsafe.Pointer(cbID)
		defer unregisterCallback(cbID)
	}

	ret := C.receive_data_quic(
		cListenAddr,
		cDestPath,
		C.int64_t(expectedSize),
		keyPtr,
		C.size_t(len(key)),
		hashPtr,
		C.int32_t(throttleMs),
		(*C.int32_t)(cancelFlag),
		C.progressCallback,
		cbPtr,
	)

	if ret == 0 {
		return hashOut, nil
	}
	return nil, fmt.Errorf("rust quic receive failed with code %d", ret)
}

// CalculateFileHash computes the SHA-256 hash of a local file using Rust
func CalculateFileHash(filePath string) ([]byte, error) {
	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))

	hashOut := make([]byte, 32)
	hashPtr := (*C.uint8_t)(unsafe.Pointer(&hashOut[0]))

	ret := C.calculate_file_hash(cFilePath, hashPtr, C.size_t(len(hashOut)))
	if ret == 0 {
		return hashOut, nil
	}
	return nil, fmt.Errorf("rust hash calculation failed with code %d", ret)
}
