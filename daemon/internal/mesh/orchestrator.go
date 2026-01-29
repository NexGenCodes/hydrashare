package mesh

import (
	"encoding/json"
	"fmt"
	"net"
	"sync"
	"time"
)

// Orchestrator manages mesh topology and G2G signaling
type Orchestrator struct {
	HostIP     string
	Peers      map[string]*PeerState
	PeersMu    sync.RWMutex
	EventsChan chan<- map[string]interface{}
}

// PeerState tracks a guest's connection and capabilities
type PeerState struct {
	ID         string
	Name       string
	Conn       net.Conn
	PublicIP   string
	LocalIPs   []string
	Transports []string
	PublicKey  string
}

func NewOrchestrator(hostIP string, eventsChan chan<- map[string]interface{}) *Orchestrator {
	return &Orchestrator{
		HostIP:     hostIP,
		Peers:      make(map[string]*PeerState),
		EventsChan: eventsChan,
	}
}

// IntroducePeers sends discovery cards to all connected guests
func (o *Orchestrator) IntroducePeers(newPeer *PeerState) {
	o.PeersMu.RLock()
	defer o.PeersMu.RUnlock()

	// 1. Tell existing peers about the new peer
	cardForExisting := DiscoveryCard{
		Type:                "PEER_DISCOVERY_CARD",
		PeerID:              newPeer.ID,
		Name:                newPeer.Name,
		IPs:                 newPeer.LocalIPs,
		SupportedTransports: newPeer.Transports,
		PublicKey:           newPeer.PublicKey,
	}

	for _, p := range o.Peers {
		if p.ID == newPeer.ID {
			continue
		}
		json.NewEncoder(p.Conn).Encode(cardForExisting)

		// 2. Tell the new peer about existing peers
		cardForNew := DiscoveryCard{
			Type:                "PEER_DISCOVERY_CARD",
			PeerID:              p.ID,
			Name:                p.Name,
			IPs:                 p.LocalIPs,
			SupportedTransports: p.Transports,
			PublicKey:           p.PublicKey,
		}
		json.NewEncoder(newPeer.Conn).Encode(cardForNew)
		fmt.Printf("🤝 Signalled G2G between %s and %s\n", newPeer.Name, p.Name)
	}
}

// MonitorThermalState checks device temperature and signals throttling
func (o *Orchestrator) MonitorThermalState() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		// Portably check thermal state (Simplified for demonstration)
		// On Android: Read /sys/class/thermal/thermal_zone*/temp
		// On Windows: WMI query
		temp := o.getDeviceTemp()
		if temp > 70 { // 70°C threshold
			fmt.Printf("🔥 Thermal Warning: Device at %d°C. Requesting throttle.\n", temp)
			if o.EventsChan != nil {
				o.EventsChan <- map[string]interface{}{
					"type":       "THERMAL_THROTTLE",
					"temp":       temp,
					"suggestion": "lower_bandwidth",
				}
			}
		}
	}
}

func (o *Orchestrator) getDeviceTemp() int {
	// Mock implementation: for real app, use OS specific commands
	return 45 // Normal state
}

func (o *Orchestrator) GetPeer(id string) *PeerState {
	o.PeersMu.RLock()
	defer o.PeersMu.RUnlock()
	return o.Peers[id]
}
