use std::sync::Arc;
use std::ffi::c_void;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicI32, Ordering};
use std::slice;
use quinn::Endpoint;
use aes_gcm::{aead::{AeadInPlace, KeyInit}, Aes256Gcm, Nonce};
use sha2::{Sha256, Digest};
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncSeekExt};
use tokio::sync::mpsc;
use rand::Rng;

use crate::common::*;
use crate::quic::{ProgressCallback, cert, session};
use crate::transfer::delta::{FileMap, BLOCK_SIZE};

#[cfg(windows)]
use std::os::windows::io::FromRawSocket;
#[cfg(unix)]
use std::os::unix::io::FromRawFd;

const COMPRESSED_FLAG: u32 = 0x8000_0000;
const PARALLEL_STREAMS: usize = 4;

fn is_compressible(path: &str) -> bool {
    let path_obj = std::path::Path::new(path);
    let ext = path_obj.extension().and_then(|s| s.to_str()).unwrap_or("").to_lowercase();
    matches!(ext.as_str(), "txt" | "log" | "md" | "json" | "xml" | "csv" | "sql" | "js" | "rs" | "go" | "c" | "cpp" | "java" | "py" | "html" | "css")
}

fn derive_nonce(master: &[u8; 12], index: u32) -> [u8; 12] {
    let mut nonce = [0u8; 12];
    nonce.copy_from_slice(master);
    let idx_bytes = index.to_be_bytes();
    for i in 0..4 {
        nonce[8 + i] ^= idx_bytes[i];
    }
    nonce
}

pub async fn run_quic_transfer(
    target_addr: String,
    file_path: String,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: usize,
    throttle_ms: i32,
    cancel_flag: usize,
    progress_callback: usize,
    _consent_callback: usize,
    user_data: usize,
    _tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
    delta_map: Option<FileMap>,
    _local_priv_key: Option<&[u8]>,
    expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let addr: SocketAddr = target_addr.parse().map_err(|_| ERROR_QUIC_ERROR)?;
    let client_cfg = cert::make_client_config(expected_peer_id);
    let mut endpoint = Endpoint::client("0.0.0.0:0".parse().unwrap()).map_err(|_| ERROR_QUIC_ERROR)?;
    endpoint.set_default_client_config(client_cfg);

    let conn = endpoint.connect(addr, "localhost").map_err(|_| ERROR_QUIC_ERROR)?.await.map_err(|_| ERROR_QUIC_ERROR)?;
    let mut master_nonce_bytes = [0u8; 12];
    rand::thread_rng().fill(&mut master_nonce_bytes);
    let tid = transfer_id.unwrap_or_else(|| "00000000-0000-0000-0000-000000000000".to_string());
    
    let shared_next_chunk = Arc::new(std::sync::atomic::AtomicUsize::new((start_offset as usize) / BLOCK_SIZE));
    let shared_total_sent = Arc::new(std::sync::atomic::AtomicU64::new(start_offset as u64));
    let shared_hasher = Arc::new(std::sync::Mutex::new(Sha256::new()));
    let atomic_cancel = if cancel_flag != 0 { Some(unsafe { Arc::new(&*(cancel_flag as *const AtomicI32)) }) } else { None };

    let delta_map = Arc::new(delta_map);
    let key_arc = Arc::new(key.to_vec());
    let file_path_arc = Arc::new(file_path);

    let mut workers = Vec::new();
    for _ in 0..PARALLEL_STREAMS {
        let conn = conn.clone();
        let tid = tid.clone();
        let master_nonce = master_nonce_bytes;
        let next_chunk = shared_next_chunk.clone();
        let total_sent = shared_total_sent.clone();
        let hasher = shared_hasher.clone();
        let cancel = atomic_cancel.clone();
        let d_map = delta_map.clone();
        let key = key_arc.clone();
        let f_path = file_path_arc.clone();

        let worker = crate::system::runtime::RUNTIME.spawn(async move {
            let mut send = conn.open_uni().await.map_err(|_| ERROR_QUIC_ERROR)?;
            send.write_all(&(tid.as_bytes().len() as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            send.write_all(tid.as_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            send.write_all(&master_nonce).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

            let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| ERROR_CRYPTO_FAILED)?;
            let mut file = File::open(&*f_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;

            loop {
                if let Some(ref c) = cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
                let health = crate::system::INTELLIGENCE.read().unwrap().get_health();
                if health != crate::system::SystemHealth::Optimal {
                    tokio::time::sleep(std::time::Duration::from_millis(50)).await;
                }
                let current_idx = next_chunk.fetch_add(1, Ordering::SeqCst);
                let offset = (current_idx as u64) * (BLOCK_SIZE as u64);
                if offset >= file_size as u64 { break; }
                if let Some(ref map) = *d_map { if current_idx < map.block_hashes.len() { total_sent.fetch_add(BLOCK_SIZE as u64, Ordering::SeqCst); continue; } }

                let bytes_to_read = std::cmp::min(BLOCK_SIZE as u64, file_size as u64 - offset) as usize;
                let mut plaintext = vec![0u8; bytes_to_read];
                file.seek(std::io::SeekFrom::Start(offset)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                file.read_exact(&mut plaintext).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                { let mut h = hasher.lock().unwrap(); h.update(&plaintext); }

                let mut is_compressed = false;
                let mut data_to_encrypt = plaintext;
                if is_compressible(&*f_path) {
                    if let Ok(compressed) = zstd::encode_all(&data_to_encrypt[..], 3) {
                        if compressed.len() < data_to_encrypt.len() { data_to_encrypt = compressed; is_compressed = true; }
                    }
                }

                let mut encrypt_buf = vec![0u8; data_to_encrypt.len() + 16];
                encrypt_buf[..data_to_encrypt.len()].copy_from_slice(&data_to_encrypt);
                let nonce_v = derive_nonce(&master_nonce, current_idx as u32);
                let tag = cipher.encrypt_in_place_detached(Nonce::from_slice(&nonce_v), b"", &mut encrypt_buf[..data_to_encrypt.len()]).map_err(|_| ERROR_CRYPTO_FAILED)?;
                encrypt_buf[data_to_encrypt.len()..].copy_from_slice(&tag);
                
                let mut c_len = encrypt_buf.len() as u32;
                if is_compressed { c_len |= COMPRESSED_FLAG; }
                send.write_all(&(current_idx as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                send.write_all(&c_len.to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                send.write_all(&encrypt_buf).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

                let newly_sent = total_sent.fetch_add(bytes_to_read as u64, Ordering::SeqCst) + bytes_to_read as u64;
                if progress_callback != 0 {
                    let cb: ProgressCallback = unsafe { std::mem::transmute(progress_callback) };
                    unsafe { cb(newly_sent as i64, file_size, user_data as *mut c_void); }
                }
                if throttle_ms > 0 { tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await; }
            }
            send.finish().map_err(|_| ERROR_TRANSFER_FAILED)?; Ok(())
        });
        workers.push(worker);
    }
    for worker in workers { worker.await.map_err(|_| ERROR_QUIC_ERROR)??; }
    if hash_output != 0 {
        let h = shared_hasher.lock().unwrap();
        let result = h.clone().finalize();
        unsafe { slice::from_raw_parts_mut(hash_output as *mut u8, 32).copy_from_slice(&result); }
    }
    Ok(())
}

pub async fn run_quic_transfer_fd(
    udp_fd: isize,
    remote_addr: SocketAddr,
    header_json: String,
    file_path: String,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: usize,
    throttle_ms: i32,
    cancel_flag: usize,
    progress_callback: usize,
    _consent_callback: usize,
    user_data: usize,
    _tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
    delta_map: Option<FileMap>,
    _local_priv_key: Option<&[u8]>,
    expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let socket = unsafe {
        #[cfg(unix)] { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)] { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };
    let client_cfg = cert::make_client_config(expected_peer_id);
    let endpoint = Endpoint::new(Default::default(), None, socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;
    let conn = endpoint.connect_with(client_cfg, remote_addr, "localhost").map_err(|_| ERROR_QUIC_ERROR)?.await.map_err(|_| ERROR_QUIC_ERROR)?;

    let (mut send_ctrl, _) = conn.open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;
    let h_bytes = header_json.into_bytes();
    send_ctrl.write_all(&(h_bytes.len() as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send_ctrl.write_all(&h_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let _ = send_ctrl.finish();

    let mut master_nonce_bytes = [0u8; 12];
    rand::thread_rng().fill(&mut master_nonce_bytes);
    let tid = transfer_id.unwrap_or_else(|| "00000000-0000-0000-0000-000000000000".to_string());
    let shared_next_chunk = Arc::new(std::sync::atomic::AtomicUsize::new((start_offset as usize) / BLOCK_SIZE));
    let shared_total_sent = Arc::new(std::sync::atomic::AtomicU64::new(start_offset as u64));
    let shared_hasher = Arc::new(std::sync::Mutex::new(Sha256::new()));
    let atomic_cancel = if cancel_flag != 0 { Some(unsafe { Arc::new(&*(cancel_flag as *const AtomicI32)) }) } else { None };
    let delta_map = Arc::new(delta_map);
    let key_arc = Arc::new(key.to_vec());
    let file_path_arc = Arc::new(file_path);

    let mut workers = Vec::new();
    for _ in 0..PARALLEL_STREAMS {
        let conn = conn.clone();
        let tid = tid.clone();
        let master_nonce = master_nonce_bytes;
        let next_chunk = shared_next_chunk.clone();
        let total_sent = shared_total_sent.clone();
        let hasher = shared_hasher.clone();
        let cancel = atomic_cancel.clone();
        let d_map = delta_map.clone();
        let key = key_arc.clone();
        let f_path = file_path_arc.clone();

        let worker = crate::system::runtime::RUNTIME.spawn(async move {
            let mut send = conn.open_uni().await.map_err(|_| ERROR_QUIC_ERROR)?;
            send.write_all(&(tid.as_bytes().len() as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            send.write_all(tid.as_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            send.write_all(&master_nonce).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| ERROR_CRYPTO_FAILED)?;
            let mut file = File::open(&*f_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
            loop {
                if let Some(ref c) = cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
                let current_idx = next_chunk.fetch_add(1, Ordering::SeqCst);
                let offset = (current_idx as u64) * (BLOCK_SIZE as u64);
                if offset >= file_size as u64 { break; }
                if let Some(ref map) = *d_map { if current_idx < map.block_hashes.len() { total_sent.fetch_add(BLOCK_SIZE as u64, Ordering::SeqCst); continue; } }
                let bytes_to_read = std::cmp::min(BLOCK_SIZE as u64, file_size as u64 - offset) as usize;
                let mut plaintext = vec![0u8; bytes_to_read];
                file.seek(std::io::SeekFrom::Start(offset)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                file.read_exact(&mut plaintext).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                { let mut h = hasher.lock().unwrap(); h.update(&plaintext); }
                let mut is_compressed = false;
                let mut data_to_encrypt = plaintext;
                if is_compressible(&*f_path) {
                    if let Ok(compressed) = zstd::encode_all(&data_to_encrypt[..], 3) {
                        if compressed.len() < data_to_encrypt.len() { data_to_encrypt = compressed; is_compressed = true; }
                    }
                }
                let mut encrypt_buf = vec![0u8; data_to_encrypt.len() + 16];
                encrypt_buf[..data_to_encrypt.len()].copy_from_slice(&data_to_encrypt);
                let nonce_v = derive_nonce(&master_nonce, current_idx as u32);
                let tag = cipher.encrypt_in_place_detached(Nonce::from_slice(&nonce_v), b"", &mut encrypt_buf[..data_to_encrypt.len()]).map_err(|_| ERROR_CRYPTO_FAILED)?;
                encrypt_buf[data_to_encrypt.len()..].copy_from_slice(&tag);
                let mut c_len = encrypt_buf.len() as u32;
                if is_compressed { c_len |= COMPRESSED_FLAG; }
                send.write_all(&(current_idx as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                send.write_all(&c_len.to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                send.write_all(&encrypt_buf).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                let newly_sent = total_sent.fetch_add(bytes_to_read as u64, Ordering::SeqCst) + bytes_to_read as u64;
                if progress_callback != 0 {
                    let cb: ProgressCallback = unsafe { std::mem::transmute(progress_callback) };
                    unsafe { cb(newly_sent as i64, file_size, user_data as *mut c_void); }
                }
                if throttle_ms > 0 { tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await; }
            }
            send.finish().map_err(|_| ERROR_TRANSFER_FAILED)?; Ok(())
        });
        workers.push(worker);
    }
    for worker in workers { worker.await.map_err(|_| ERROR_QUIC_ERROR)??; }
    if hash_output != 0 {
        let h = shared_hasher.lock().unwrap();
        let result = h.clone().finalize();
        unsafe { slice::from_raw_parts_mut(hash_output as *mut u8, 32).copy_from_slice(&result); }
    }
    Ok(())
}

pub async fn open_session_fd_v2(
    udp_fd: isize, 
    remote_addr: SocketAddr,
    _ticket: Option<Vec<u8>>,
    expected_peer_id: Option<String>,
) -> Result<(u32, Option<Vec<u8>>), i32> {
    let socket = unsafe {
        #[cfg(unix)] { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)] { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };
    let client_cfg = cert::make_client_config(expected_peer_id);
    let endpoint = Endpoint::new(Default::default(), None, socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;
    let conn = endpoint.connect_with(client_cfg, remote_addr, "localhost").map_err(|_| ERROR_QUIC_ERROR)?.await.map_err(|_| ERROR_QUIC_ERROR)?;
    let (data_tx, data_rx) = mpsc::unbounded_channel();
    let id = session::NEXT_SESSION_ID.fetch_add(1, Ordering::SeqCst);
    let session = session::Session {
        connections: vec![conn.clone()],
        data_rx: Arc::new(tokio::sync::Mutex::new(data_rx)),
    };
    session::SESSIONS.write().unwrap().insert(id, session);
    
    crate::system::runtime::RUNTIME.spawn(session::session_dispatcher(conn, data_tx, id));
    Ok((id, None))
}

pub async fn session_send_message(session_id: u32, message: String) -> Result<(), i32> {
    let conns = { session::SESSIONS.read().unwrap().get(&session_id).ok_or(ERROR_INVALID_FD)?.connections.clone() };
    if conns.is_empty() { return Err(ERROR_SESSION_CLOSED); }
    let (mut send, _) = conns[0].open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;
    let bytes = message.into_bytes();
    send.write_all(&0u32.to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send.write_all(&(bytes.len() as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send.write_all(&bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let _ = send.finish(); Ok(())
}

pub async fn run_quic_transfer_session(
    session_id: u32,
    header_json: String,
    file_path: String,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: usize,
    throttle_ms: i32,
    cancel_flag: usize,
    progress_callback: usize,
    _consent_callback: usize,
    user_data: usize,
    _tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
    delta_map: Option<FileMap>,
    _local_priv_key: Option<&[u8]>,
    _expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let conns = { session::SESSIONS.read().unwrap().get(&session_id).ok_or(ERROR_INVALID_FD)?.connections.clone() };
    if conns.is_empty() { return Err(ERROR_SESSION_CLOSED); }

    let (mut send_ctrl, _) = conns[0].open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;
    send_ctrl.write_all(&1u32.to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let h_bytes = header_json.into_bytes();
    send_ctrl.write_all(&(h_bytes.len() as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send_ctrl.write_all(&h_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let _ = send_ctrl.finish();

    let mut master_nonce_bytes = [0u8; 12];
    rand::thread_rng().fill(&mut master_nonce_bytes);
    let tid = transfer_id.unwrap_or_else(|| "00000000-0000-0000-0000-000000000000".to_string());
    let shared_next_chunk = Arc::new(std::sync::atomic::AtomicUsize::new((start_offset as usize) / BLOCK_SIZE));
    let shared_total_sent = Arc::new(std::sync::atomic::AtomicU64::new(start_offset as u64));
    let shared_hasher = Arc::new(std::sync::Mutex::new(Sha256::new()));
    let atomic_cancel = if cancel_flag != 0 { Some(unsafe { Arc::new(&*(cancel_flag as *const AtomicI32)) }) } else { None };
    let delta_map = Arc::new(delta_map);
    let key_arc = Arc::new(key.to_vec());
    let file_path_arc = Arc::new(file_path);
    let f_path = file_path_arc.clone();

    let mut workers = Vec::new();
    for i in 0..PARALLEL_STREAMS {
        let conn = conns[i % conns.len()].clone();
        let tid = tid.clone();
        let master_nonce = master_nonce_bytes;
        let next_chunk = shared_next_chunk.clone();
        let total_sent = shared_total_sent.clone();
        let hasher = shared_hasher.clone();
        let cancel = atomic_cancel.clone();
        let d_map = delta_map.clone();
        let key = key_arc.clone();
        let f_path = f_path.clone();

        let worker = crate::system::runtime::RUNTIME.spawn(async move {
            let mut send = conn.open_uni().await.map_err(|_| ERROR_QUIC_ERROR)?;
            send.write_all(&(tid.as_bytes().len() as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            send.write_all(tid.as_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            send.write_all(&master_nonce).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| ERROR_CRYPTO_FAILED)?;
            let mut file = File::open(&*f_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
            loop {
                if let Some(ref c) = cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
                let health = crate::system::INTELLIGENCE.read().unwrap().get_health();
                if health != crate::system::SystemHealth::Optimal {
                    tokio::time::sleep(std::time::Duration::from_millis(50)).await;
                }
                let current_idx = next_chunk.fetch_add(1, Ordering::SeqCst);
                let offset = (current_idx as u64) * (BLOCK_SIZE as u64);
                if offset >= file_size as u64 { break; }
                if let Some(ref map) = *d_map { if current_idx < map.block_hashes.len() { total_sent.fetch_add(BLOCK_SIZE as u64, Ordering::SeqCst); continue; } }
                let bytes_to_read = std::cmp::min(BLOCK_SIZE as u64, file_size as u64 - offset) as usize;
                let mut plaintext = vec![0u8; bytes_to_read];
                file.seek(std::io::SeekFrom::Start(offset)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                file.read_exact(&mut plaintext).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                { let mut h = hasher.lock().unwrap(); h.update(&plaintext); }
                let mut is_compressed = false;
                let mut data_to_encrypt = plaintext;
                if is_compressible(&*f_path) {
                    if let Ok(compressed) = zstd::encode_all(&data_to_encrypt[..], 3) {
                        if compressed.len() < data_to_encrypt.len() { data_to_encrypt = compressed; is_compressed = true; }
                    }
                }
                let mut encrypt_buf = vec![0u8; data_to_encrypt.len() + 16];
                encrypt_buf[..data_to_encrypt.len()].copy_from_slice(&data_to_encrypt);
                let nonce_v = derive_nonce(&master_nonce, current_idx as u32);
                let tag = cipher.encrypt_in_place_detached(Nonce::from_slice(&nonce_v), b"", &mut encrypt_buf[..data_to_encrypt.len()]).map_err(|_| ERROR_CRYPTO_FAILED)?;
                encrypt_buf[data_to_encrypt.len()..].copy_from_slice(&tag);
                let mut c_len = encrypt_buf.len() as u32;
                if is_compressed { c_len |= COMPRESSED_FLAG; }
                send.write_all(&(current_idx as u32).to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                send.write_all(&c_len.to_be_bytes()).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                send.write_all(&encrypt_buf).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                let newly_sent = total_sent.fetch_add(bytes_to_read as u64, Ordering::SeqCst) + bytes_to_read as u64;
                if progress_callback != 0 {
                    let cb: ProgressCallback = unsafe { std::mem::transmute(progress_callback) };
                    unsafe { cb(newly_sent as i64, file_size, user_data as *mut c_void); }
                }
                if throttle_ms > 0 { tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await; }
            }
            send.finish().map_err(|_| ERROR_TRANSFER_FAILED)?; Ok(())
        });
        workers.push(worker);
    }
    for worker in workers { worker.await.map_err(|_| ERROR_QUIC_ERROR)??; }
    if hash_output != 0 {
        let h = shared_hasher.lock().unwrap();
        let result = h.clone().finalize();
        unsafe { slice::from_raw_parts_mut(hash_output as *mut u8, 32).copy_from_slice(&result); }
    }
    Ok(())
}
