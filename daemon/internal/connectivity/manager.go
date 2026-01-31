package connectivity

import (
	"fmt"
	"log"
	"net"
	"os/exec"
	"strings"
	"sync"
	"time"
)

type NetworkType int

const (
	None NetworkType = iota
	Ethernet
	WiFiDirect
	Hotspot
	WiFi
)

// Emitter defines a generic interface for sending events to the UI/Bridge
type Emitter interface {
	Emit(event interface{})
}

// Manager handles network connectivity logic
type Manager struct {
	Emitter   Emitter
	Proximity map[string]*PeerProximity
	ProxMu    sync.RWMutex
}

type PeerProximity struct {
	IP         string
	AverageRTT time.Duration
	Samples    []time.Duration
}

func NewManager(emitter Emitter) *Manager {
	return &Manager{
		Emitter:   emitter,
		Proximity: make(map[string]*PeerProximity),
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
		if iface.Flags&net.FlagLoopback != 0 || iface.Flags&net.FlagUp == 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil || len(addrs) == 0 {
			continue
		}

		name := strings.ToLower(iface.Name)

		// 1. Ethernet (Highest Priority)
		if isEthernet(name) {
			return Ethernet
		}

		// 2. WiFi Direct / P2P
		if isWiFiDirect(name) {
			if bestType == None || bestType > WiFiDirect {
				bestType = WiFiDirect
			}
			continue
		}

		// 3. Hotspot / Access Point
		if isHotspot(name) {
			if bestType == None || bestType > Hotspot {
				bestType = Hotspot
			}
			continue
		}

		// 4. Standard WiFi
		if isWiFi(name) {
			if bestType == None || bestType > WiFi {
				bestType = WiFi
			}
		}
	}

	if bestType == None {
		log.Println("🌲 Forest Mode: No suitable network found, triggering WIFI_DIRECT_REQ")
		m.triggerWiFiDirect()
	}

	return bestType
}

func isEthernet(name string) bool {
	return strings.Contains(name, "eth") || strings.Contains(name, "en") || strings.Contains(name, "ethernet")
}

func isWiFiDirect(name string) bool {
	return strings.Contains(name, "p2p") || strings.Contains(name, "wlan-p2p") || strings.Contains(name, "direct")
}

func isHotspot(name string) bool {
	return strings.Contains(name, "ap0") || strings.Contains(name, "softap") || strings.Contains(name, "hotspot")
}

func isWiFi(name string) bool {
	return strings.Contains(name, "wlan") || strings.Contains(name, "wifi") || strings.Contains(name, "wireless")
}

func (m *Manager) triggerWiFiDirect() {
	if m.Emitter != nil {
		m.Emitter.Emit(map[string]interface{}{
			"type":   "WIFI_DIRECT_REQ",
			"status": "searching",
		})
	}
}

// GetLocalIPs returns all non-loopback IPv4 addresses
func GetLocalIPs() ([]net.IP, error) {
	var ips []net.IP

	// 1. Try standard interface lookup
	addrs, err := net.InterfaceAddrs()
	if err == nil {
		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
				if ipnet.IP.To4() != nil {
					ips = append(ips, ipnet.IP)
				}
			}
		}
	}

	// 2. Fallback Probes (Android SELinux bypass)
	// We try to "dial" various targets to see what our local source IP becomes.
	// This doesn't actually send packets if we don't Write() to the connection.
	if len(ips) == 0 {
		targets := []string{
			"8.8.8.8:80",     // Internet (Google)
			"1.1.1.1:80",     // Internet (Cloudflare)
			"192.168.0.1:80", // Common Gateway
			"192.168.1.1:80", // Common Gateway
		}

		for _, target := range targets {
			conn, err := net.DialTimeout("udp", target, 200*time.Millisecond)
			if err == nil {
				localAddr := conn.LocalAddr().(*net.UDPAddr)
				if !localAddr.IP.IsLoopback() && localAddr.IP.To4() != nil {
					ips = append(ips, localAddr.IP)
					log.Printf("🌐 Found local IP via UDP probe (%s): %v", target, localAddr.IP)
					conn.Close()
					break // Found one, that's usually enough
				}
				conn.Close()
			}
		}
	}

	// 3. Absolute fallback to localhost
	if len(ips) == 0 {
		ips = append(ips, net.ParseIP("127.0.0.1"))
	}

	return ips, nil
}

// StartProximityMonitor tracks a peer's latency over time
func (m *Manager) StartProximityMonitor(ip string, stopChan <-chan struct{}) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-stopChan:
			return
		case <-ticker.C:
			rtt, err := m.measureRTT(ip)
			if err != nil {
				log.Printf("⚠️  Proximity check failed for %s: %v", ip, err)
				continue
			}

			m.updateProximity(ip, rtt)
		}
	}
}

func (m *Manager) measureRTT(ip string) (time.Duration, error) {
	start := time.Now()
	// Practical hack: Dial a UDP port (doesn't need to be open to measure interface RTT)
	// or perform a simple TCP connection check.
	conn, err := net.DialTimeout("udp", net.JoinHostPort(ip, "5052"), 1*time.Second)
	if err != nil {
		return 0, err
	}
	conn.Close()
	return time.Since(start), nil
}

func (m *Manager) updateProximity(ip string, rtt time.Duration) {
	m.ProxMu.Lock()
	defer m.ProxMu.Unlock()

	p, ok := m.Proximity[ip]
	if !ok {
		p = &PeerProximity{IP: ip, Samples: []time.Duration{}}
		m.Proximity[ip] = p
	}

	// Keep last 5 samples
	p.Samples = append(p.Samples, rtt)
	if len(p.Samples) > 5 {
		p.Samples = p.Samples[1:]
	}

	// Calculate average
	var sum time.Duration
	for _, s := range p.Samples {
		sum += s
	}
	p.AverageRTT = sum / time.Duration(len(p.Samples))

	// If average RTT > 1 second over 5 samples, trigger disconnect warning
	if p.AverageRTT > 1000*time.Millisecond && len(p.Samples) >= 5 {
		log.Printf("🚨 Proximity Alert: %s is drifting (Avg RTT: %v)", ip, p.AverageRTT)
		if m.Emitter != nil {
			m.Emitter.Emit(map[string]interface{}{
				"type":    "PROXIMITY_WARNING",
				"peer_ip": ip,
				"avg_rtt": p.AverageRTT.String(),
			})
		}
	}
}

// MonitorSignalStrength watches for RSSI drops and warns the UI
func (m *Manager) MonitorSignalStrength() {
	ticker := time.NewTicker(10 * time.Second)
	go func() {
		for range ticker.C {
			signal := m.getSignalStrength()
			if signal > 0 && signal < 30 { // 30% roughly maps to -85dBm
				log.Printf("⚠️  Low Signal Warning: %d%%", signal)
				if m.Emitter != nil {
					m.Emitter.Emit(map[string]interface{}{
						"type":   "LOW_SIGNAL_WARNING",
						"signal": signal,
					})
				}
			}
		}
	}()
}

func (m *Manager) getSignalStrength() int {
	return getWindowsSignal()
}

func getWindowsSignal() int {
	out, err := exec.Command("netsh", "wlan", "show", "interfaces").Output()
	if err != nil {
		return 100 // Fallback
	}

	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		if strings.Contains(line, "Signal") {
			parts := strings.Split(line, ":")
			if len(parts) > 1 {
				sigStr := strings.TrimSpace(parts[1])
				sigStr = strings.TrimSuffix(sigStr, "%")
				var sig int
				fmt.Sscanf(sigStr, "%d", &sig)
				return sig
			}
		}
	}
	return 100
}
