package mesh

import (
	"fmt"
	"net"
	"sync"
	"time"
)

// PeerRegistry manages the state of all connected peers in the mesh
type PeerRegistry struct {
	peers      map[string]*PeerState
	mu         sync.RWMutex
	emitter    Emitter
	offers     map[string]string   // OfferID -> FilePath
	meshFiles  map[string][]string // FileName -> List of Peer IDs
	blockedIPs map[string]bool
	mutedIPs   map[string]bool
	routing    *RoutingTable
}

func NewPeerRegistry(emitter Emitter, localID string) *PeerRegistry {
	return &PeerRegistry{
		peers:      make(map[string]*PeerState),
		emitter:    emitter,
		offers:     make(map[string]string),
		meshFiles:  make(map[string][]string),
		blockedIPs: make(map[string]bool),
		mutedIPs:   make(map[string]bool),
		routing:    NewRoutingTable(localID),
	}
}

// RegisterPeer adds or updates a peer in the registry
func (r *PeerRegistry) RegisterPeer(state *PeerState) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.peers[state.ID] = state
	r.routing.Update(PeerInfo{
		ID:       state.ID,
		IP:       state.PublicIP,
		Port:     state.TransferPort,
		LastSeen: time.Now(),
	})
	fmt.Printf("📝 Registered peer: %s (%s)\n", state.Name, state.ID)

	if r.emitter != nil {
		r.emitter.Emit(map[string]interface{}{
			"type": "PEER_CONNECTED",
			"ip":   state.ID,
			"name": state.Name,
		})
	}
}

// UnregisterPeer removes a peer from the registry
func (r *PeerRegistry) UnregisterPeer(id string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if peer, ok := r.peers[id]; ok {
		if peer.Conn != nil {
			peer.Conn.Close()
		}
		delete(r.peers, id)
		fmt.Printf("🔌 Unregistered peer: %s\n", id)

		if r.emitter != nil {
			r.emitter.Emit(map[string]interface{}{
				"type": "PEER_DISCONNECTED",
				"ip":   id,
			})
		}
	}
}

// GetPeer retrieves a peer state by ID
func (r *PeerRegistry) GetPeer(id string) *PeerState {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.peers[id]
}

// GetAllPeers returns a slice of all registered peers
func (r *PeerRegistry) GetAllPeers() []*PeerState {
	r.mu.RLock()
	defer r.mu.RUnlock()

	all := make([]*PeerState, 0, len(r.peers))
	for _, p := range r.peers {
		all = append(all, p)
	}
	return all
}

// UpdatePeerName updates the display name for a peer
func (r *PeerRegistry) UpdatePeerName(id string, name string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if p, ok := r.peers[id]; ok {
		p.Name = name
	}
}

// GetConnection returns the network connection for a peer
func (r *PeerRegistry) GetConnection(id string) net.Conn {
	r.mu.RLock()
	defer r.mu.RUnlock()

	if p, ok := r.peers[id]; ok {
		return p.Conn
	}
	return nil
}

// --- File Offer Management ---

func (r *PeerRegistry) AddOffer(id, path string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.offers[id] = path
}

func (r *PeerRegistry) RemoveOffer(id string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.offers, id)
}

func (r *PeerRegistry) GetOfferPath(id string) (string, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	path, ok := r.offers[id]
	return path, ok
}

// --- Mesh Knowledge ---

func (r *PeerRegistry) AddMeshFile(fileName, peerID string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.meshFiles[fileName] = append(r.meshFiles[fileName], peerID)
}

func (r *PeerRegistry) GetMeshProviders(fileName string) []string {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.meshFiles[fileName]
}

// --- ACL (Security) ---

func (r *PeerRegistry) BlockIP(ip string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.blockedIPs[ip] = true
}

func (r *PeerRegistry) IsBlocked(ip string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.blockedIPs[ip]
}

func (r *PeerRegistry) SetMuted(ip string, muted bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if muted {
		r.mutedIPs[ip] = true
	} else {
		delete(r.mutedIPs, ip)
	}
}

func (r *PeerRegistry) IsMuted(ip string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.mutedIPs[ip]
}

// IsPeerOnline checks if a peer with the given IP or ID is currently registered
func (r *PeerRegistry) IsPeerOnline(ipOrID string) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()

	// Direct ID check
	if _, ok := r.peers[ipOrID]; ok {
		return true
	}

	// Secondary IP scan
	for _, p := range r.peers {
		if p.PublicIP == ipOrID {
			return true
		}
	}
	return false
}
