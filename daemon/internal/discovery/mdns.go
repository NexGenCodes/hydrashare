package discovery

import (
	"context"
	"fmt"
	"hydra_share/daemon/internal/connectivity"
	"log"
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
	ips, err := connectivity.GetLocalIPs()
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

// UpdateName updates the advertised hostname and restarts advertising if active
func (s *Service) UpdateName(newName string) {
	s.hostname = newName
	if s.server != nil {
		s.StopAdvertising()
		s.StartAdvertising()
	}
}
