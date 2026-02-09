pub mod orchestrator;

use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use crate::discovery::PeerInfo;
use serde::{Serialize, Deserialize};
use tracing::debug;

#[derive(Clone, Serialize, Deserialize, Debug)]
pub enum PeerStatus {
    Online,
    Offline,
    Paired,
    Blocked,
}

pub struct MeshPeer {
    pub info: PeerInfo,
    pub status: PeerStatus,
    pub session_id: Option<u32>,
    pub bluetooth_addr: Option<u64>,
}

pub struct MeshNetwork {
    pub peers: Arc<RwLock<HashMap<String, MeshPeer>>>,
}

impl Default for MeshNetwork {
    fn default() -> Self {
        Self::new()
    }
}

impl MeshNetwork {
    pub fn new() -> Self {
        Self {
            peers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub fn update_peer_discovery(&self, info: PeerInfo) {
        let mut peers = self.peers.write().unwrap();
        if let Some(peer) = peers.get_mut(&info.peer_id) {
            peer.info = info;
            peer.status = PeerStatus::Online;
        } else {
            debug!("New peer discovered in mesh: {}", info.peer_id);
            peers.insert(info.peer_id.clone(), MeshPeer {
                bluetooth_addr: info.bt_addr,
                info,
                status: PeerStatus::Online,
                session_id: None,
            });
        }
    }

    pub fn get_peer(&self, peer_id: &str) -> Option<PeerInfo> {
        self.peers.read().unwrap().get(peer_id).map(|p| p.info.clone())
    }

    pub fn set_peer_session(&self, peer_id: &str, session_id: u32) {
        let mut peers = self.peers.write().unwrap();
        if let Some(peer) = peers.get_mut(peer_id) {
            peer.session_id = Some(session_id);
        }
    }
    pub fn update_peer_status(&self, peer_id: &str, status: PeerStatus) {
        let mut peers = self.peers.write().unwrap();
        if let Some(peer) = peers.get_mut(peer_id) {
            peer.status = status;
        }
    }
}
