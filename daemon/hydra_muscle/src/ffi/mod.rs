use std::sync::{Mutex, Arc};
use std::collections::VecDeque;
use std::ffi::CString;
use once_cell::sync::Lazy;
use serde::{Serialize, Deserialize};
use tracing::{info, error};
use crate::core::engine::EngineState;
use crate::db::Database;
use crate::mesh::{MeshNetwork, orchestrator::Orchestrator};
use crate::discovery::DiscoveryService;
use crate::transfer::TransferManager;
use crate::auth::{Identity, service::AuthService};
use rkyv::{Archive, Deserialize as RkyvDeserialize, Serialize as RkyvSerialize};
use uuid::Uuid;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use tracing_log::LogTracer;
use std::panic;

pub static EVENT_QUEUE: Lazy<Mutex<VecDeque<Vec<u8>>>> = Lazy::new(|| Mutex::new(VecDeque::new()));
static ENGINE: Lazy<Arc<Mutex<Option<EngineState>>>> = Lazy::new(|| Arc::new(Mutex::new(None)));
use crate::system::runtime::RUNTIME;


#[derive(Archive, RkyvDeserialize, RkyvSerialize, Serialize, Deserialize, Debug, Clone)]
#[archive(check_bytes)]
#[archive_attr(derive(Debug))]
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
    TransferOffer {
        peer_id: String,
        transfer_id: String,
        file_name: String,
        file_size: u64,
        thumbnail: Option<String>,
    },
    LogMessage {
        level: String,
        message: String,
    },
    CredentialsGenerated {
        pin: String,
        session_key: String,
    },
    QrPayloadGenerated {
        payload_json: String,
    },
    SettingReported {
        key: String,
        value: String,
    },
    SessionCodeGenerated {
        code: String,
    },
    SignalingStarted {
        id: String,
    },
    CodeGenerated {
        key: String,
        pin: Option<String>,
        ip: String,
    },
    PeerDisconnected {
        peer_id: String,
    },
    PeerConnected {
        peer_id: String,
        name: String,
        address: String,
        port: u16,
    },
}

#[derive(Archive, RkyvDeserialize, RkyvSerialize, Deserialize, Debug)]
#[archive(check_bytes)]
#[archive_attr(derive(Debug))]
#[serde(tag = "type", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DaemonCommand {
    Init {
        data_dir: String,
    },
    StartEngine,
    StopEngine,
    SaveMessage { message: String }, // JSON of MessageInfo
    GetMessages { peer_id: String },
    SendFile {
        peer_id: String,
        file_path: String,
    },
    AcceptFile { offer_id: String, peer_id: String, file_size: u64, dest_path: String },
    CancelTransfer { transfer_id: String },
    MarkMessagesRead { peer_id: String },
    RejectFile {
        offer_id: String,
        peer_id: String,
    },
    GenerateCredentials,
    GenerateQrPayload,
    JoinSession { pin: String },
    SetSettings {
        key: String,
        text: String,
    },
    GetSettings {
        key: String,
    },
    GenerateSessionCode,
    JoinSessionCode { text: String },
    SetDeviceName { name: String },
    StartDiscovery,
    GenerateCode,
    ConnectPeer {
        peer_id: String,
        address: String,
        port: u16,
        encryption_key: Option<String>,
    },
    StopDiscovery,
    DisconnectPeer {
        peer_id: String,
    },
}

pub fn emit_event(event: DaemonEvent) {
    // 1. Send to FRB StreamSink (New)
    if let Ok(guard) = crate::api::EVENT_SINK.lock() {
        if let Some(sink) = guard.as_ref() {
            let _ = sink.add(event.clone());
        }
    }

    // 2. Send to Legacy Event Queue (Old/Polling)
    if let Ok(json) = serde_json::to_string(&event) {
        let c_str = CString::new(json).expect("Failed to create CString");
        if let Ok(mut queue) = EVENT_QUEUE.lock() {
            queue.push_back(c_str.into_bytes_with_nul());
        }
    }
}

// --- FFI EXPORTS REMOVED (Migrated to FRB) ---

/// Handle a daemon command (used by both binary and JSON FFI)
pub fn handle_command(command: DaemonCommand) -> i32 {
    match command {
        DaemonCommand::Init { data_dir } => {
            // 1. Bridge tracing -> log
            let _ = LogTracer::init();

            #[cfg(target_os = "android")]
            {
                android_logger::init_once(
                    android_logger::Config::default()
                        .with_max_level(log::LevelFilter::Info)
                        .with_tag("HydraDaemon")
                );
            }

            // 2. Set Global Panic Hook
            panic::set_hook(Box::new(|panic_info| {
                let backtrace = backtrace::Backtrace::new();
                let location = panic_info.location().map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column())).unwrap_or_else(|| "unknown".to_string());
                let message = if let Some(s) = panic_info.payload().downcast_ref::<&str>() {
                    s.to_string()
                } else if let Some(s) = panic_info.payload().downcast_ref::<String>() {
                    s.clone()
                } else {
                    "Unknown panic".to_string()
                };

                let panic_msg = format!("🔥 CRITICAL RUST PANIC at {}: {}\n{:?}", location, message, backtrace);
                
                #[cfg(target_os = "android")]
                {
                    log::error!("{}", panic_msg);
                }
                
                eprintln!("{}", panic_msg);

                // Try to emit event
                emit_event(DaemonEvent::LogMessage {
                    level: "CRITICAL".to_string(),
                    message: format!("Native Crash: {}", message),
                });
            }));

            info!("🚀 Panic hook and logging bridge initialized");

            let data_path = std::path::Path::new(&data_dir);
            if !data_path.exists() {
                if let Err(e) = std::fs::create_dir_all(data_path) {
                    let msg = format!("❌ Failed to create data directory at {:?}: {}", data_path, e);
                    error!("{}", msg);
                    emit_event(DaemonEvent::LogMessage {
                        level: "ERROR".to_string(),
                        message: msg,
                    });
                } else {
                    info!("📁 Created data directory at {:?}", data_path);
                }
            } else {
                info!("📁 Data directory exists at {:?}", data_path);
            }

            
            let db_path = data_path.join("hydra.db");
            let db = match Database::new(&db_path) {
                Ok(d) => Arc::new(d),
                Err(e) => {
                    let msg = format!("❌ Failed to open database at {:?}: {}", db_path, e);
                    error!("{}", msg);
                    emit_event(DaemonEvent::LogMessage {
                        level: "ERROR".to_string(),
                        message: msg,
                    });
                    return -3;
                }

            };

            // Start background maintenance loop (7-day cleanup)
            crate::system::start_maintenance_loop(db.clone());
            
            let mesh = Arc::new(MeshNetwork::new());
            let transfer = Arc::new(TransferManager::new(db.clone()));
            
            let my_id = match db.get_config("hydra_priv_key").unwrap_or(None) {
                Some(key) => Identity::from_saved(&key).unwrap_or_else(|_| Identity::generate()),
                None => Identity::generate(),
            };

            let auth = Arc::new(AuthService::new(db.clone()));
            let discovery = Arc::new(DiscoveryService::new(&my_id.peer_id, mesh.clone(), auth.clone()));
            let orchestrator = Arc::new(Orchestrator::new(&my_id.peer_id, mesh.clone(), discovery.clone(), db.clone()));

            let mut engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ Fatal: ENGINE Mutex poisoned: {}", e);
                    return -1;
                }
            };
            *engine = Some(EngineState::new(db, mesh, discovery, transfer, orchestrator, auth));

            info!("🚀 Engine initialized in {}", data_dir);
        }
        DaemonCommand::StartEngine => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let orchestrator = state.orchestrator.clone();
                let discovery = state.discovery.clone();

                
                // Spawn async start
                RUNTIME.spawn(async move {
                    let port = orchestrator.start().await.unwrap_or(0);
                    
                    // Restore saved peers and attempt reconnection
                    orchestrator.restore_peers_from_db().await;
                    
                    discovery.start(orchestrator.clone(), port);
                    crate::system::start_intelligence_loop();
                    info!("📢 Discovery started on port {}", port);
                });
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
        DaemonCommand::SaveMessage { message } => {
            let engine = ENGINE.lock().unwrap();
            if let Some(state) = engine.as_ref() {
                let db = &state.db;
                match serde_json::from_str::<crate::db::MessageInfo>(&message) {
                    Ok(msg) => {
                        if let Err(e) = db.save_message(&msg) {
                            error!("❌ Failed to save message: {}", e);
                            return -1;
                        } else {
                            return 0;
                        }
                    }
                    Err(e) => {
                        error!("❌ Failed to parse message JSON: {}", e);
                        return -2;
                    }
                }
            } else {
                return -3;
            }
        }
        DaemonCommand::GetMessages { peer_id } => {
            let engine = ENGINE.lock().unwrap();
            if let Some(state) = engine.as_ref() {
                let db = &state.db;
                match db.get_messages(&peer_id) {
                    Ok(messages) => {
                        match serde_json::to_string(&messages) {
                            Ok(json) => {
                                emit_event(DaemonEvent::LogMessage {
                                    level: "DATA".to_string(),
                                    message: format!("history:{}", json),
                                });
                                return 0;
                            }
                            Err(_) => return -1,
                        }
                    }
                    Err(_) => return -2,
                }
            } else {
                return -3;
            }
        }

        DaemonCommand::SendFile { peer_id, file_path } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                // Look up peer in mesh
                let peer_info = state.mesh.get_peer(&peer_id);
                
                if let Some(info) = peer_info {
                    let orchestrator = state.orchestrator.clone();
                    let file_name = std::path::Path::new(&file_path)
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("unknown")
                        .to_string();
                    let file_path_clone = file_path.clone();

                    RUNTIME.spawn(async move {
                        let transfer_id = Uuid::new_v4().to_string();
                        
                        // Generate thumbnail
                        let thumbnail = crate::transfer::preview::PreviewGenerator::generate_thumbnail(&file_path_clone);

                        let file_size = std::fs::metadata(&file_path_clone).map(|m| m.len()).unwrap_or(0);
                        
                        // Register in orchestrator for when Accept comes back
                        {
                            if let Ok(mut pending) = orchestrator.pending_transfers.write() {
                                pending.insert(transfer_id.clone(), file_path_clone);
                            }
                        }

                        // Send G2gTransferReq via Mesh
                        let _ = orchestrator.send_to_peer(&info.peer_id, crate::mesh::orchestrator::MeshMessage::G2gTransferReq {
                            target_peer_id: info.peer_id.clone(),
                            file_name,
                            file_size,
                            transfer_id,
                            thumbnail,
                        }).await;
                    });
                } else {
                    error!("❌ Peer not found in mesh: {}", peer_id);
                    emit_event(DaemonEvent::LogMessage {
                        level: "ERROR".to_string(),
                        message: format!("Peer {} not found or not connected", peer_id),
                    });
                }
            } else {
                return -4;
            }
        }
        DaemonCommand::AcceptFile { offer_id, peer_id, file_size, dest_path } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let orchestrator = state.orchestrator.clone();
                let _transfer_manager = state.transfer.clone();
                let mesh = state.mesh.clone();
                let peer_id_clone = peer_id.clone();
                let offer_id_clone = offer_id.clone();
                let dest_path_clone = dest_path.clone();

                RUNTIME.spawn(async move {
                    info!("✅ Accepting file offer {} from {}", offer_id_clone, peer_id_clone);
                    
                    // 1. Check for existing .part file and compute map
                    let part_file = format!("{}.part", dest_path_clone);
                    let delta_map = if std::path::Path::new(&part_file).exists() {
                        crate::transfer::delta::DeltaHasher::compute_map(&part_file).ok()
                    } else {
                        None
                    };

                    // 2. Send G2gTransferAccept via Mesh
                    let _ = orchestrator.send_to_peer(&peer_id_clone, crate::mesh::orchestrator::MeshMessage::G2gTransferAccept {
                        transfer_id: offer_id_clone.clone(),
                        delta_map: delta_map.clone(),
                    }).await;

                    // 3. Start QUIC server to receive
                    let listen_port = orchestrator.get_port();
                    
                    // Retrieve shared key for authentication
                    let mut key = [0u8; 32];
                    if let Some(peer_info) = mesh.get_peer(&peer_id_clone) {
                        if let Some(key_b64) = peer_info.shared_key {
                            if let Ok(decoded) = STANDARD.decode(key_b64) {
                                if decoded.len() == 32 {
                                    key.copy_from_slice(&decoded);
                                }
                            }
                        }
                    }

                    let _ = crate::quic::server::run_quic_receive(
                        format!("0.0.0.0:{}", listen_port),
                        dest_path_clone,
                        file_size as i64,
                        0, // start_offset (placeholder)
                        &key,
                        0, // hash_output
                        0, // throttle_ms
                        0, // cancel_flag
                        0, // progress_callback
                        0, // consent_callback
                        0, // user_data
                        None, // tracker
                        Some(offer_id_clone),
                        delta_map,
                        None, // local_priv_key
                        None, // expected_peer_id
                    ).await;
                });
            }
        }
        DaemonCommand::CancelTransfer { transfer_id } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let transfer_id_clone = transfer_id.clone();
                let manager = state.transfer.clone();
                let orchestrator = state.orchestrator.clone();
                
                RUNTIME.spawn(async move {
                    // 1. Get peer ID before cancelling session state
                    let peer_id = manager.get_peer_id(&transfer_id_clone).await;

                    // 2. Mark locally as cancelled
                    manager.cancel_session(&transfer_id_clone).await;
                    
                    // 3. Notify peer via mesh
                    if let Some(peer_id) = peer_id {
                        let _ = orchestrator.send_to_peer(&peer_id, crate::mesh::orchestrator::MeshMessage::G2gTransferCancel {
                            transfer_id: transfer_id_clone,
                        }).await;
                    }
                });
            } else {
                return -4;
            }
        }
        DaemonCommand::MarkMessagesRead { peer_id } => {
            info!("📖 Marking messages with {} as read", peer_id);
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let _ = state.db.mark_all_messages_read(&peer_id);
            }
        }
        DaemonCommand::RejectFile { offer_id, peer_id } => {
            info!("❌ Rejecting file offer {} from {}", offer_id, peer_id);
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let orchestrator = state.orchestrator.clone();
                RUNTIME.spawn(async move {
                    let _ = orchestrator.send_to_peer(&peer_id, crate::mesh::orchestrator::MeshMessage::G2gTransferReject {
                        transfer_id: offer_id,
                    }).await;
                });
            }
        }
        DaemonCommand::GenerateCredentials => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let (pin, key) = state.auth.generate_credentials();
                emit_event(DaemonEvent::CredentialsGenerated { pin, session_key: key });
            } else {
                return -4;
            }
        }
        DaemonCommand::GenerateQrPayload => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let my_id = state.db.get_config("hydra_peer_id").unwrap_or(None).unwrap_or_else(|| "unknown".to_string());
                let port = state.orchestrator.get_port();
                let payload = state.auth.generate_qr_payload(&my_id, port);
                let json = serde_json::to_string(&payload).unwrap_or_default();
                emit_event(DaemonEvent::QrPayloadGenerated { payload_json: json });
            } else {
                return -4;
            }
        }
        DaemonCommand::JoinSession { pin } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                state.discovery.start_signaling(&pin, state.orchestrator.clone());
            } else {
                return -4;
            }
        }
        DaemonCommand::SetSettings { key, text } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                info!("⚙️ Setting: {} = {}", key, text);
                let _ = state.db.set_config(&format!("setting_{}", key), &text);
            } else {
                return -4;
            }
        }
        DaemonCommand::GetSettings { key } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let value = state.db.get_config(&format!("setting_{}", key)).unwrap_or(None).unwrap_or_default();
                emit_event(DaemonEvent::SettingReported { key, value });
            } else {
                return -4;
            }
        }
        DaemonCommand::GenerateSessionCode => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let code = state.discovery.generate_ldt_code(state.orchestrator.clone());
                emit_event(DaemonEvent::SessionCodeGenerated { code });
            } else {
                return -4;
            }
        }
        DaemonCommand::JoinSessionCode { text } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                state.discovery.join_ldt_session(&text, state.orchestrator.clone());
            } else {
                return -4;
            }
        }
        DaemonCommand::SetDeviceName { name } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let _ = state.db.set_config("device_name", &name);
                info!("🏷️ Device name set to: {}", name);
            } else {
                return -4;
            }
        }
        DaemonCommand::StartDiscovery => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let orchestrator = state.orchestrator.clone();
                let discovery = state.discovery.clone();
                RUNTIME.spawn(async move {
                    let port = orchestrator.start().await.unwrap_or(0);
                    discovery.start(orchestrator, port);
                    crate::system::start_intelligence_loop();
                    info!("📢 Discovery started via START_DISCOVERY on port {}", port);
                });
            } else {
                return -4;
            }
        }
        DaemonCommand::GenerateCode => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let (pin, key) = state.auth.generate_credentials();
                let ip = state.auth.get_local_ips().first().cloned().unwrap_or_else(|| "127.0.0.1".to_string());
                emit_event(DaemonEvent::CodeGenerated { key, pin: Some(pin.clone()), ip: ip.clone() });
                info!("🔑 Generated pair code: {} @ {}", pin, ip);
            } else {
                return -4;
            }
        }
        DaemonCommand::ConnectPeer { peer_id, address, port, encryption_key } => {
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let orchestrator = state.orchestrator.clone();
                let mesh = state.mesh.clone();
                let db = state.db.clone();
                
                info!("🔗 ConnectPeer: Connecting to {} at {}:{}", peer_id, address, port);
                
                RUNTIME.spawn(async move {
                    // Parse address
                    let socket_addr = match format!("{}:{}", address, port).parse::<std::net::SocketAddr>() {
                        Ok(addr) => addr,
                        Err(e) => {
                            error!("❌ Invalid address {}:{}: {}", address, port, e);
                            return;
                        }
                    };
                    
                    // Create peer info for mesh
                    let peer_info = crate::db::PeerInfo {
                        peer_id: peer_id.clone(),
                        name: "QR Peer".to_string(), // Will be updated on handshake
                        ips: vec![socket_addr.ip()],
                        port,
                        bt_addr: None,
                        shared_key: encryption_key.clone(),
                    };
                    
                    // Add to mesh
                    mesh.update_peer_discovery(peer_info.clone());
                    
                    // Save to DB if we have an encryption key
                    if encryption_key.is_some() {
                        let _ = db.save_peer(&peer_info);
                        info!("🔑 Peer saved with encryption key. Initializing secure handshake...");
                    }
                    
                    // Attempt connection
                    info!("🚀 Initiating connection attempt to {}...", peer_id);
                    orchestrator.connect_to_peer_multi(peer_id, vec![socket_addr]);
                });
            } else {
                return -4;
            }
        }
        DaemonCommand::StopDiscovery => {
            info!("🛑 FFI: StopDiscovery");
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let discovery = state.discovery.clone();
                RUNTIME.spawn(async move {
                    discovery.stop().await;
                });
            } else {
                return -4;
            }
        }
        DaemonCommand::DisconnectPeer { peer_id } => {
            info!("✂️ FFI: DisconnectPeer {}", peer_id);
            let engine = match ENGINE.lock() {
                Ok(guard) => guard,
                Err(e) => {
                    error!("❌ ENGINE Mutex poisoned: {}", e);
                    return -4;
                }
            };
            if let Some(state) = engine.as_ref() {
                let orchestrator = state.orchestrator.clone();
                RUNTIME.spawn(async move {
                    orchestrator.disconnect_peer(&peer_id).await;
                });
            } else {
                return -4;
            }
        }
    }
    
    0
}
