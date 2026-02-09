use std::sync::{Arc, RwLock};
use std::sync::atomic::{AtomicU16, Ordering};
use std::collections::HashMap;
use std::time::{SystemTime, Duration};
use futures::future::{BoxFuture, FutureExt};
use crate::discovery::{DiscoveryService};
use crate::mesh::{MeshNetwork, PeerStatus};
use crate::transfer::delta::FileMap;
use crate::ffi::{emit_event, DaemonEvent};
use tracing::{info, warn, debug, error};
use serde::{Serialize, Deserialize};
use quinn::Endpoint;
use crate::quic::cert;
use crate::common::networks::{classify_network};
use crate::transport::bluetooth::{BluetoothStream, BluetoothListener};
use std::io::{self, Read, Write};
use anyhow::Result;
use base64::{Engine as _, engine::general_purpose::STANDARD};

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MeshMessage {
    Handshake {
        name: String,
        peer_id: String,
    },
    DiscoveryCard {
        peer_id: String,
        name: String,
        ips: Vec<String>,
        port: u16,
    },
    Heartbeat {
        health: Option<crate::system::SystemHealth>,
    },
    Chat {
        text: String,
        target_peer_id: Option<String>,
    },
    G2gTransferReq {
        target_peer_id: String,
        file_name: String,
        file_size: u64,
        transfer_id: String,
        thumbnail: Option<String>,
    },
    G2gTransferAccept {
        transfer_id: String,
        delta_map: Option<FileMap>,
    },
    G2gTransferCancel {
        transfer_id: String,
    },
    G2gTransferReject {
        transfer_id: String,
    },
}

#[derive(Clone)]
pub struct Orchestrator {
    mesh: Arc<MeshNetwork>,
    _discovery: Arc<DiscoveryService>,
    db: Arc<crate::db::Database>,
    local_peer_id: String,
    last_heartbeats: Arc<RwLock<HashMap<String, SystemTime>>>,
    bound_port: Arc<AtomicU16>,
    connections: Arc<RwLock<HashMap<String, Vec<quinn::Connection>>>>,
    pub pending_transfers: Arc<RwLock<HashMap<String, String>>>,
}

impl Orchestrator {
    pub fn new(local_peer_id: &str, mesh: Arc<MeshNetwork>, discovery: Arc<DiscoveryService>, db: Arc<crate::db::Database>) -> Self {
        Self {
            mesh,
            _discovery: discovery,
            db,
            local_peer_id: local_peer_id.to_string(),
            last_heartbeats: Arc::new(RwLock::new(HashMap::new())),
            bound_port: Arc::new(AtomicU16::new(0)),
            connections: Arc::new(RwLock::new(HashMap::new())),
            pending_transfers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn get_port(&self) -> u16 {
        self.bound_port.load(Ordering::Relaxed)
    }

    pub fn get_connection_count(&self, peer_id: &str) -> usize {
        self.connections.read().map(|conns| conns.get(peer_id).map(|v| v.len()).unwrap_or(0)).unwrap_or(0)
    }

    pub fn has_connection(&self, peer_id: &str) -> bool {
        self.connections.read().map(|conns| conns.contains_key(peer_id)).unwrap_or(false)
    }

    pub async fn restore_peers_from_db(&self) {
        let db = self.db.clone();
        info!("🔄 Restoring peers from database...");
        
        let peers = match db.get_all_peers() {
            Ok(p) => p,
            Err(e) => {
                warn!("⚠️ Failed to load peers from DB: {}", e);
                return;
            }
        };
        
        info!("📦 Found {} saved peers", peers.len());
        
        for peer_info in peers {
            // Skip peers with no IPs
            if peer_info.ips.is_empty() {
                continue;
            }
            
            info!("🔌 Restoring peer: {} ({})", peer_info.name, peer_info.peer_id);
            
            // Add to mesh as Offline initially
            self.mesh.update_peer_discovery(peer_info.clone());
            
            // Attempt reconnection
            let addrs: Vec<std::net::SocketAddr> = peer_info.ips.iter()
                .map(|ip| std::net::SocketAddr::new(*ip, peer_info.port))
                .collect();
            
            self.connect_to_peer_multi(peer_info.peer_id.clone(), addrs);
        }
    }

    pub async fn start(&self) -> Result<u16> {
        self.start_monitoring();
        if cfg!(windows) {
            self.start_bluetooth_server();
        }
        
        let orchestrator = Arc::new(self.clone());
        crate::system::runtime::RUNTIME.spawn(async move {
            orchestrator.run_persistent_listener().await;
        });

        // Small wait to ensure first bind attempt happens before returning port
        tokio::time::sleep(Duration::from_millis(100)).await;
        Ok(self.get_port())
    }

    fn start_monitoring(&self) {
        let heartbeats = self.last_heartbeats.clone();
        let mesh = self.mesh.clone();
        let orchestrator = Arc::new(self.clone());
        
        crate::system::runtime::RUNTIME.spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(10));
            loop {
                interval.tick().await;
                let now = SystemTime::now();
                let mut peers_to_remove = Vec::new();
                
                {
                    let hbs = match heartbeats.read() {
                        Ok(guard) => guard,
                        Err(_) => break,
                    };
                    for (id, last_seen) in hbs.iter() {
                        if now.duration_since(*last_seen).unwrap_or(Duration::from_secs(0)) > Duration::from_secs(30) {
                            peers_to_remove.push(id.clone());
                        }
                    }
                }

                for id in peers_to_remove {
                    info!("🔌 Peer {} timed out", id);
                    if let Ok(mut guard) = heartbeats.write() {
                        guard.remove(&id);
                    }
                    if let Ok(mut peers) = mesh.peers.write() {
                        if let Some(peer) = peers.get_mut(&id) {
                            peer.status = PeerStatus::Offline;
                            emit_event(DaemonEvent::PeerLost { peer_id: id.clone() });
                        }
                    }
                }

                // Smart Heartbeat: Broadcast our health to all active connections
                let health = if let Ok(guard) = crate::system::INTELLIGENCE.read() {
                    guard.get_health()
                } else {
                    crate::system::SystemHealth::Optimal
                };
                let msg = MeshMessage::Heartbeat { health: Some(health) };
                
                let peer_ids: Vec<String> = if let Ok(conns) = orchestrator.connections.read() {
                    conns.keys().cloned().collect()
                } else {
                    Vec::new()
                };
                
                for id in peer_ids {
                    let _ = orchestrator.send_to_peer(&id, msg.clone()).await;
                }
            }
        });
    }

    pub async fn bind_quic_server(&self) -> Result<(Endpoint, u16)> {
        // Try to bind to standard port 5051 first, then 0 (random) if failed
        let addr_fixed = "0.0.0.0:5051".parse().unwrap();
        let server_cfg = cert::make_hydra_server_config(None);
        
        let endpoint = match Endpoint::server(server_cfg.clone(), addr_fixed) {
            Ok(ep) => ep,
            Err(e) => {
                warn!("⚠️ Failed to bind to 5051 ({}), falling back to random port", e);
                let addr_random = "0.0.0.0:0".parse().unwrap();
                Endpoint::server(server_cfg, addr_random)?
            }
        };
        let port = endpoint.local_addr()?.port();
        self.bound_port.store(port, Ordering::Relaxed);
        
        info!("🚀 QUIC Mesh Listener bound to port {}", port);
        Ok((endpoint, port))
    }

    async fn run_persistent_listener(&self) {
        loop {
            match self.bind_quic_server().await {
                Ok((endpoint, port)) => {
                    info!("🚀 persistent listener active on port {}", port);
                    // Update discovery/signaling with new port if it changed
                    // (DiscoveryService polls get_port() so it should be automatic)
                    
                    if let Err(e) = self.listen_loop(endpoint).await {
                        warn!("⚠️ QUIC listener loop error: {}. Re-binding...", e);
                    }
                }
                Err(e) => {
                    error!("❌ Fatal error binding QUIC server: {}. Retrying in 5s...", e);
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    }

    async fn listen_loop(&self, endpoint: Endpoint) -> Result<()> {
        let orchestrator = Arc::new(self.clone());
        while let Some(incoming) = endpoint.accept().await {
            let orchestrator = orchestrator.clone();
            crate::system::runtime::RUNTIME.spawn(async move {
                if let Ok(conn) = incoming.await {
                    info!("🤝 New mesh connection from {}", conn.remote_address());
                    let (mut _send, mut recv) = match conn.accept_bi().await {
                        Ok(pair) => pair,
                        Err(_) => return,
                    };

                    let mut buf = vec![0u8; 65536];
                    let mut remote_peer_id: Option<String> = None;

                    while let Ok(Some(len)) = recv.read(&mut buf).await {
                        if let Ok(msg) = serde_json::from_slice::<MeshMessage>(&buf[..len]) {
                            debug!("📩 Received handshake message type from stream");
                            if let MeshMessage::Handshake { ref peer_id, ref name } = msg {
                                remote_peer_id = Some(peer_id.clone());
                                // Register connection in bonding pool
                                if let Ok(mut conns) = orchestrator.connections.write() {
                                    let entry = conns.entry(peer_id.clone()).or_insert_with(Vec::new);
                                    if !entry.iter().any(|c| c.remote_address() == conn.remote_address()) {
                                        entry.push(conn.clone());
                                        info!("🔗 Bonded connection added for {}: {}", peer_id, conn.remote_address());
                                        
                                        // Emit PeerConnected event
                                        crate::ffi::emit_event(crate::ffi::DaemonEvent::PeerConnected {
                                            peer_id: peer_id.clone(),
                                            name: name.clone(),
                                            address: conn.remote_address().ip().to_string(),
                                            port: conn.remote_address().port(),
                                        });

                                        // Auto-save peer to DB
                                        let peer_info = crate::db::PeerInfo {
                                            peer_id: peer_id.clone(),
                                            name: name.clone(),
                                            ips: vec![conn.remote_address().ip()],
                                            port: conn.remote_address().port(),
                                            bt_addr: None, 
                                            shared_key: orchestrator.mesh.get_peer(peer_id).and_then(|p| p.shared_key),
                                        };
                                        let _ = orchestrator.db.save_peer(&peer_info);
                                    }
                                }
                            }

                            let sender_id = remote_peer_id.clone().unwrap_or_else(|| "unknown".to_string());
                            orchestrator.handle_message(&sender_id, msg);
                        }
                    }
                }
            });
        }
        Ok(())
    }

    fn start_bluetooth_server(&self) {
        let orchestrator = Arc::new(self.clone());
        crate::system::runtime::RUNTIME.spawn_blocking(move || {
            // Port 1 is standard for first RFCOMM channel
            match BluetoothListener::bind(1) {
                Ok(listener) => {
                    info!("🚀 Bluetooth RFCOMM Listener started on channel 1");
                    loop {
                        match listener.accept() {
                            Ok((stream, bt_addr)) => {
                                info!("🤝 New Bluetooth mesh connection from {:X}", bt_addr);
                                let orch = orchestrator.clone();
                                crate::system::runtime::RUNTIME.spawn_blocking(move || {
                                    orch.handle_bluetooth_session(stream);
                                });
                            }
                            Err(e) => warn!("❌ Bluetooth accept failed: {}", e),
                        }
                    }
                }
                Err(e) => warn!("⚠️ Bluetooth RFCOMM failed to start: {}. (Is Bluetooth enabled?)", e),
            }
        });
    }

    fn handle_bluetooth_session(&self, mut stream: BluetoothStream) {
        let mut len_buf = [0u8; 4];
        loop {
            // Read length-prefix (4 bytes)
            if stream.read_exact(&mut len_buf).is_err() { break; }
            let len = u32::from_be_bytes(len_buf) as usize;
            if len > 65536 { break; } // Sanity check

            let mut msg_buf = vec![0u8; len];
            if stream.read_exact(&mut msg_buf).is_err() { break; }

            if let Ok(msg) = serde_json::from_slice::<MeshMessage>(&msg_buf) {
                self.handle_message("bluetooth", msg);
            }
        }
    }

    pub fn connect_to_peer(&self, peer_id: String, addr: std::net::SocketAddr) {
        self.connect_to_peer_multi(peer_id, vec![addr]);
    }

    pub fn connect_to_peer_multi(&self, peer_id: String, addrs: Vec<std::net::SocketAddr>) {
        if addrs.is_empty() { return; }
        
        // Sort addresses by network quality score
        let mut scored_addrs = addrs.into_iter()
            .map(|addr| {
                let score = classify_network(addr.ip()) as u8;
                (score, addr)
            })
            .collect::<Vec<_>>();
        
        scored_addrs.sort_by(|a, b| b.0.cmp(&a.0)); // High score first

        let orchestrator = Arc::new(self.clone());
        let client_cfg = cert::make_client_config(None);
        
        crate::system::runtime::RUNTIME.spawn(async move {
            info!("🛰️ Attempting parallel connection to peer at {:?}", scored_addrs);
            
            // Create the endpoint once
            let mut endpoint = match Endpoint::client("0.0.0.0:0".parse().unwrap()) {
                Ok(ep) => ep,
                Err(e) => {
                    error!("❌ Failed to create client endpoint: {}", e);
                    return;
                }
            };
            endpoint.set_default_client_config(client_cfg);
            
            type ConnectionResult = Result<(std::net::SocketAddr, quinn::Connection), (std::net::SocketAddr, String)>;
            let mut futures: Vec<BoxFuture<ConnectionResult>> = Vec::new();
            for (_, addr) in scored_addrs {
                let conn_fut = endpoint.connect(addr, "localhost");
                futures.push(async move {
                    info!("⏳ Connecting to {}...", addr);
                    match conn_fut {
                        Ok(conn) => {
                            match conn.await {
                                Ok(connection) => Ok((addr, connection)),
                                Err(e) => Err((addr, e.to_string())),
                            }
                        }
                        Err(e) => Err((addr, e.to_string())),
                    }
                }.boxed());
            }

            // Parallel Bonding: Keep all successful connections from distinct local interfaces
            let results = futures::future::join_all(futures).await;
            let mut succeeded = false;
            for (addr, connection) in results.into_iter().flatten() {
                info!("✅ Path established to {} for {}", addr, peer_id);
                orchestrator.start_mesh_session(connection).await;
                succeeded = true;
            }
            
            if !succeeded {
                warn!("❌ All IP attempts failed for {}. Attempting Bluetooth Fallback...", peer_id);
                if let Some(bt_addr) = orchestrator.mesh.get_peer(&peer_id).and_then(|p| p.bt_addr) {
                    orchestrator.connect_via_bluetooth(bt_addr);
                } else {
                    warn!("⚠️ No Bluetooth address known for {}", peer_id);
                }
            }
        });
    }

    pub async fn disconnect_peer(&self, peer_id: &str) {
        info!("✂️ Disconnecting peer: {}", peer_id);
        
        if let Ok(mut conns) = self.connections.write() {
            if let Some(peer_conns) = conns.remove(peer_id) {
                for conn in peer_conns {
                    conn.close(0u32.into(), b"Closed by user");
                }
            }
        }
        
        self.mesh.update_peer_status(peer_id, PeerStatus::Offline);
        emit_event(DaemonEvent::PeerDisconnected { peer_id: peer_id.to_string() });
    }

    fn _send_bluetooth_message(stream: &mut BluetoothStream, msg: &MeshMessage) -> io::Result<()> {
        let buf = serde_json::to_vec(msg).map_err(io::Error::other)?;
        let len = buf.len() as u32;
        stream.write_all(&len.to_be_bytes())?;
        stream.write_all(&buf)?;
        stream.flush()?;
        Ok(())
    }

    pub fn connect_via_bluetooth(&self, bt_addr: u64) {
        let orchestrator = Arc::new(self.clone());
        crate::system::runtime::RUNTIME.spawn_blocking(move || {
            match BluetoothStream::connect(bt_addr, 1) {
                Ok(stream) => {
                    info!("✅ Bluetooth RFCOMM connection established with {:X}", bt_addr);
                    let orch = orchestrator.clone();
                    crate::system::runtime::RUNTIME.spawn_blocking(move || {
                        orch.handle_bluetooth_session(stream);
                    });
                }
                Err(e) => warn!("❌ Bluetooth connection failed to {:X}: {}", bt_addr, e),
            }
        });
    }

    async fn start_mesh_session(&self, conn: quinn::Connection) {
        let (mut send, mut _recv) = match conn.open_bi().await {
            Ok(pair) => pair,
            Err(_) => return,
        };

        let msg = MeshMessage::Handshake {
            name: hostname::get().map(|h| h.to_string_lossy().to_string()).unwrap_or_else(|_| "Unknown".to_string()),
            peer_id: self.local_peer_id.clone(),
        };

        if let Ok(buf) = serde_json::to_vec(&msg) {
            let _ = send.write_all(&buf).await;
        }
        
        // We can't Register connection here because we don't know the remote peer_id yet.
        // It will be registered in the listener loop when we receive THEIR handshake.
        
        let orchestrator = Arc::new(self.clone());
        crate::system::runtime::RUNTIME.spawn(async move {
            let mut buf = vec![0u8; 65536];
            let mut remote_id: Option<String> = None;
            while let Ok(pair) = conn.accept_bi().await {
                let mut recv = pair.1;
                while let Ok(Some(len)) = recv.read(&mut buf).await {
                    if let Ok(msg) = serde_json::from_slice::<MeshMessage>(&buf[..len]) {
                        if let MeshMessage::Handshake { ref peer_id, ref name } = msg {
                            remote_id = Some(peer_id.clone());
                            if let Ok(mut conns) = orchestrator.connections.write() {
                                let entry = conns.entry(peer_id.clone()).or_insert_with(Vec::new);
                                if !entry.iter().any(|c| c.remote_address() == conn.remote_address()) {
                                    entry.push(conn.clone());
                                    
                                    // Emit PeerConnected event for outgoing connection
                                    crate::ffi::emit_event(crate::ffi::DaemonEvent::PeerConnected {
                                        peer_id: peer_id.clone(),
                                        name: name.clone(),
                                        address: conn.remote_address().ip().to_string(),
                                        port: conn.remote_address().port(),
                                    });

                                    // Auto-save peer to DB
                                    let peer_info = crate::db::PeerInfo {
                                        peer_id: peer_id.clone(),
                                        name: name.clone(),
                                        ips: vec![conn.remote_address().ip()],
                                        port: conn.remote_address().port(),
                                        bt_addr: None, 
                                        shared_key: orchestrator.mesh.get_peer(peer_id).and_then(|p| p.shared_key),
                                    };
                                    let _ = orchestrator.db.save_peer(&peer_info);
                                }
                            }
                        }
                        let sender_id = remote_id.clone().unwrap_or_else(|| "unknown".to_string());
                        orchestrator.handle_message(&sender_id, msg);
                    }
                }
            }
        });
    }
    pub fn select_best_connection(&self, peer_id: &str) -> Result<quinn::Connection> {
        let conns = self.connections.read().map_err(|_| anyhow::anyhow!("Connections lock poisoned"))?;
        let peer_conns = conns.get(peer_id).ok_or_else(|| anyhow::anyhow!("No active connection to {}", peer_id))?;
        
        // Smart Pathfinding: Score = (Base Network Type) - (Real-time RTT in ms)
        let mut scored_conns = peer_conns.iter().map(|c| {
            let stats = c.stats();
            let rtt = stats.path.rtt.as_millis() as i32;
            let net_score = crate::common::networks::classify_network(c.remote_address().ip()) as i32;
            let final_score = net_score - rtt;
            (final_score, c.clone())
        }).collect::<Vec<_>>();
        
        scored_conns.sort_by(|a, b| b.0.cmp(&a.0));
        scored_conns.first().map(|(_, c)| c.clone()).ok_or_else(|| anyhow::anyhow!("Bonding pool empty"))
    }

    pub async fn send_to_peer(&self, peer_id: &str, msg: MeshMessage) -> Result<()> {
        let conn = self.select_best_connection(peer_id)?;

        let (mut send, _) = conn.open_bi().await?;
        let buf = serde_json::to_vec(&msg)?;
        send.write_all(&buf).await?;
        let _ = send.finish();
        Ok(())
    }

    pub fn handle_message(&self, peer_id: &str, msg: MeshMessage) {
        debug!("📩 Mesh message from {}: {:?}", peer_id, msg);
        
        // Update heartbeat
        if let Ok(mut hbs) = self.last_heartbeats.write() {
            hbs.insert(peer_id.to_string(), SystemTime::now());
        }

        match msg {
            MeshMessage::Heartbeat { health } => {
                if let Some(h) = health {
                    if h != crate::system::SystemHealth::Optimal {
                        debug!("🧠 Peer {} reported reduced health: {:?}", peer_id, h);
                    }
                }
            },
            MeshMessage::Chat { text, target_peer_id } => {
                if let Some(ref target) = target_peer_id {
                    if target != &self.local_peer_id {
                        info!("🔀 Smart Mesh: Forwarding chat to {}", target);
                        let orch = self.clone();
                        let target_str = target.clone();
                        let msg_clone = MeshMessage::Chat { text, target_peer_id: Some(target_str.clone()) };
                        crate::system::runtime::RUNTIME.spawn(async move {
                            let _ = orch.send_to_peer(&target_str, msg_clone).await;
                        });
                        return;
                    }
                }
                info!("💬 Chat from {}: {}", peer_id, text);
                emit_event(DaemonEvent::LogMessage { level: "CHAT".into(), message: format!("{}: {}", peer_id, text) });
            },
            MeshMessage::DiscoveryCard { peer_id: discovered_id, name, ips, port } => {
                info!("🤝 Discovery card for {} via {}", name, peer_id);
                self.mesh.update_peer_discovery(crate::db::PeerInfo {
                    peer_id: discovered_id,
                    name,
                    ips: ips.iter().filter_map(|ip| ip.parse().ok()).collect(),
                    port,
                    bt_addr: None,
                    shared_key: None,
                });
            },
            MeshMessage::G2gTransferReq { ref target_peer_id, .. } => {
                if target_peer_id != &self.local_peer_id {
                    info!("🔀 Smart Mesh: Forwarding transfer request to {}", target_peer_id);
                    let orch = self.clone();
                    let msg_clone = msg.clone();
                    let target = target_peer_id.clone();
                    crate::system::runtime::RUNTIME.spawn(async move {
                        let _ = orch.send_to_peer(&target, msg_clone).await;
                    });
                    return;
                }
                
                let (file_name, file_size, transfer_id, thumbnail) = match msg {
                    MeshMessage::G2gTransferReq { file_name, file_size, transfer_id, thumbnail, .. } => (file_name, file_size, transfer_id, thumbnail),
                    _ => unreachable!(),
                };
                
                info!("📂 File offer: {} ({} bytes, ID: {})", file_name, file_size, transfer_id);
                emit_event(DaemonEvent::TransferOffer {
                    peer_id: peer_id.to_string(),
                    transfer_id,
                    file_name,
                    file_size,
                    thumbnail,
                });
            }
            MeshMessage::G2gTransferCancel { transfer_id } => {
                info!("🚫 Peer cancelled transfer {}", transfer_id);
                // We need access to transfer manager here or emit event
                emit_event(DaemonEvent::TransferComplete {
                    transfer_id,
                    status: "CANCELLED_BY_PEER".to_string(),
                });
            }
            MeshMessage::G2gTransferAccept { transfer_id, delta_map } => {
                info!("✅ Transfer accepted: {}", transfer_id);
                let file_path = if let Ok(pending) = self.pending_transfers.read() {
                    pending.get(&transfer_id).cloned()
                } else {
                    None
                };

                if let Some(path) = file_path {
                    let peer_id_str = peer_id.to_string();
                    let orchestrator = self.clone();
                    crate::system::runtime::RUNTIME.spawn(async move {
                        // Look up peer info to get addr and key
                        if let Some(peer_info) = orchestrator.mesh.get_peer(&peer_id_str) {
                            let addr = format!("{}:{}", peer_info.ips[0], peer_info.port);
                            let file_size = std::fs::metadata(&path).map(|m| m.len() as i64).unwrap_or(0);
                            
                            let mut key = [0u8; 32];
                            if let Some(key_b64) = peer_info.shared_key {
                                if let Ok(decoded) = STANDARD.decode(key_b64) {
                                    if decoded.len() == 32 {
                                        key.copy_from_slice(&decoded);
                                    }
                                }
                            }

                            let _ = crate::quic::client::run_quic_transfer(
                                addr,
                                path,
                                file_size,
                                0, // start_offset
                                &key,
                                0, // hash_output
                                0, // throttle_ms
                                0, // cancel_flag
                                0, // progress_callback
                                0, // consent_callback
                                0, // user_data
                                None, // tracker
                                Some(transfer_id),
                                delta_map,
                                None, // local_priv_key
                                None, // expected_peer_id
                            ).await;
                        }
                    });
                }
            }
            MeshMessage::G2gTransferReject { transfer_id } => {
                info!("❌ Peer rejected transfer {}", transfer_id);
                emit_event(DaemonEvent::TransferComplete {
                    transfer_id,
                    status: "REJECTED_BY_PEER".to_string(),
                });
            }
            _ => {
                warn!("Unhandled mesh message: {:?}", msg);
            }
        }
    }
}
