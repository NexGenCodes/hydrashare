use std::sync::{Mutex, Arc};
use std::collections::VecDeque;
use std::ffi::{CString, CStr};
use std::os::raw::c_char;
use once_cell::sync::Lazy;
use serde::{Serialize, Deserialize};
use tracing::{debug, info};
use crate::core::engine::EngineState;
use crate::db::Database;
use crate::mesh::{MeshNetwork, orchestrator::Orchestrator};
use crate::discovery::DiscoveryService;
use crate::transfer::TransferManager;
use crate::auth::{Identity, service::AuthService};

pub static EVENT_QUEUE: Lazy<Mutex<VecDeque<String>>> = Lazy::new(|| Mutex::new(VecDeque::new()));
static ENGINE: Lazy<Arc<Mutex<Option<EngineState>>>> = Lazy::new(|| Arc::new(Mutex::new(None)));

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DaemonEvent {
    PeerDiscovered {
        peer_id: String,
        name: String,
        ip: String,
        port: u16,
    },
    PeerLost {
        peer_id: String,
    },
    TransferProgress {
        transfer_id: String,
        bytes_transferred: u64,
        total_bytes: u64,
        speed: f64,
    },
    TransferComplete {
        transfer_id: String,
        status: String,
    },
    PairingRequest {
        peer_id: String,
        pin: String,
    },
    LogMessage {
        level: String,
        message: String,
    },
    CredentialsGenerated {
        pin: String,
        session_key: String,
    },
}

#[derive(Deserialize, Debug)]
#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DaemonCommand {
    Init {
        data_dir: String,
    },
    StartEngine,
    StopEngine,
    SendFile {
        file_path: String,
        dest_ip: String,
    },
    AcceptFile {
        offer_id: String,
        dest_ip: String,
    },
    RejectFile {
        offer_id: String,
        dest_ip: String,
    },
    GenerateCredentials,
}

pub fn emit_event(event: DaemonEvent) {
    if let Ok(json) = serde_json::to_string(&event) {
        if let Ok(mut queue) = EVENT_QUEUE.lock() {
            queue.push_back(json);
        }
    }
}

// --- FFI EXPORTS ---

#[no_mangle]
pub extern "C" fn poll_event() -> *mut c_char {
    if let Ok(mut queue) = EVENT_QUEUE.lock() {
        if let Some(event_json) = queue.pop_front() {
            return CString::new(event_json).unwrap().into_raw();
        }
    }
    std::ptr::null_mut()
}

#[no_mangle]
pub unsafe extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}

#[no_mangle]
pub unsafe extern "C" fn send_command(cmd_json: *const c_char) -> i32 {
    if cmd_json.is_null() {
        return -1;
    }
    
    let c_str = CStr::from_ptr(cmd_json);
    let r_str = c_str.to_string_lossy();
    
    debug!("📩 Received command: {}", r_str);
    
    let command: DaemonCommand = match serde_json::from_str(&r_str) {
        Ok(cmd) => cmd,
        Err(e) => {
            tracing::error!("Failed to parse command: {}", e);
            return -2;
        }
    };

    match command {
        DaemonCommand::Init { data_dir } => {
            let data_path = std::path::Path::new(&data_dir);
            if !data_path.exists() {
                let _ = std::fs::create_dir_all(data_path);
            }
            
            let db_path = data_path.join("hydra.db");
            let db = match Database::new(&db_path) {
                Ok(d) => Arc::new(d),
                Err(_) => return -3,
            };

            let mesh = Arc::new(MeshNetwork::new());
            let transfer = Arc::new(TransferManager::new(db.clone()));
            
            let my_id = match db.get_config("hydra_priv_key").unwrap_or(None) {
                Some(key) => Identity::from_saved(&key).unwrap_or_else(|_| Identity::generate()),
                None => Identity::generate(),
            };

            let discovery = Arc::new(DiscoveryService::new(&my_id.peer_id, 5051, mesh.clone()));
            let orchestrator = Arc::new(Orchestrator::new(mesh.clone(), discovery.clone()));
            let auth = Arc::new(AuthService::new(db.clone()));

            let mut engine = ENGINE.lock().unwrap();
            *engine = Some(EngineState::new(db, mesh, discovery, transfer, orchestrator, auth));
            info!("🚀 Engine initialized in {}", data_dir);
        }
        DaemonCommand::StartEngine => {
            let engine = ENGINE.lock().unwrap();
            if let Some(state) = engine.as_ref() {
                state.discovery.start();
                state.orchestrator.start();
                info!("📢 Discovery and Orchestration started");
            } else {
                return -4;
            }
        }
        DaemonCommand::StopEngine => {
            let mut engine = ENGINE.lock().unwrap();
            *engine = None;
            info!("🛑 Engine stopped");
        }
        DaemonCommand::SendFile { file_path, dest_ip } => {
            let engine = ENGINE.lock().unwrap();
            if let Some(state) = engine.as_ref() {
                let transfer_manager = state.transfer.clone();
                tokio::spawn(async move {
                    let _ = transfer_manager.start_transfer("peer_id_placeholder".to_string(), file_path, dest_ip).await;
                });
            } else {
                return -4;
            }
        }
        DaemonCommand::GenerateCredentials => {
            let engine = ENGINE.lock().unwrap();
            if let Some(state) = engine.as_ref() {
                let (pin, key) = state.auth.generate_credentials();
                emit_event(DaemonEvent::CredentialsGenerated { pin, session_key: key });
            } else {
                return -4;
            }
        }
        _ => {
            info!("Command not yet implemented");
        }
    }
    
    0
}
