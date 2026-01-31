package main

import (
	"encoding/json"
	"net"

	"hydra_share/daemon/internal/connectivity"
	"hydra_share/daemon/internal/mesh"
	"hydra_share/daemon/internal/transfer"
)

func startSecureListener() {
	ln, err := net.Listen("tcp", ":5052")
	if err != nil {
		MyLog("❌ Failed to start secure listener on :5052: %v", err)
		return
	}
	defer ln.Close()

	for {
		conn, err := ln.Accept()
		if err != nil {
			continue
		}

		remoteAddr := conn.RemoteAddr().(*net.TCPAddr).IP.String()

		if peerRegistry.IsBlocked(remoteAddr) {
			conn.Close()
			continue
		}

		var handshakeMsg map[string]interface{}
		var sessionKeyToSend string
		decoder := json.NewDecoder(conn)
		if err := decoder.Decode(&handshakeMsg); err == nil {
			if pinProof, ok := handshakeMsg["pin_proof"].(string); ok {
				_, sKey, valid := authService.VerifyPinProof(remoteAddr, pinProof)
				if valid {
					sessionKeyToSend = sKey
					newPin, newSKey, newHash, newSalt := authService.GenerateCredentials()
					transfer.SetTransferKey(newSKey)
					ips, _ := connectivity.GetLocalIPs()
					hostIP := "127.0.0.1"
					if len(ips) > 0 {
						hostIP = ips[0].String()
					}
					if discoveryService != nil {
						discoveryService.UpdatePIN(newHash, newSalt)
					}
					bridgeService.Emit(Response{
						Type: "CODE_GENERATED",
						Key:  newSKey,
						Pin:  newPin,
						IP:   hostIP,
						Name: localName,
					})
				} else {
					conn.Close()
					continue
				}
			}
		}

		response := map[string]interface{}{
			"type":          "HANDSHAKE_RESPONSE",
			"name":          localName,
			"transfer_port": transferPort,
		}
		if sessionKeyToSend != "" {
			response["key"] = sessionKeyToSend
		}
		json.NewEncoder(conn).Encode(response)

		name := "Guest Device"
		if n, ok := handshakeMsg["name"].(string); ok {
			name = n
		}

		peerState := &mesh.PeerState{
			ID:           remoteAddr,
			Name:         name,
			Conn:         conn,
			LocalIPs:     []string{remoteAddr},
			Transports:   []string{"router"},
			TransferPort: transferPort,
		}
		if pPort, ok := handshakeMsg["transfer_port"].(float64); ok {
			peerState.TransferPort = int(pPort)
		}

		peerRegistry.RegisterPeer(peerState)
		meshOrchestrator.IntroducePeers(peerState)
		go handlePeerConn(conn, remoteAddr)
	}
}
