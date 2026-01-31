package main

import (
	"fmt"
	"log"
	"net"
	"sync"
	"time"

	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"hydra_share/daemon/internal/auth"
	"hydra_share/daemon/internal/bridge"
	"hydra_share/daemon/internal/connectivity"
	"hydra_share/daemon/internal/discovery"
	"hydra_share/daemon/internal/mesh"
	"hydra_share/daemon/internal/storage"
	"hydra_share/daemon/internal/transfer"
)

// Command represents the JSON structure for incoming commands
type Command struct {
	Type       string `json:"type"`
	FilePath   string `json:"file_path,omitempty"`
	DestIP     string `json:"dest_ip,omitempty"`
	TransferID string `json:"transfer_id,omitempty"`
	OfferID    string `json:"offer_id,omitempty"`
	Text       string `json:"text,omitempty"`
	Name       string `json:"name,omitempty"`
	Key        string `json:"key,omitempty"`
	SourceID   string `json:"src_id,omitempty"`
	DestID     string `json:"dest_id,omitempty"`
	HopCount   int    `json:"hop_count,omitempty"`
}

// Response represents the JSON structure for outgoing responses
type Response struct {
	Type    string `json:"type"`
	Status  string `json:"status,omitempty"`
	Key     string `json:"key,omitempty"`
	Pin     string `json:"pin,omitempty"`
	IP      string `json:"ip,omitempty"`
	Name    string `json:"name,omitempty"`
	OfferID string `json:"offer_id,omitempty"`
}

type PeerDiscoveredEvent struct {
	Type   string `json:"type"`
	IP     string `json:"ip"`
	Name   string `json:"name"`
	Port   int    `json:"port"`
	MeshID string `json:"mesh_id,omitempty"`
}

type ConnectionInfo struct {
	IP   string
	Key  string
	Port int
}

var (
	authService      *auth.Service
	bridgeService    *bridge.Service
	discoveryService *discovery.Service
	connManager      *connectivity.Manager
	meshOrchestrator *mesh.Orchestrator
	db               *storage.Database

	localName    = "HydraShare Device"
	localID      string
	transferPort int

	peerRegistry *mesh.PeerRegistry
	relayEnabled = true
	adminStateMu sync.RWMutex
	maxFileSize  int64 = 0
)

func init() {
	authService = auth.NewService()
	bridgeService = bridge.NewService()
}

func StartDaemon() {
	// 0. Start TCP Listener IMMEDIATELY to avoid race conditions
	listener, err := net.Listen("tcp", "0.0.0.0:5050")
	if err != nil {
		log.Fatalf("❌ Failed to start Flutter bridge server: %v", err)
	}
	// We don't defer listener.Close() here because we want it to run indefinitely
	// or we can handle graceful shutdown later. For now, let it run.

	MyLog("🚀 Flutter bridge listener started on 0.0.0.0:5050")

	// Start accepting connections in background
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				continue
			}
			// Bridge service is initialized in init(), so it's safe to use
			bridgeService.SetConnection(conn)
			go handleConnection(conn)
		}
	}()

	connManager = connectivity.NewManager(bridgeService)

	ips, _ := connectivity.GetLocalIPs()
	hostIP := "127.0.0.1"
	if len(ips) > 0 {
		hostIP = ips[0].String()
	}

	// 1. Initialize Storage and Load/Generate Identity
	var errStorage error
	db, errStorage = storage.NewDatabase()
	if errStorage != nil {
		MyLog("⚠️  Failed to initialize database: %v", errStorage)
	}

	persistentID, err := db.GetConfig("hydra_id")
	if err != nil || persistentID == "" {
		// Generate new Permanent Identity (Ed25519)
		pub, priv, _ := ed25519.GenerateKey(nil)
		persistentID = base64.StdEncoding.EncodeToString(pub)
		privStr := base64.StdEncoding.EncodeToString(priv)

		db.SaveConfig("hydra_id", persistentID)
		db.SaveConfig("hydra_priv_key", privStr)
		MyLog("🆔 Generated new permanent HydraID: %s", persistentID)
	} else {
		MyLog("🆔 Loaded persistent HydraID: %s", persistentID)
	}
	localID = persistentID

	go func() {
		time.Sleep(2 * time.Second)
		connManager.CheckConnectivity()
	}()

	// Load or Generate MeshID
	meshID, err := db.GetConfig("mesh_id")
	if err != nil || meshID == "" {
		// For now, just generate a random UUID-like string
		// In a real implementation, we might want a more robust ID generation
		// Using a simple random hex string for simplicity
		b := make([]byte, 16)
		_, _ = rand.Read(b)
		meshID = fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
		db.SaveConfig("mesh_id", meshID)
		MyLog("🌐 Generated new MeshID: %s", meshID)
	} else {
		MyLog("🌐 Loaded MeshID: %s", meshID)
	}

	discoveryService, _ = discovery.NewService(localName, 5051, meshID)
	discoveryService.StartAdvertising()

	peerRegistry = mesh.NewPeerRegistry(bridgeService, localID)
	meshOrchestrator = mesh.NewOrchestrator(hostIP, peerRegistry, bridgeService)

	queueMgr := transfer.NewQueueManager(db)
	queueMgr.ProcessQueue(func(ip string) bool {
		return peerRegistry.IsPeerOnline(ip)
	}, func(tid string) {
		transfer.Resume(tid, db, bridgeService)
	})

	go startSecureListener()

	transfer.SetMessenger(meshOrchestrator)
	transfer.SetDB(db)
	transfer.StartAdaptiveThrottler()
	transfer.StartScrubber(transfer.GetReceiveDir())
	transfer.SetTelemetryCallback(TrackTransferResult) // Enable Telemetry
	connManager.MonitorSignalStrength()

	transferPort, _ = transfer.StartReceiver(bridgeService)
	MyLog("📥 File receiver started on port %d", transferPort)
	discoveryService.UpdatePort(transferPort)

	// Main thread can block or exit depending on how it's called.
	// For Android (init via FFI), this runs in a goroutine, so we should block here or just return?
	// The original code fell through to the listener loop which blocked.
	// Since we moved the listener loop to a goroutine, we need to block this function
	// to prevent the caller (if it expects blocking) from exiting,
	// although in Android it's called as `go StartDaemon()`, so the goroutine would just finish.
	// But `StartDaemon` was previously blocking. Let's keep it blocking.
	select {}
}
