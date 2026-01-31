package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"path/filepath"
	"strings"
	"time"

	"hydra_share/daemon/internal/connectivity"
	"hydra_share/daemon/internal/discovery"
	"hydra_share/daemon/internal/mesh"
	"hydra_share/daemon/internal/transfer"
)

func handleConnection(conn net.Conn) {
	defer conn.Close()
	decoder := json.NewDecoder(conn)
	encoder := json.NewEncoder(conn)

	for {
		var cmd Command
		if err := decoder.Decode(&cmd); err != nil {
			if err == io.EOF || strings.Contains(err.Error(), "wsarecv") || strings.Contains(err.Error(), "connection reset") {
				// Silent disconnect
			} else {
				MyLog("Connection error: %v", err)
			}
			break
		}

		MyLog("📥 Received: %s", cmd.Type)

		// --- Multi-hop Relay Logic ---
		if cmd.DestID != "" && cmd.DestID != localID {
			if !relayEnabled {
				MyLog("🔋 Relay disabled (Low Power Mode). Dropping message.")
				continue
			}
			if cmd.HopCount >= 5 {
				MyLog("⚠️  Dropping message, max hops exceeded: %s", cmd.Type)
				continue
			}
			cmd.HopCount++
			relayMessage(cmd)
			continue
		}

		// Handle commands
		switch cmd.Type {
		case "MARK_AS_READ":
			if db != nil {
				db.MarkAsRead(cmd.DestIP)
			}
		case "ping":
			response := Response{
				Type:   "pong",
				Status: "ready",
			}
			encoder.Encode(response)

		case "SET_DEVICE_NAME":
			MyLog("📝 Setting local device name: %s", cmd.Name)
			localName = cmd.Name
			if discoveryService != nil {
				discoveryService.UpdateName(localName)
			}

		case "TOGGLE_RELAY":
			relayEnabled = (cmd.Text == "true")
			MyLog("🔋 Relay Enabled: %v", relayEnabled)

		case "SEND_FILE":
			handleSendFile(cmd, encoder)

		case "ACCEPT_FILE":
			handleAcceptFile(cmd)

		case "REJECT_FILE":
			handleRejectFile(cmd)

		case "START_TRANSFER":
			handleStartTransfer(cmd, encoder)

		case "CANCEL_TRANSFER":
			MyLog("🛑 Cancelling transfer: %s", cmd.TransferID)
			transfer.CancelTransfer(cmd.TransferID)

		case "START_DISCOVERY":
			handleStartDiscovery(encoder)

		case "STOP_DISCOVERY":
			handleStopDiscovery(encoder)

		case "GENERATE_CODE":
			handleGenerateCode(encoder)

		case "CONNECT_WITH_PIN":
			handleConnectWithPin(cmd, encoder)

		case "CONNECT_PEER":
			handleConnectPeer(cmd, encoder)

		case "SEND_CHAT":
			handleSendChat(cmd)

		case "BROADCAST_CHAT":
			handleBroadcastChat(cmd)

		case "BROADCAST_FILE":
			handleBroadcastFile(cmd)

		case "SHARE_FILE":
			handleShareFile(cmd)

		case "REQUEST_FILE":
			handleRequestFile(cmd)

		case "DISCONNECT_PEER":
			MyLog("🚫 Disconnecting peer: %s", cmd.DestIP)
			peerRegistry.UnregisterPeer(cmd.DestIP)

		case "BAN_PEER":
			MyLog("⛔ Banning peer: %s", cmd.DestIP)
			peerRegistry.BlockIP(cmd.DestIP)
			peerRegistry.UnregisterPeer(cmd.DestIP)

		case "MUTE_PEER":
			isMuted := cmd.Text == "true"
			MyLog("🔇 Muting peer %s: %v", cmd.DestIP, isMuted)
			peerRegistry.SetMuted(cmd.DestIP, isMuted)

		case "SET_SETTINGS":
			if cmd.Key == "max_file_size" {
				var size int64
				fmt.Sscanf(cmd.Text, "%d", &size)
				maxFileSize = size
				transfer.SetMaxFileSize(size)
				MyLog("⚙️ Max File Size set to: %d bytes", maxFileSize)
			} else if cmd.Key == "throttle" {
				var ms int
				fmt.Sscanf(cmd.Text, "%d", &ms)
				transfer.SetThrottle(ms)
				MyLog("⚖️ Manual Throttling speed set to: %d ms delay", ms)
			}

		case "SET_METERED":
			isMetered := (cmd.Text == "true")
			connectivity.SetMetered(isMetered)
			MyLog("📶 Metered Connection set to: %v", isMetered)

		default:
			MyLog("⚠️  Unknown command: %s", cmd.Type)
		}
	}
	MyLog("🔌 Client disconnected")
}

// Sub-handlers for cleaner code

func handleSendFile(cmd Command, encoder *json.Encoder) {
	MyLog("🚀 Sending file offer: %s -> %s", cmd.FilePath, cmd.DestIP)
	fileInfo, err := transfer.GetFileInfo(cmd.FilePath)
	if err != nil {
		encoder.Encode(map[string]string{"type": "ERROR", "error": err.Error()})
		return
	}

	if maxFileSize > 0 && fileInfo.Size() > maxFileSize {
		encoder.Encode(map[string]string{"type": "ERROR", "error": fmt.Sprintf("File too large (%d > %d)", fileInfo.Size(), maxFileSize)})
		return
	}

	offerID := fmt.Sprintf("%d", time.Now().UnixNano())
	peerRegistry.AddOffer(offerID, cmd.FilePath)

	peer := peerRegistry.GetPeer(cmd.DestIP)
	if peer != nil {
		msg := map[string]interface{}{
			"type":      "FILE_OFFER",
			"offer_id":  offerID,
			"file_name": fileInfo.Name(),
			"file_size": fileInfo.Size(),
			"ip":        "Home",
		}
		json.NewEncoder(peer.Conn).Encode(msg)
	} else {
		encoder.Encode(map[string]string{"type": "ERROR", "error": "Peer not connected"})
	}
}

func handleAcceptFile(cmd Command) {
	peer := peerRegistry.GetPeer(cmd.DestIP)
	if peer != nil {
		json.NewEncoder(peer.Conn).Encode(map[string]interface{}{
			"type":     "ACCEPT_FILE",
			"offer_id": cmd.OfferID,
		})
	}
}

func handleRejectFile(cmd Command) {
	peer := peerRegistry.GetPeer(cmd.DestIP)
	if peer != nil {
		json.NewEncoder(peer.Conn).Encode(map[string]interface{}{
			"type":     "REJECT_FILE",
			"offer_id": cmd.OfferID,
		})
	}
}

func handleStartTransfer(cmd Command, encoder *json.Encoder) {
	peer := peerRegistry.GetPeer(cmd.DestIP)
	if peer != nil {
		destPort := peer.TransferPort
		if destPort == 0 {
			destPort = 5051
		}
		if err := transfer.StartTransfer(cmd.FilePath, cmd.DestIP, destPort, bridgeService, peer.Conn, 0); err != nil {
			encoder.Encode(map[string]string{"type": "ERROR", "error": err.Error()})
		}
	}
}

func handleStartDiscovery(encoder *json.Encoder) {
	MyLog("🔍 Starting peer discovery...")
	peersChan := discoveryService.StartDiscovery()
	go func() {
		for peer := range peersChan {
			encoder.Encode(PeerDiscoveredEvent{
				Type: "PEER_DISCOVERED",
				IP:   peer.IP,
				Name: peer.Name,
				Port: peer.Port,
			})
		}
	}()
	encoder.Encode(Response{Type: "DISCOVERY_STARTED", Status: "scanning"})
}

func handleStopDiscovery(encoder *json.Encoder) {
	MyLog("🛑 Stopping peer discovery...")
	discoveryService.StopDiscovery()
	discoveryService, _ = discovery.NewService(localName, transferPort)
	discoveryService.StartAdvertising()
	encoder.Encode(Response{Type: "DISCOVERY_STOPPED", Status: "idle"})
}

func handleGenerateCode(encoder *json.Encoder) {
	pin, sessionKey, pinHash, salt := authService.GenerateCredentials()
	transfer.SetTransferKey(sessionKey)

	ips, _ := connectivity.GetLocalIPs()
	hostIP := "127.0.0.1"
	if len(ips) > 0 {
		hostIP = ips[0].String()
	}

	if discoveryService != nil {
		discoveryService.UpdatePIN(pinHash, salt)
	}

	encoder.Encode(Response{
		Type: "CODE_GENERATED",
		Key:  sessionKey,
		Pin:  pin,
		IP:   hostIP,
		Name: localName,
	})
	MyLog("📤 Sent: CODE_GENERATED (IP: %s, Name: %s, key length: %d)", hostIP, localName, len(sessionKey))
}

func handleConnectWithPin(cmd Command, encoder *json.Encoder) {
	pin := cmd.Key
	var connInfo ConnectionInfo

	if discoveryService == nil {
		encoder.Encode(map[string]string{"type": "ERROR", "error": "Discovery service unavailable"})
		return
	}

	peersChan := discoveryService.StartDiscovery()
	found := false
	timeout := time.After(8 * time.Second)

ScanLoop:
	for {
		select {
		case p := <-peersChan:
			if p.PINHash == authService.HashPIN(pin, p.Salt) {
				connInfo = ConnectionInfo{IP: p.IP, Key: p.PINHash, Port: p.Port}
				found = true
				discoveryService.StopDiscovery()
				break ScanLoop
			}
		case <-timeout:
			discoveryService.StopDiscovery()
			break ScanLoop
		}
	}

	if !found {
		encoder.Encode(map[string]string{"type": "ERROR", "error": "Invalid PIN code or Peer not found"})
		return
	}

	transfer.SetTransferKey(connInfo.Key)
	peerConn, err := net.DialTimeout("tcp", net.JoinHostPort(connInfo.IP, "5052"), 5*time.Second)
	if err != nil {
		encoder.Encode(map[string]string{"type": "ERROR", "error": "Connection failed: " + err.Error()})
		return
	}

	json.NewEncoder(peerConn).Encode(map[string]interface{}{
		"name":          localName,
		"transfer_port": transferPort,
		"pin_proof":     connInfo.Key,
	})

	var hostHandshake map[string]interface{}
	if err := json.NewDecoder(peerConn).Decode(&hostHandshake); err == nil {
		hName, _ := hostHandshake["name"].(string)
		hPort, _ := hostHandshake["transfer_port"].(float64)
		hKey, _ := hostHandshake["key"].(string)
		if hKey != "" {
			transfer.SetTransferKey(hKey)
		}
		peerRegistry.RegisterPeer(&mesh.PeerState{
			ID:           connInfo.IP,
			Name:         hName,
			Conn:         peerConn,
			LocalIPs:     []string{connInfo.IP},
			Transports:   []string{"router"},
			TransferPort: int(hPort),
		})
	}

	go handlePeerConn(peerConn, connInfo.IP)
	encoder.Encode(map[string]interface{}{
		"type":   "PEER_CONNECTED",
		"status": "connected",
		"ip":     connInfo.IP,
		"name":   peerRegistry.GetPeer(connInfo.IP).Name,
	})
}

func handleConnectPeer(cmd Command, encoder *json.Encoder) {
	if cmd.Key != "" {
		transfer.SetTransferKey(cmd.Key)
	}
	peerConn, err := net.DialTimeout("tcp", net.JoinHostPort(cmd.DestIP, "5052"), 5*time.Second)
	if err != nil {
		encoder.Encode(map[string]string{"type": "ERROR", "error": "Handshake failed: " + err.Error()})
		return
	}

	json.NewEncoder(peerConn).Encode(map[string]interface{}{
		"name":          localName,
		"transfer_port": transferPort,
	})

	var hostHandshake map[string]interface{}
	if err := json.NewDecoder(peerConn).Decode(&hostHandshake); err == nil {
		hName, _ := hostHandshake["name"].(string)
		hPort, _ := hostHandshake["transfer_port"].(float64)
		peerRegistry.RegisterPeer(&mesh.PeerState{
			ID:           cmd.DestIP,
			Name:         hName,
			Conn:         peerConn,
			LocalIPs:     []string{cmd.DestIP},
			Transports:   []string{"router"},
			TransferPort: int(hPort),
		})
	}

	go handlePeerConn(peerConn, cmd.DestIP)
	encoder.Encode(map[string]interface{}{
		"type":   "PEER_CONNECTED",
		"status": "connected",
		"ip":     cmd.DestIP,
		"name":   peerRegistry.GetPeer(cmd.DestIP).Name,
	})
}

func handleSendChat(cmd Command) {
	if db != nil {
		db.SaveMessage(cmd.DestIP, "Me", cmd.Text, false)
	}
	peer := peerRegistry.GetPeer(cmd.DestIP)
	if peer != nil {
		json.NewEncoder(peer.Conn).Encode(map[string]interface{}{
			"type": "INCOMING_CHAT",
			"text": cmd.Text,
			"ip":   "Home",
		})
	}
}

func handleBroadcastChat(cmd Command) {
	if db != nil {
		db.SaveMessage("broadcast", "Me", cmd.Text, true)
	}
	for _, peer := range peerRegistry.GetAllPeers() {
		json.NewEncoder(peer.Conn).Encode(map[string]interface{}{
			"type": "INCOMING_CHAT",
			"text": cmd.Text,
			"ip":   "Broadcast",
		})
	}
}

func handleBroadcastFile(cmd Command) {
	for _, peer := range peerRegistry.GetAllPeers() {
		destPort := peer.TransferPort
		if destPort == 0 {
			destPort = 5051
		}
		transfer.StartTransfer(cmd.FilePath, peer.ID, destPort, bridgeService, peer.Conn, 0)
	}
}

func handleShareFile(cmd Command) {
	fileName := filepath.Base(cmd.FilePath)
	peerRegistry.AddMeshFile(fileName, cmd.DestIP)
	bridgeService.Emit(map[string]interface{}{
		"type":      "FILE_AVAILABLE",
		"file_name": fileName,
		"peer_ip":   cmd.DestIP,
	})
}

func handleRequestFile(cmd Command) {
	fileName := filepath.Base(cmd.FilePath)
	peers := peerRegistry.GetMeshProviders(fileName)
	if len(peers) > 0 {
		providerIP := peers[0]
		requesterIP := cmd.DestIP
		go func() {
			peerConn, err := net.DialTimeout("tcp", net.JoinHostPort(providerIP, "5052"), 5*time.Second)
			if err != nil {
				return
			}
			defer peerConn.Close()
			json.NewEncoder(peerConn).Encode(map[string]interface{}{
				"type":      "PROVIDE_FILE",
				"file_path": "/shared/" + fileName,
				"dest_ip":   requesterIP,
			})
		}()
	}
}
