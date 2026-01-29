package discovery

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"github.com/hashicorp/mdns"
)

const (
	ServiceName = "_hydra-share._tcp"
	Domain      = "local."
	Port        = 5050
)

// Peer represents a discovered peer on the network
type Peer struct {
	IP   string
	Name string
	Port int
}

// Service manages mDNS advertising and discovery
type Service struct {
	server    *mdns.Server
	hostname  string
	ctx       context.Context
	cancel    context.CancelFunc
	peersChan chan *Peer
}

// NewService creates a new discovery service
func NewService() (*Service, error) {
	hostname, err := os.Hostname()
	if err != nil {
		hostname = "hydra-unknown"
	}

	ctx, cancel := context.WithCancel(context.Background())

	return &Service{
		hostname:  hostname,
		ctx:       ctx,
		cancel:    cancel,
		peersChan: make(chan *Peer, 10),
	}, nil
}

// StartAdvertising starts advertising this device via mDNS
func (s *Service) StartAdvertising() error {
	// Get local IP addresses
	ips, err := getLocalIPs()
	if err != nil {
		return fmt.Errorf("failed to get local IPs: %w", err)
	}

	// Create mDNS service
	service, err := mdns.NewMDNSService(
		s.hostname,
		ServiceName,
		Domain,
		"",
		Port,
		ips,
		[]string{fmt.Sprintf("hostname=%s", s.hostname)},
	)
	if err != nil {
		return fmt.Errorf("failed to create mDNS service: %w", err)
	}

	// Start the mDNS server
	server, err := mdns.NewServer(&mdns.Config{Zone: service})
	if err != nil {
		return fmt.Errorf("failed to start mDNS server: %w", err)
	}

	s.server = server
	log.Printf("📡 mDNS advertising started as '%s' on port %d", s.hostname, Port)
	return nil
}

// StartDiscovery starts browsing for other HydraShare peers
func (s *Service) StartDiscovery() <-chan *Peer {
	go s.discover()
	return s.peersChan
}

// discover browses for peers continuously
func (s *Service) discover() {
	entriesCh := make(chan *mdns.ServiceEntry, 10)

	go func() {
		for {
			select {
			case <-s.ctx.Done():
				return
			case entry := <-entriesCh:
				// Filter out self-discovery
				if entry.Name == s.hostname+"."+ServiceName+"."+Domain {
					continue
				}

				peer := &Peer{
					IP:   entry.AddrV4.String(),
					Name: entry.Name,
					Port: entry.Port,
				}

				// Use IPv6 if IPv4 is not available
				if peer.IP == "<nil>" && entry.AddrV6 != nil {
					peer.IP = entry.AddrV6.String()
				}

				select {
				case s.peersChan <- peer:
					log.Printf("🔍 Discovered peer: %s (%s:%d)", peer.Name, peer.IP, peer.Port)
				default:
					// Channel full, skip
				}
			}
		}
	}()

	// Browse for peers periodically
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-s.ctx.Done():
			close(entriesCh)
			return
		case <-ticker.C:
			params := mdns.DefaultParams(ServiceName)
			params.Entries = entriesCh
			params.Timeout = 3 * time.Second
			params.DisableIPv6 = false

			if err := mdns.Query(params); err != nil {
				log.Printf("⚠️  Discovery query failed: %v", err)
			}
		}
	}
}

// StopAdvertising stops the mDNS server
func (s *Service) StopAdvertising() {
	if s.server != nil {
		s.server.Shutdown()
		log.Println("📡 mDNS advertising stopped")
	}
}

// StopDiscovery stops browsing for peers
func (s *Service) StopDiscovery() {
	s.cancel()
	close(s.peersChan)
	log.Println("🔍 Peer discovery stopped")
}

// getLocalIPs returns all non-loopback IPv4 addresses
func getLocalIPs() ([]net.IP, error) {
	var ips []net.IP

	// On Android, net.InterfaceAddrs() often fails due to SELinux restrictions (netlink_route_socket)
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		log.Printf("⚠️  net.InterfaceAddrs() failed: %v", err)
	} else {
		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
				if ipnet.IP.To4() != nil {
					ips = append(ips, ipnet.IP)
				}
			}
		}
	}

	// Fallback: Use UDP Dial to find default outbound IP (doesn't require netlink)
	if len(ips) == 0 {
		conn, err := net.Dial("udp", "8.8.8.8:80")
		if err == nil {
			localAddr := conn.LocalAddr().(*net.UDPAddr)
			ips = append(ips, localAddr.IP)
			conn.Close()
			log.Printf("🌐 Found local IP via UDP dial: %v", localAddr.IP)
		}
	}

	// Last fallback to localhost
	if len(ips) == 0 {
		ips = append(ips, net.ParseIP("127.0.0.1"))
	}

	return ips, nil
}
