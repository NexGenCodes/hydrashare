pub mod session;

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;
use crate::transfer::session::{TransferSession, TransferStatus, TransferDirection};
use crate::db::Database;

pub struct TransferManager {
    sessions: Arc<RwLock<HashMap<String, TransferSession>>>,
    _db: Arc<Database>,
}

impl TransferManager {
    pub fn new(db: Arc<Database>) -> Self {
        Self {
            sessions: Arc::new(RwLock::new(HashMap::new())),
            _db: db,
        }
    }

    pub async fn create_session(
        &self,
        file_path: String,
        file_size: u64,
        direction: TransferDirection,
        peer_id: String,
    ) -> String {
        let session = TransferSession::new(file_path, file_size, direction, peer_id);
        let id = session.id.clone();
        
        let mut sessions = self.sessions.write().await;
        sessions.insert(id.clone(), session);
        
        // TODO: Persist to DB
        id
    }

    pub async fn update_progress(&self, id: &str, transferred: u64) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            session.bytes_transferred = transferred;
            session.status = TransferStatus::Running;
            
            // Emit to UI
            crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferProgress {
                transfer_id: id.to_string(),
                bytes_transferred: transferred,
                total_bytes: session.file_size,
                speed: 0.0, // TODO: Calculate actual speed
            });

            // TODO: Throttle DB updates (e.g., every 5MB like Go did)
        }
    }

    pub async fn complete_session(&self, id: &str) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            session.status = TransferStatus::Completed;
            info!("✅ Transfer {} completed", id);

            crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferComplete {
                transfer_id: id.to_string(),
                status: "SUCCESS".to_string(),
            });
        }
    }

    pub async fn start_transfer(
        &self,
        peer_id: String,
        file_path: String,
        addr: String,
    ) -> anyhow::Result<String> {
        let file_info = std::fs::metadata(&file_path)?;
        let id = self.create_session(file_path.clone(), file_info.len(), TransferDirection::Send, peer_id.clone()).await;
        
        let id_for_task = id.clone();
        tokio::spawn(async move {
            info!("🚀 Starting transfer {} to {}", id_for_task, addr);
            // This will call quic::client::run_quic_transfer eventually
            // For now, let's keep the logic simple
        });

        Ok(id)
    }

    // A lightweight clone or reference to report back to manager
    pub fn _clone_for_callbacks(&self) -> TransferTracker {
        TransferTracker {
            sessions: self.sessions.clone(),
            _db: self._db.clone(),
        }
    }
}

pub struct TransferTracker {
    sessions: Arc<RwLock<HashMap<String, TransferSession>>>,
    _db: Arc<Database>,
}

impl TransferTracker {
    pub async fn report_progress(&self, id: &str, transferred: u64) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            session.bytes_transferred = transferred;
            // Persistence logic here
        }
    }
}
