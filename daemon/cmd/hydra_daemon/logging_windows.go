//go:build !android

package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"
)

var logFile *os.File

func init() {
	// Setup file logging - Lightweight mode
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}
	logPath := filepath.Join(configDir, "HydraShare", "daemon.log")
	os.MkdirAll(filepath.Dir(logPath), 0755)

	// Check file size to prevent bloat
	stat, err := os.Stat(logPath)
	if err == nil && stat.Size() > 5*1024*1024 { // 5MB Limit
		os.Remove(logPath) // Simple rotation: delete if too big
	}

	logFile, err = os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("Failed to open log file: %v", err)
	}
}

// MyLog handles platform-standard logging for Desktop/Windows
func MyLog(format string, v ...interface{}) {
	msg := fmt.Sprintf(format, v...)
	log.Println(msg) // Write to console

	if logFile != nil {
		timestamp := time.Now().Format("2006-01-02 15:04:05")
		fmt.Fprintf(logFile, "[%s] %s\n", timestamp, msg)
	}
}
