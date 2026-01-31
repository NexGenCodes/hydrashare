package mesh

import (
	"sort"
	"sync"
	"time"
)

const K = 20 // Bucket size
const MaxPeers = 200

type PeerInfo struct {
	ID       string // HydraID (Ed25519 PubKey)
	IP       string
	Port     int
	LastSeen time.Time
}

type KBucket struct {
	peers []PeerInfo
}

type RoutingTable struct {
	mu      sync.RWMutex
	localID string
	buckets []*KBucket
}

func NewRoutingTable(localID string) *RoutingTable {
	return &RoutingTable{
		localID: localID,
		buckets: []*KBucket{{peers: make([]PeerInfo, 0)}},
	}
}

func (rt *RoutingTable) Update(peer PeerInfo) {
	rt.mu.Lock()
	defer rt.mu.Unlock()

	// 1. Find the bucket (simplification: we use a single bucket for now or a small subset)
	// In a real DHT, we'd use XOR distance. Here we use a simpler peer limit for Hydra's "Viral" mesh.

	bucket := rt.buckets[0]
	for i, p := range bucket.peers {
		if p.ID == peer.ID {
			bucket.peers[i] = peer // Update existing
			return
		}
	}

	if len(bucket.peers) < MaxPeers {
		bucket.peers = append(bucket.peers, peer)
	} else {
		// Evict oldest if full
		sort.Slice(bucket.peers, func(i, j int) bool {
			return bucket.peers[i].LastSeen.Before(bucket.peers[j].LastSeen)
		})
		bucket.peers[0] = peer
	}
}

func (rt *RoutingTable) GetRandomPeers(n int) []PeerInfo {
	rt.mu.RLock()
	defer rt.mu.RUnlock()

	bucket := rt.buckets[0]
	if len(bucket.peers) <= n {
		return bucket.peers
	}

	// Simple shuffle pick
	peers := make([]PeerInfo, len(bucket.peers))
	copy(peers, bucket.peers)
	return peers[:n]
}

func (rt *RoutingTable) Remove(peerID string) {
	rt.mu.Lock()
	defer rt.mu.Unlock()

	bucket := rt.buckets[0]
	for i, p := range bucket.peers {
		if p.ID == peerID {
			bucket.peers = append(bucket.peers[:i], bucket.peers[i+1:]...)
			break
		}
	}
}
