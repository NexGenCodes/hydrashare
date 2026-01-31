package transfer

import (
	"log"
	"os"
	"path/filepath"
	"time"
)

// StartScrubber runs a background worker that deletes old files
func StartScrubber(downloadDir string) {
	ticker := time.NewTicker(1 * time.Hour)
	go func() {
		for range ticker.C {
			log.Println("🧹 Scrubbing downloads folder (7-day TTL)...")
			scrub(downloadDir)
		}
	}()
}

func scrub(dir string) {
	files, err := os.ReadDir(dir)
	if err != nil {
		log.Printf("⚠️  Scrubber failed to read dir: %v", err)
		return
	}

	now := time.Now()
	threshold := 7 * 24 * time.Hour

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		info, err := file.Info()
		if err != nil {
			continue
		}

		// Delete if older than threshold
		if now.Sub(info.ModTime()) > threshold {
			path := filepath.Join(dir, file.Name())
			if err := os.Remove(path); err != nil {
				log.Printf("❌ Failed to delete old file %s: %v", path, err)
			} else {
				log.Printf("🗑️  Auto-deleted old file: %s", file.Name())
			}
		}
	}
}
