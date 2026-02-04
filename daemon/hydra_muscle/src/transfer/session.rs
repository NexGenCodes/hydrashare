use serde::{Serialize, Deserialize};
use std::time::SystemTime;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TransferDirection {
    Send,
    Receive,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TransferStatus {
    Pending,
    Running,
    Completed,
    Failed,
    Cancelled,
}

impl std::fmt::Display for TransferDirection {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TransferDirection::Send => write!(f, "SEND"),
            TransferDirection::Receive => write!(f, "RECEIVE"),
        }
    }
}

impl std::fmt::Display for TransferStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferSession {
    pub id: String,
    pub file_path: String,
    pub file_size: u64,
    pub bytes_transferred: u64,
    pub direction: TransferDirection,
    pub status: TransferStatus,
    pub start_offset: u64,
    pub peer_id: String,
    pub missing_blocks: Option<Vec<usize>>,
    pub speed: f64,
    pub last_reported_bytes: u64,
    pub last_reported_at: u128,
    pub last_db_write: u64,
    pub created_at: u64,
    pub last_updated: u64,
}

impl TransferSession {
    pub fn new(file_path: String, file_size: u64, direction: TransferDirection, peer_id: String) -> Self {
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        Self {
            id: Uuid::new_v4().to_string(),
            file_path,
            file_size,
            bytes_transferred: 0,
            direction,
            status: TransferStatus::Pending,
            start_offset: 0,
            peer_id,
            missing_blocks: None,
            speed: 0.0,
            last_reported_bytes: 0,
            last_reported_at: SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().as_millis(),
            last_db_write: 0,
            created_at: now,
            last_updated: now,
        }
    }
}
