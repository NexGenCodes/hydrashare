package connectivity

import (
	"log"
	"net"
	"strings"
)

type NetworkType int

const (
	None NetworkType = iota
	Ethernet
	WiFi
	Hotspot
)

// Manager handles network connectivity logic
type Manager struct {
	EventsChan chan<- map[string]interface{}
}

func NewManager(eventsChan chan<- map[string]interface{}) *Manager {
	return &Manager{
		EventsChan: eventsChan,
	}
}

// CheckConnectivity scans interfaces and returns the best available network type
func (m *Manager) CheckConnectivity() NetworkType {
	interfaces, err := net.Interfaces()
	if err != nil {
		log.Printf("⚠️  Failed to get interfaces: %v", err)
		return None
	}

	bestType := None

	for _, iface := range interfaces {
		// Skip loopback and down interfaces
		if iface.Flags&net.FlagLoopback != 0 || iface.Flags&net.FlagUp == 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil || len(addrs) == 0 {
			continue
		}

		name := strings.ToLower(iface.Name)

		// Heuristic detection based on common interface names
		if isEthernet(name) {
			return Ethernet // Highest priority
		}

		if isWiFi(name) {
			if bestType < WiFi {
				bestType = WiFi
			}
		}
	}

	if bestType == None {
		log.Println("🌲 Forest Mode: No router found, triggering WIFI_DIRECT_REQ")
		m.triggerWiFiDirect()
	}

	return bestType
}

func isEthernet(name string) bool {
	return strings.Contains(name, "eth") || strings.Contains(name, "en") || strings.Contains(name, "ethernet")
}

func isWiFi(name string) bool {
	return strings.Contains(name, "wlan") || strings.Contains(name, "wifi") || strings.Contains(name, "wireless")
}

func (m *Manager) triggerWiFiDirect() {
	if m.EventsChan != nil {
		m.EventsChan <- map[string]interface{}{
			"type":   "WIFI_DIRECT_REQ",
			"status": "searching",
		}
	}
}
