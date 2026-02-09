pub mod session;
pub mod delta;
pub mod preview;

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn};
use crate::transfer::session::{TransferSession, TransferStatus, TransferDirection};
use crate::db::Database;

pub struct TransferManager {
    sessions: Arc<RwLock<HashMap<String, TransferSession>>>,
    db: Arc<Database>,
}

impl TransferManager {
    pub fn new(db: Arc<Database>) -> Self {
        let sessions = Arc::new(RwLock::new(HashMap::new()));
        let manager = Self {
            sessions: sessions.clone(),
            db,
        };

        // Spawn timeout checker (runs every 60s)
        let sessions_clone = sessions.clone();
        crate::system::runtime::RUNTIME.spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(60)).await;
                let now = std::time::SystemTime::now()
                    .duration_since(std::time::SystemTime::UNIX_EPOCH)
                    .unwrap()
                    .as_secs();
                
                let mut sessions_to_cancel = Vec::new();
                {
                    let sessions = sessions_clone.read().await;
                    for (id, session) in sessions.iter() {
                        if session.status == TransferStatus::Pending && (now - session.created_at) > 300 {
                            sessions_to_cancel.push(id.clone());
                        }
                    }
                }

                for id in sessions_to_cancel {
                    warn!("⏰ Transfer {} timed out (Pending > 5m)", id);
                    // Note: We can't easily call self.cancel_session from here due to Arc/RwLock cycle
                    // so we do a simplified cancel
                    let mut sessions = sessions_clone.write().await;
                    if let Some(session) = sessions.get_mut(&id) {
                        session.status = TransferStatus::Cancelled;
                        crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferComplete {
                            transfer_id: id.clone(),
                            status: "TIMED_OUT".to_string(),
                        });
                    }
                }
            }
        });

        manager
    }

    pub async fn create_session(
        &self,
        file_path: String,
        file_size: u64,
        direction: TransferDirection,
        peer_id: String,
    ) -> String {
        let session = TransferSession::new(file_path.clone(), file_size, direction.clone(), peer_id.clone());
        let id = session.id.clone();
        
        let mut sessions = self.sessions.write().await;
        sessions.insert(id.clone(), session);
        
        let db = self.db.clone();
        let file_path_clone = file_path.clone();
        let id_clone = id.clone();
        let peer_id_clone = peer_id.clone();
        
        crate::system::runtime::RUNTIME.spawn(async move {
            let _ = db.save_transfer(&id_clone, &file_path_clone, file_size, 0, "PENDING", &peer_id_clone, &direction.to_string());
        });

        id
    }

    pub async fn update_progress(&self, id: &str, transferred: u64) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
            let time_delta = now - session.last_reported_at;
            
            // 1. Speed Calculation (update every 500ms for smoothness)
            if time_delta >= 500 {
                let bytes_delta = transferred - session.last_reported_bytes;
                session.speed = bytes_delta as f64 / (time_delta as f64 / 1000.0);
                session.last_reported_bytes = transferred;
                session.last_reported_at = now;
            }

            session.bytes_transferred = transferred;
            session.status = TransferStatus::Running;
            
            // 2. Throttle DB Updates (every 5MB)
            let bytes_since_db_update = transferred.saturating_sub(session.last_db_write);
            
            if bytes_since_db_update >= 5 * 1024 * 1024 || transferred == session.file_size {
                let db = self.db.clone();
                let id_clone = id.to_string();
                let file_path = session.file_path.clone();
                let size = session.file_size;
                let peer_id = session.peer_id.clone();
                let dir = session.direction.to_string();
                
                crate::system::runtime::RUNTIME.spawn(async move {
                    let _ = db.save_transfer(&id_clone, &file_path, size, transferred, "RUNNING", &peer_id, &dir);
                });
                session.last_db_write = transferred;
            }
            
            // Update last_updated timestamp
            session.last_updated = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();

            // Emit to UI
            crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferProgress {
                transfer_id: id.to_string(),
                bytes_transferred: transferred,
                total_bytes: session.file_size,
                speed: session.speed,
            });
        }
    }

    pub async fn complete_session(&self, id: &str) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            session.status = TransferStatus::Completed;
            info!("✅ Transfer {} completed", id);

            let db = self.db.clone();
            let id_clone = id.to_string();
            let file_path = session.file_path.clone();
            let size = session.file_size;
            let peer_id = session.peer_id.clone();
            let dir = session.direction.to_string();

            crate::system::runtime::RUNTIME.spawn(async move {
                let _ = db.save_transfer(&id_clone, &file_path, size, size, "COMPLETED", &peer_id, &dir);
            });

            crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferComplete {
                transfer_id: id.to_string(),
                status: "SUCCESS".to_string(),
            });
        }
    }

    pub async fn fail_session(&self, id: &str, error: &str) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            session.status = TransferStatus::Failed;
            info!("❌ Transfer {} failed: {}", id, error);

            let db = self.db.clone();
            let id_clone = id.to_string();
            let file_path = session.file_path.clone();
            let size = session.file_size;
            let offset = session.bytes_transferred;
            let peer_id = session.peer_id.clone();
            let dir = session.direction.to_string();

            crate::system::runtime::RUNTIME.spawn(async move {
                let _ = db.save_transfer(&id_clone, &file_path, size, offset, "FAILED", &peer_id, &dir);
            });

            crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferComplete {
                transfer_id: id.to_string(),
                status: format!("FAILED: {}", error),
            });
        }
    }

    pub async fn cancel_session(&self, id: &str) {
        let mut sessions = self.sessions.write().await;
        if let Some(session) = sessions.get_mut(id) {
            session.status = TransferStatus::Cancelled;
            info!("🚫 Transfer {} cancelled", id);

            let db = self.db.clone();
            let id_clone = id.to_string();
            let file_path = session.file_path.clone();
            let size = session.file_size;
            let offset = session.bytes_transferred;
            let peer_id = session.peer_id.clone();
            let dir = session.direction.to_string();

            crate::system::runtime::RUNTIME.spawn(async move {
                let _ = db.save_transfer(&id_clone, &file_path, size, offset, "CANCELLED", &peer_id, &dir);
            });

            crate::ffi::emit_event(crate::ffi::DaemonEvent::TransferComplete {
                transfer_id: id.to_string(),
                status: "CANCELLED".to_string(),
            });
        }
    }

    pub async fn get_peer_id(&self, id: &str) -> Option<String> {
        let sessions = self.sessions.read().await;
        sessions.get(id).map(|s| s.peer_id.clone())
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
        crate::system::runtime::RUNTIME.spawn(async move {
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
            _db: self.db.clone(),
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
