package transfer

import (
	"hydra_share/daemon/internal/storage"
	"log"
	"time"
)

type QueueManager struct {
	db *storage.Database
}

func NewQueueManager(db *storage.Database) *QueueManager {
	return &QueueManager{db: db}
}

// AddToQueue registers a new transfer in the database
func (q *QueueManager) AddToQueue(transferID, fileName, peerIP, direction string) error {
	return q.db.SaveTransfer(transferID, fileName, peerIP, direction, "pending")
}

// GetPendingTransfers returns all transfers that haven't completed or failed
func (q *QueueManager) GetPendingTransfers() ([]map[string]interface{}, error) {
	return q.db.GetPendingTransfers()
}

// ProcessQueue checks for online peers and resumes their transfers with backoff
func (q *QueueManager) ProcessQueue(getPeerStatus func(string) bool, resumeFunc func(transferID string)) {
	ticker := time.NewTicker(2 * time.Minute)
	retries := make(map[string]int) // Track retries per transferID

	go func() {
		for range ticker.C {
			log.Println("🔄 Checking persistent queue for resume opportunities...")
			pending, err := q.GetPendingTransfers()
			if err != nil {
				continue
			}

			for _, t := range pending {
				peerIP := t["ip"].(string)
				transferID := t["id"].(string)

				// Skip if we've retried too many times recently
				if retries[transferID] > 10 {
					// Exponential backoff: only check every 10 ticks for dead-ish peers
					if time.Now().Unix()%10 != 0 {
						continue
					}
				}

				if getPeerStatus(peerIP) {
					log.Printf("🚀 Peer %s is back online! Resuming transfer %s\n", peerIP, transferID)
					resumeFunc(transferID)
					delete(retries, transferID)
				} else {
					retries[transferID]++
				}
			}
		}
	}()
}
