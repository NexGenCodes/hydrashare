package bridge

import (
	"encoding/json"
	"io"
	"log"
	"net"
	"sync"
)

// Service manages communication with the local Flutter client
type Service struct {
	mu      sync.RWMutex
	encoder *json.Encoder
	conn    net.Conn
	events  chan interface{}
}

// NewService creates a new Bridge Service
func NewService() *Service {
	s := &Service{
		events: make(chan interface{}, 100),
	}
	go s.run()
	return s
}

// Emit sends an event to the connected Flutter client
func (s *Service) Emit(event interface{}) {
	s.mu.RLock()
	hasEncoder := s.encoder != nil
	s.mu.RUnlock()

	if hasEncoder {
		s.events <- event
	}
}

// SetConnection sets the current active connection from the Flutter client
func (s *Service) SetConnection(conn net.Conn) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.conn != nil {
		s.conn.Close()
	}

	s.conn = conn
	s.encoder = json.NewEncoder(conn)
	log.Println("🔌 Flutter client connected to Bridge")
}

// run processes the event queue and sends them via the encoder
func (s *Service) run() {
	for event := range s.events {
		s.mu.RLock()
		enc := s.encoder
		s.mu.RUnlock()

		if enc != nil {
			if err := enc.Encode(event); err != nil {
				if err == io.EOF {
					log.Println("🔌 Flutter client disconnected")
				} else {
					log.Printf("⚠️  Failed to send event to Flutter: %v", err)
				}
				s.mu.Lock()
				s.encoder = nil
				s.conn = nil
				s.mu.Unlock()
			}
		}
	}
}
