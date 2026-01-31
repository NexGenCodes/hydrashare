package mesh

import (
	"encoding/json"
	"fmt"
	"net"
	"time"
)

// Emitter defines a generic interface for sending events to the UI/Bridge
type Emitter interface {
	Emit(event interface{})
}

// Orchestrator manages mesh topology and G2G signaling
type Orchestrator struct {
	HostIP   string
	Registry *PeerRegistry
	Emitter  Emitter
}

// PeerState tracks a guest's connection and capabilities
type PeerState struct {
	ID           string
	Name         string
	Conn         net.Conn
	PublicIP     string
	LocalIPs     []string
	Transports   []string
	PublicKey    string
	TransferPort int
}

func NewOrchestrator(hostIP string, registry *PeerRegistry, emitter Emitter) *Orchestrator {
	return &Orchestrator{
		HostIP:   hostIP,
		Registry: registry,
		Emitter:  emitter,
	}
}

// IntroducePeers sends discovery cards to all connected guests
func (o *Orchestrator) IntroducePeers(newPeer *PeerState) {
	peers := o.Registry.GetAllPeers()

	// 1. Tell existing peers about the new peer
	cardForExisting := DiscoveryCard{
		Type:                "PEER_DISCOVERY_CARD",
		PeerID:              newPeer.ID,
		Name:                newPeer.Name,
		IPs:                 newPeer.LocalIPs,
		SupportedTransports: newPeer.Transports,
		PublicKey:           newPeer.PublicKey,
	}

	for _, p := range peers {
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
			if o.Emitter != nil {
				o.Emitter.Emit(map[string]interface{}{
					"type":       "THERMAL_THROTTLE",
					"temp":       temp,
					"suggestion": "lower_bandwidth",
				})
			}
		}
	}
}

func (o *Orchestrator) getDeviceTemp() int {
	// Mock implementation: for real app, use OS specific commands
	return 45 // Normal state
}

// CoordinateG2GTransfer tells Guest A and Guest B to connect to each other for a file transfer
func (o *Orchestrator) CoordinateG2GTransfer(senderID, receiverID, fileName, transferID string, startOffset int64) error {
	sender := o.Registry.GetPeer(senderID)
	receiver := o.Registry.GetPeer(receiverID)

	if sender == nil || receiver == nil {
		return fmt.Errorf("one or both peers not found in mesh")
	}

	// Tell Receiver about Sender
	introToReceiver := G2GTransferIntro{
		Type:        "G2G_TRANSFER_INTRO",
		TargetPeer:  sender.ID,
		PeerName:    sender.Name,
		PeerIPs:     sender.LocalIPs,
		TransferID:  transferID,
		FileName:    fileName,
		IsSender:    false,
		StartOffset: startOffset,
	}

	// Tell Sender about Receiver
	introToSender := G2GTransferIntro{
		Type:        "G2G_TRANSFER_INTRO",
		TargetPeer:  receiver.ID,
		PeerName:    receiver.Name,
		PeerIPs:     receiver.LocalIPs,
		TransferID:  transferID,
		FileName:    fileName,
		IsSender:    true,
		StartOffset: startOffset,
	}

	// Send signals
	if err := json.NewEncoder(receiver.Conn).Encode(introToReceiver); err != nil {
		return fmt.Errorf("failed to signal receiver: %v", err)
	}
	if err := json.NewEncoder(sender.Conn).Encode(introToSender); err != nil {
		return fmt.Errorf("failed to signal sender: %v", err)
	}

	fmt.Printf("📂 Coordinated G2G transfer: %s -> %s for '%s' (start: %d)\n", sender.Name, receiver.Name, fileName, startOffset)
	return nil
}

func (o *Orchestrator) GetPeer(id string) *PeerState {
	return o.Registry.GetPeer(id)
}
