//go:build !android

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"encoding/json"
	"sync"
)

var (
	ffiOnce sync.Once
	// We use a channel to bridge FFI commands into the daemon loop
	ffiCommandChan = make(chan Command, 10)
)

//export InitDaemon
func InitDaemon() {
	ffiOnce.Do(func() {
		MyLog("🚀 Daemon initializing via FFI bridge")

		go func() {
			defer func() {
				if r := recover(); r != nil {
					MyLog("🔥 CRITICAL: FFI Daemon Panic: %v", r)
				}
			}()

			// Re-use the shared StartDaemon logic
			StartDaemon()
		}()
	})
}

//export SendDaemonCommand
func SendDaemonCommand(jsonCmd *C.char) {
	cmdStr := C.GoString(jsonCmd)
	var cmd Command
	if err := json.Unmarshal([]byte(cmdStr), &cmd); err != nil {
		MyLog("❌ FFI Command Parse Error: %v", err)
		return
	}

	MyLog("📩 FFI Command Received: %s", cmd.Type)

	// If we need to inject this into the running daemon:
	// ffiCommandChan <- cmd

	// Note: Currently, the Flutter app connects via TCP to localhost:5050
	// after starting the daemon via FFI. This is a robust "hybrid" approach
	// that works well on both Desktop and Mobile.
}
