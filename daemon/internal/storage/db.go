package storage

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

type Database struct {
	db *sql.DB
}

func NewDatabase() (*Database, error) {
	home, _ := os.UserHomeDir()
	dbDir := filepath.Join(home, ".hydrashare")
	os.MkdirAll(dbDir, 0755)

	dbPath := filepath.Join(dbDir, "hydra.db")
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	d := &Database{db: db}
	if err := d.init(); err != nil {
		return nil, err
	}

	// Start scrubbing worker
	go d.scrubWorker()

	return d, nil
}

func (d *Database) init() error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS messages (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			peer_ip TEXT,
			sender TEXT,
			content TEXT,
			unread INTEGER DEFAULT 1,
			is_broadcast INTEGER DEFAULT 0,
			timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS transfers (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			transfer_id TEXT,
			file_name TEXT,
			peer_ip TEXT,
			direction TEXT, -- 'send' or 'receive'
			status TEXT,
			timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE IF NOT EXISTS resumption_tokens (
			token_id TEXT PRIMARY KEY,
			file_path TEXT,
			bytes_completed INTEGER,
			total_size INTEGER,
			peer_public_key TEXT,
			expires_at DATETIME
		)`,
		`CREATE TABLE IF NOT EXISTS peer_cards (
			peer_id TEXT PRIMARY KEY,
			last_known_ip TEXT,
			supported_transports TEXT, -- JSON array
			last_seen DATETIME
		)`,
	}

	for _, q := range queries {
		if _, err := d.db.Exec(q); err != nil {
			return fmt.Errorf("failed to initialize table: %w", err)
		}
	}
	return nil
}

func (d *Database) SaveMessage(peerIP, sender, content string, isBroadcast bool) error {
	isB := 0
	if isBroadcast {
		isB = 1
	}
	_, err := d.db.Exec(
		"INSERT INTO messages (peer_ip, sender, content, is_broadcast) VALUES (?, ?, ?, ?)",
		peerIP, sender, content, isB,
	)
	return err
}

func (d *Database) SaveTransfer(transferID, fileName, peerIP, direction, status string) error {
	_, err := d.db.Exec(
		"INSERT INTO transfers (transfer_id, file_name, peer_ip, direction, status) VALUES (?, ?, ?, ?, ?)",
		transferID, fileName, peerIP, direction, status,
	)
	return err
}

func (d *Database) scrubWorker() {
	ticker := time.NewTicker(6 * time.Hour)
	for range ticker.C {
		log.Println("🧹 Scrubbing database (7-day TTL)...")
		res, err := d.db.Exec("DELETE FROM messages WHERE timestamp < datetime('now', '-7 days')")
		if err == nil {
			rows, _ := res.RowsAffected()
			if rows > 0 {
				log.Printf("🗑️ Scrubbed %d old messages", rows)
			}
		}

		res, err = d.db.Exec("DELETE FROM transfers WHERE timestamp < datetime('now', '-7 days')")
		if err == nil {
			rows, _ := res.RowsAffected()
			if rows > 0 {
				log.Printf("🗑️ Scrubbed %d old transfers", rows)
			}
		}
	}
}

func (d *Database) SaveResumptionToken(tokenID, filePath string, bytesCompleted, totalSize int64, peerPubKey string) error {
	expiresAt := time.Now().Add(24 * time.Hour)
	_, err := d.db.Exec(
		"INSERT OR REPLACE INTO resumption_tokens (token_id, file_path, bytes_completed, total_size, peer_public_key, expires_at) VALUES (?, ?, ?, ?, ?, ?)",
		tokenID, filePath, bytesCompleted, totalSize, peerPubKey, expiresAt,
	)
	return err
}

func (d *Database) GetResumptionToken(tokenID string) (filePath string, bytesCompleted int64, totalSize int64, err error) {
	err = d.db.QueryRow(
		"SELECT file_path, bytes_completed, total_size FROM resumption_tokens WHERE token_id = ? AND expires_at > ?",
		tokenID, time.Now(),
	).Scan(&filePath, &bytesCompleted, &totalSize)
	return
}

func (d *Database) MarkAsRead(peerIP string) error {
	_, err := d.db.Exec("UPDATE messages SET unread = 0 WHERE peer_ip = ? AND unread = 1", peerIP)
	return err
}

func (d *Database) Close() error {
	return d.db.Close()
}
