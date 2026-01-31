//go:build android

package main

/*
#include <stdlib.h>
#include <android/log.h>

static void android_log(const char* msg) {
    __android_log_print(ANDROID_LOG_INFO, "HydraDaemon", "%s", msg);
}
*/
import "C"
import (
	"encoding/json"
	"fmt"
	"log"
	"runtime/debug"
	"unsafe"
)

func main() {}

// MyLog logs a message to Android logcat
func MyLog(format string, v ...interface{}) {
	msg := fmt.Sprintf(format, v...)
	cmsg := C.CString(msg)
	defer C.free(unsafe.Pointer(cmsg))
	C.android_log(cmsg)
}

//export InitDaemon
func InitDaemon() {
	// Start the daemon startup logic in a background goroutine
	// because FFI calls shouldn't block the caller too long.
	go func() {
		defer func() {
			if r := recover(); r != nil {
				msg := fmt.Sprintf("🛑 CRITICAL PANIC in Go Daemon: %v\nStack: %s", r, debug.Stack())
				MyLog(msg)
			}
		}()

		log.SetOutput(logWriter{}) // Redirect standard log to Android logcat

		// Re-use the shared StartDaemon logic
		// But for Android, we might need slightly different behavior (e.g., waiting for frontend)
		// For now, we replicate what was in InitDaemon previously
		StartDaemon()
	}()
}

//export SendDaemonCommand
func SendDaemonCommand(jsonCmd *C.char) {
	// Bridge FFI calls into the existing command handler
	cmdStr := C.GoString(jsonCmd)
	var cmd Command
	if err := json.Unmarshal([]byte(cmdStr), &cmd); err != nil {
		return
	}
	// TODO: Implement command handling bridge if needed using channels
}

type logWriter struct{}

func (logWriter) Write(p []byte) (n int, err error) {
	MyLog(string(p))
	return len(p), nil
}
