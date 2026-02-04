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
}

#[derive(Clone)]
pub struct Orchestrator {
    mesh: Arc<MeshNetwork>,
    _discovery: Arc<DiscoveryService>,
    local_peer_id: String,
    last_heartbeats: Arc<RwLock<HashMap<String, SystemTime>>>,
    bound_port: Arc<AtomicU16>,
    connections: Arc<RwLock<HashMap<String, Vec<quinn::Connection>>>>,
    pub pending_transfers: Arc<RwLock<HashMap<String, String>>>,
}

impl Orchestrator {
    pub fn new(local_peer_id: &str, mesh: Arc<MeshNetwork>, discovery: Arc<DiscoveryService>) -> Self {
        Self {
            mesh,
            _discovery: discovery,
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
        self.connections.read().unwrap().get(peer_id).map(|v| v.len()).unwrap_or(0)
    }

    pub fn has_connection(&self, peer_id: &str) -> bool {
        self.connections.read().unwrap().contains_key(peer_id)
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
                    let hbs = heartbeats.read().unwrap();
                    for (id, last_seen) in hbs.iter() {
                        if now.duration_since(*last_seen).unwrap_or(Duration::from_secs(0)) > Duration::from_secs(30) {
                            peers_to_remove.push(id.clone());
                        }
                    }
                }

                for id in peers_to_remove {
                    info!("🔌 Peer {} timed out", id);
                    heartbeats.write().unwrap().remove(&id);
                    let mut peers = mesh.peers.write().unwrap();
                    if let Some(peer) = peers.get_mut(&id) {
                        peer.status = PeerStatus::Offline;
                        emit_event(DaemonEvent::PeerLost { peer_id: id.clone() });
                    }
                }

                // Smart Heartbeat: Broadcast our health to all active connections
                let health = crate::system::INTELLIGENCE.read().unwrap().get_health();
                let msg = MeshMessage::Heartbeat { health: Some(health) };
                
                let peer_ids: Vec<String> = {
                    let conns = orchestrator.connections.read().unwrap();
                    conns.keys().cloned().collect()
                };
                
                for id in peer_ids {
                    let _ = orchestrator.send_to_peer(&id, msg.clone()).await;
                }
            }
        });
    }

    pub async fn bind_quic_server(&self) -> Result<(Endpoint, u16)> {
        let addr = "0.0.0.0:0".parse().unwrap();
        let server_cfg = cert::make_hydra_server_config(None);
        let endpoint = Endpoint::server(server_cfg, addr)?;
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
                            if let MeshMessage::Handshake { ref peer_id, .. } = msg {
                                remote_peer_id = Some(peer_id.clone());
                                // Register connection in bonding pool
                                let mut conns = orchestrator.connections.write().unwrap();
                                let entry = conns.entry(peer_id.clone()).or_insert_with(Vec::new);
                                if !entry.iter().any(|c| c.remote_address() == conn.remote_address()) {
                                    entry.push(conn.clone());
                                    info!("🔗 Bonded connection added for {}: {}", peer_id, conn.remote_address());
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
            if let Err(_) = stream.read_exact(&mut len_buf) { break; }
            let len = u32::from_be_bytes(len_buf) as usize;
            if len > 65536 { break; } // Sanity check

            let mut msg_buf = vec![0u8; len];
            if let Err(_) = stream.read_exact(&mut msg_buf) { break; }

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
            let mut endpoint = Endpoint::client("0.0.0.0:0".parse().unwrap()).expect("Failed to create client endpoint");
            endpoint.set_default_client_config(client_cfg);
            
            let mut futures: Vec<BoxFuture<Result<(std::net::SocketAddr, quinn::Connection), (std::net::SocketAddr, String)>>> = Vec::new();
            for (_, addr) in scored_addrs {
                let conn_fut = endpoint.connect(addr, "localhost");
                futures.push(async move {
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
            for res in results {
                if let Ok((addr, connection)) = res {
                    info!("✅ Path established to {} for {}", addr, peer_id);
                    orchestrator.start_mesh_session(connection).await;
                    succeeded = true;
                }
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

    fn _send_bluetooth_message(stream: &mut BluetoothStream, msg: &MeshMessage) -> io::Result<()> {
        let buf = serde_json::to_vec(msg).map_err(|e| io::Error::new(io::ErrorKind::Other, e))?;
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
            name: hostname::get().unwrap_or_default().to_string_lossy().to_string(),
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
                        if let MeshMessage::Handshake { ref peer_id, .. } = msg {
                            remote_id = Some(peer_id.clone());
                            let mut conns = orchestrator.connections.write().unwrap();
                            let entry = conns.entry(peer_id.clone()).or_insert_with(Vec::new);
                            if !entry.iter().any(|c| c.remote_address() == conn.remote_address()) {
                                entry.push(conn.clone());
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
        let conns = self.connections.read().unwrap();
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
        self.last_heartbeats.write().unwrap().insert(peer_id.to_string(), SystemTime::now());

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
                
                let (file_name, transfer_id, thumbnail) = match msg {
                    MeshMessage::G2gTransferReq { file_name, transfer_id, thumbnail, .. } => (file_name, transfer_id, thumbnail),
                    _ => unreachable!(),
                };
                
                info!("📂 File offer: {} (ID: {})", file_name, transfer_id);
                emit_event(DaemonEvent::TransferOffer {
                    peer_id: peer_id.to_string(),
                    transfer_id,
                    file_name,
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
                let file_path = {
                    let pending = self.pending_transfers.read().unwrap();
                    pending.get(&transfer_id).cloned()
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
            _ => {
                warn!("Unhandled mesh message: {:?}", msg);
            }
        }
    }
}
