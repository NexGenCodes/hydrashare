use std::sync::{Arc, RwLock};
use std::collections::HashMap;
use std::time::{SystemTime, Duration};
use crate::discovery::{DiscoveryService};
use crate::mesh::{MeshNetwork, PeerStatus};
use crate::ffi::{emit_event, DaemonEvent};
use tracing::{info, warn, debug, error};
use serde::{Serialize, Deserialize};
use quinn::Endpoint;
use crate::quic::cert;

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
    Heartbeat,
    Chat {
        text: String,
    },
    G2gTransferReq {
        target_peer_id: String,
        file_name: String,
        transfer_id: String,
    },
}

pub struct Orchestrator {
    mesh: Arc<MeshNetwork>,
    discovery: Arc<DiscoveryService>,
    last_heartbeats: Arc<RwLock<HashMap<String, SystemTime>>>,
}

impl Orchestrator {
    pub fn new(mesh: Arc<MeshNetwork>, discovery: Arc<DiscoveryService>) -> Self {
        Self {
            mesh,
            discovery,
            last_heartbeats: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn start(&self) {
        self.start_monitoring();
        self.start_quic_server();
    }

    fn start_monitoring(&self) {
        let heartbeats = self.last_heartbeats.clone();
        let mesh = self.mesh.clone();
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(10));
            loop {
                interval.tick().await;
                let now = SystemTime::now();
                let mut peers_to_remove = Vec::new();
                
                {
                    let hbs = heartbeats.read().unwrap();
                    let _peers = mesh.peers.read().unwrap();
                    for (id, last_seen) in hbs.iter() {
                        if now.duration_since(*last_seen).unwrap_or(Duration::from_secs(0)) > Duration::from_secs(30) {
                            peers_to_remove.push(id.clone());
                        }
                    }
                }

                for id in peers_to_remove {
                    info!("🔌 Peer {} timed out", id);
                    heartbeats.write().unwrap().remove(&id);
                    // Update mesh status
                    let mut peers = mesh.peers.write().unwrap();
                    if let Some(peer) = peers.get_mut(&id) {
                        peer.status = PeerStatus::Offline;
                        emit_event(DaemonEvent::PeerLost { peer_id: id.clone() });
                    }
                }
            }
        });
    }

    fn start_quic_server(&self) {
        let addr = "0.0.0.0:5053".parse().unwrap();
        let server_cfg = cert::make_hydra_server_config(None);
        
        tokio::spawn(async move {
            let endpoint = Endpoint::server(server_cfg, addr).expect("Failed to bind QUIC server");
            info!("🚀 QUIC Mesh Listener on {}", addr);
            
            while let Some(incoming) = endpoint.accept().await {
                tokio::spawn(async move {
                    if let Ok(conn) = incoming.await {
                        info!("🤝 New mesh connection from {}", conn.remote_address());
                        // Handle session
                    }
                });
            }
        });
    }

    pub fn handle_message(&self, peer_id: &str, msg: MeshMessage) {
        debug!("📩 Mesh message from {}: {:?}", peer_id, msg);
        
        // Update heartbeat
        self.last_heartbeats.write().unwrap().insert(peer_id.to_string(), SystemTime::now());

        match msg {
            MeshMessage::Heartbeat => {
                // Already updated heartbeat above
            },
            MeshMessage::Chat { text } => {
                info!("💬 Chat from {}: {}", peer_id, text);
            },
            MeshMessage::DiscoveryCard { peer_id: _discovered_id, name, ips: _ips, port: _port } => {
                info!("🤝 Discovery card for {} via {}", name, peer_id);
            },
            _ => {
                warn!("Unhandled mesh message: {:?}", msg);
            }
        }
    }
}
