package main

import (
	"encoding/json"
	"fmt"
	"net"
	"time"

	"hydra_share/daemon/internal/mesh"
	"hydra_share/daemon/internal/transfer"
)

func handlePeerConn(conn net.Conn, ip string) {
	defer peerRegistry.UnregisterPeer(ip)

	decoder := json.NewDecoder(conn)
	for {
		var msg map[string]interface{}
		if err := decoder.Decode(&msg); err != nil {
			MyLog("🔌 Peer %s disconnected: %v", ip, err)
			return
		}

		msgType, _ := msg["type"].(string)

		if peerRegistry.IsMuted(ip) {
			if msgType == "INCOMING_CHAT" || msgType == "FILE_OFFER" {
				MyLog("🔇 Ignored message from muted peer %s: %s", ip, msgType)
				continue
			}
		}

		switch msgType {
		case "PEER_DISCOVERY_CARD":
			targetIPs, _ := msg["ips"].([]interface{})
			targetName, _ := msg["name"].(string)
			MyLog("🗂️ Received Discovery Card for %s. Attempting G2G Direct Dial...", targetName)
			for _, tip := range targetIPs {
				go attemptDirectG2G(tip.(string), targetName)
			}

		case "PEER_CONNECTED", "PEER_DISCONNECTED", "FILE_OFFER":
			handleRemoteCommand(conn, ip, msg)

		case "G2G_HANDSHAKE":
			targetName, _ := msg["name"].(string)
			MyLog("🤝 Direct G2G Handshake completed with %s", targetName)
			peerRegistry.UpdatePeerName(ip, targetName)
			if pPort, ok := msg["transfer_port"].(float64); ok {
				if peer := peerRegistry.GetPeer(ip); peer != nil {
					peer.TransferPort = int(pPort)
				}
			}

		case "INCOMING_CHAT":
			text, _ := msg["text"].(string)
			if db != nil {
				db.SaveMessage(ip, "Peer", text, false)
			}
			bridgeService.Emit(map[string]interface{}{
				"type":   "INCOMING_CHAT",
				"text":   text,
				"ip":     ip,
				"unread": true,
			})

		case "PROVIDE_FILE":
			filePath, _ := msg["file_path"].(string)
			destIP, _ := msg["dest_ip"].(string)
			destPort := 5051
			if peer := peerRegistry.GetPeer(destIP); peer != nil {
				destPort = peer.TransferPort
			}
			transfer.StartTransfer(filePath, destIP, destPort, bridgeService, conn, 0)

		case "G2G_TRANSFER_REQ":
			targetPeerID, _ := msg["target_peer_id"].(string)
			fileName, _ := msg["file_name"].(string)
			transferID, _ := msg["transfer_id"].(string)
			meshOrchestrator.CoordinateG2GTransfer(ip, targetPeerID, fileName, transferID, 0)

		case "G2G_TRANSFER_INTRO":
			// Handled in mesh orchestrator or specialized logic if complex
			MyLog("🤝 Host introduced us for G2G transfer")

		case "ACCEPT_FILE":
			handlePeerAcceptFile(ip, msg, conn)

		case "REJECT_FILE":
			offerID, _ := msg["offer_id"].(string)
			bridgeService.Emit(map[string]interface{}{
				"type":     "TRANSFER_REJECTED",
				"offer_id": offerID,
				"peer_ip":  ip,
			})
			peerRegistry.RemoveOffer(offerID)

		case "VERIFY_HASH":
			fileName, _ := msg["file_name"].(string)
			hash, _ := msg["hash"].(string)
			transfer.VerifyReceivedFile(fileName, hash, bridgeService)

		case "ROTATE_KEY_SIGNAL":
			atBytes, _ := msg["at_bytes"].(float64)
			MyLog("🔄 Received P2P Key Rotation Signal at %d bytes", int64(atBytes))
		}
	}
}

func handlePeerAcceptFile(ip string, msg map[string]interface{}, conn net.Conn) {
	offerID, _ := msg["offer_id"].(string)
	filePath, ok := peerRegistry.GetOfferPath(offerID)
	if ok {
		tokenID := fmt.Sprintf("%s_%s", filePath, ip)
		_, startOffset, _, err := db.GetResumptionToken(tokenID)
		if err != nil {
			startOffset = 0
		}
		destPort := 5051
		if peer := peerRegistry.GetPeer(ip); peer != nil {
			destPort = peer.TransferPort
		}
		transfer.StartTransfer(filePath, ip, destPort, bridgeService, conn, startOffset)
		peerRegistry.RemoveOffer(offerID)
	}
}

func attemptDirectG2G(destIP, name string) {
	conn, err := net.DialTimeout("tcp", net.JoinHostPort(destIP, "5052"), 3*time.Second)
	if err != nil {
		return
	}
	json.NewEncoder(conn).Encode(map[string]interface{}{
		"type":          "G2G_HANDSHAKE",
		"name":          localName,
		"transfer_port": transferPort,
	})
	peerRegistry.RegisterPeer(&mesh.PeerState{
		ID:           destIP,
		Name:         name,
		Conn:         conn,
		LocalIPs:     []string{destIP},
		Transports:   []string{"g2g"},
		TransferPort: 5051,
	})
	go handlePeerConn(conn, destIP)
}

func handleRemoteCommand(conn net.Conn, remoteAddr string, msg map[string]interface{}) {
	msgType, _ := msg["type"].(string)
	switch msgType {
	case "FILE_OFFER":
		fileName, _ := msg["file_name"].(string)
		fileSize, _ := msg["file_size"].(float64)
		offerID, _ := msg["offer_id"].(string)
		bridgeService.Emit(map[string]interface{}{
			"type":      "FILE_OFFER_RECEIVED",
			"file_name": fileName,
			"file_size": int64(fileSize),
			"offer_id":  offerID,
			"ip":        remoteAddr,
		})
	case "PEER_CONNECTED", "PEER_DISCONNECTED":
		bridgeService.Emit(msg)
	}
}
