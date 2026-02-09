use std::sync::Arc;
use std::ffi::c_void;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicI32, Ordering};
use std::slice;
use quinn::Endpoint;
use aes_gcm::{aead::{AeadInPlace, KeyInit}, Aes256Gcm, Nonce};
use sha2::{Sha256, Digest};
use tokio::fs::OpenOptions;
use tokio::io::{AsyncWriteExt, AsyncSeekExt, SeekFrom};
use tokio::sync::mpsc;
use std::ffi::CString;

use crate::common::*;
use crate::quic::{ProgressCallback, ConsentCallback, cert, session};
use crate::transfer::delta::{FileMap, BLOCK_SIZE};

#[cfg(windows)]
use std::os::windows::io::FromRawSocket;
#[cfg(unix)]
use std::os::unix::io::FromRawFd;

const COMPRESSED_FLAG: u32 = 0x8000_0000;
const LEN_MASK: u32 = !COMPRESSED_FLAG;

fn derive_nonce(master: &[u8; 12], index: u32) -> [u8; 12] {
    let mut nonce = [0u8; 12];
    nonce.copy_from_slice(master);
    let idx_bytes = index.to_be_bytes();
    for i in 0..4 { nonce[8 + i] ^= idx_bytes[i]; }
    nonce
}

pub async fn run_quic_receive(
    listen_addr: String,
    dest_path: String,
    expected_size: i64,
    _start_offset: i64,
    key: &[u8],
    hash_output: usize,
    _throttle_ms: i32,
    cancel_flag: usize,
    progress_callback: usize,
    _consent_callback: usize,
    user_data: usize,
    tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
    _delta_map: Option<FileMap>,
    _local_priv_key: Option<&[u8]>,
    _expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let addr: SocketAddr = listen_addr.parse().map_err(|_| ERROR_QUIC_ERROR)?;
    let endpoint = Endpoint::server(cert::make_hydra_server_config(None), addr).map_err(|_| ERROR_QUIC_ERROR)?;
    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;

    let part_path = format!("{}.part", dest_path);
    let file = Arc::new(tokio::sync::Mutex::new(OpenOptions::new().write(true).create(true).open(&part_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?));
    let shared_total_received = Arc::new(std::sync::atomic::AtomicU64::new(0));
    let shared_hasher = Arc::new(std::sync::Mutex::new(Sha256::new()));
    let atomic_cancel = if cancel_flag != 0 { Some(unsafe { Arc::new(&*(cancel_flag as *const AtomicI32)) }) } else { None };
    let key_arc = Arc::new(key.to_vec());
    let mut stream_tasks = Vec::new();

    while expected_size == 0 || shared_total_received.load(Ordering::SeqCst) < expected_size as u64 {
        if let Some(ref c) = atomic_cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
        let mut recv = match conn.accept_uni().await { Ok(s) => s, Err(_) => break };
        let file = file.clone();
        let total_received = shared_total_received.clone();
        let hasher = shared_hasher.clone();
        let key = key_arc.clone();
        let cancel = atomic_cancel.clone();
        let tracker = tracker.clone();
        let tid_expected = transfer_id.clone();

        let task = crate::system::runtime::RUNTIME.spawn(async move {
            let mut tid_len_bytes = [0u8; 4];
            recv.read_exact(&mut tid_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let tid_len = u32::from_be_bytes(tid_len_bytes) as usize;
            let mut tid_bytes = vec![0u8; tid_len];
            recv.read_exact(&mut tid_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let tid = String::from_utf8_lossy(&tid_bytes).to_string();
            if let Some(expected) = tid_expected { if tid != expected { return Err(ERROR_TRANSFER_FAILED); } }
            let mut master_nonce = [0u8; 12];
            recv.read_exact(&mut master_nonce).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| ERROR_CRYPTO_FAILED)?;
            let mut buffer = vec![0u8; 8 + BLOCK_SIZE + 16];
            loop {
                if let Some(ref c) = cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
                let mut h_bytes = [0u8; 8];
                if let Err(_) = recv.read_exact(&mut h_bytes).await { break; }
                let chunk_idx = u32::from_be_bytes([h_bytes[0], h_bytes[1], h_bytes[2], h_bytes[3]]);
                let h_len_f = u32::from_be_bytes([h_bytes[4], h_bytes[5], h_bytes[6], h_bytes[7]]);
                let is_comp = (h_len_f & COMPRESSED_FLAG) != 0;
                let c_len = (h_len_f & LEN_MASK) as usize;
                if c_len > buffer.len() { return Err(ERROR_TRANSFER_FAILED); }
                recv.read_exact(&mut buffer[..c_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                let ct_len = c_len - 16;
                let (data, tag_slice) = buffer.split_at_mut(ct_len);
                let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_slice[..16]);
                let nonce_v = derive_nonce(&master_nonce, chunk_idx);
                cipher.decrypt_in_place_detached(Nonce::from_slice(&nonce_v), b"", data, tag).map_err(|_| ERROR_CRYPTO_FAILED)?;
                let mut pt = &data[..ct_len];
                let d_buf;
                if is_comp { d_buf = zstd::decode_all(pt).map_err(|_| ERROR_TRANSFER_FAILED)?; pt = &d_buf; }
                { let mut f = file.lock().await; f.seek(SeekFrom::Start((chunk_idx as u64) * (BLOCK_SIZE as u64))).await.map_err(|_| ERROR_TRANSFER_FAILED)?; f.write_all(pt).await.map_err(|_| ERROR_TRANSFER_FAILED)?; }
                if let Ok(mut h) = hasher.lock() { h.update(pt); } 
                let newly_rec = total_received.fetch_add(pt.len() as u64, Ordering::SeqCst) + pt.len() as u64;
                if progress_callback != 0 {
                    let cb: ProgressCallback = unsafe { std::mem::transmute(progress_callback) };
                    unsafe { cb(newly_rec as i64, expected_size, user_data as *mut c_void); }
                }
                if let Some(t) = &tracker { t.report_progress(&tid, newly_rec).await; }
            }
            Ok(())
        });
        stream_tasks.push(task);
    }
    for t in stream_tasks { let _ = t.await; }
    if hash_output != 0 {
        if let Ok(h) = shared_hasher.lock() {
            let result = h.clone().finalize();
            unsafe { slice::from_raw_parts_mut(hash_output as *mut u8, 32).copy_from_slice(&result); }
        }
    }
    drop(file); tokio::fs::rename(part_path, dest_path).await.map_err(|_| ERROR_TRANSFER_FAILED)?; Ok(())
}

pub async fn run_quic_receive_fd(
    udp_fd: isize,
    dest_path: String,
    expected_size: i64,
    _start_offset: i64,
    key: &[u8],
    hash_output: usize,
    _throttle_ms: i32,
    cancel_flag: usize,
    progress_callback: usize,
    consent_callback: usize,
    user_data: usize,
    tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
    _delta_map: Option<FileMap>,
    local_priv_key: Option<&[u8]>,
    _expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let socket = unsafe {
        #[cfg(unix)] { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)] { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };
    let endpoint = Endpoint::new(Default::default(), Some(cert::make_hydra_server_config(local_priv_key)), socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;
    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;

    let (_, mut recv_ctrl) = conn.accept_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;
    let mut h_len_bytes = [0u8; 4];
    recv_ctrl.read_exact(&mut h_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let h_len = u32::from_be_bytes(h_len_bytes) as usize;
    let mut h_bytes = vec![0u8; h_len];
    recv_ctrl.read_exact(&mut h_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    if consent_callback != 0 {
        let cb: ConsentCallback = unsafe { std::mem::transmute(consent_callback) };
        let h_cstr = CString::new(h_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;
        if unsafe { cb(h_cstr.as_ptr(), user_data as *mut c_void) } != SUCCESS { return Err(ERROR_CANCELLED); }
    }

    let part_path = format!("{}.part", dest_path);
    let file = Arc::new(tokio::sync::Mutex::new(OpenOptions::new().write(true).create(true).open(&part_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?));
    let shared_total_received = Arc::new(std::sync::atomic::AtomicU64::new(0));
    let shared_hasher = Arc::new(std::sync::Mutex::new(Sha256::new()));
    let atomic_cancel = if cancel_flag != 0 { Some(unsafe { Arc::new(&*(cancel_flag as *const AtomicI32)) }) } else { None };
    let key_arc = Arc::new(key.to_vec());
    let mut stream_tasks = Vec::new();

    while expected_size == 0 || shared_total_received.load(Ordering::SeqCst) < expected_size as u64 {
        if let Some(ref c) = atomic_cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
        let mut recv = match conn.accept_uni().await { Ok(s) => s, Err(_) => break };
        let file = file.clone();
        let total_received = shared_total_received.clone();
        let hasher = shared_hasher.clone();
        let key = key_arc.clone();
        let cancel = atomic_cancel.clone();
        let tracker = tracker.clone();
        let tid_expected = transfer_id.clone();

        let task = crate::system::runtime::RUNTIME.spawn(async move {
            let mut tid_len_bytes = [0u8; 4];
            recv.read_exact(&mut tid_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let tid_len = u32::from_be_bytes(tid_len_bytes) as usize;
            let mut tid_bytes = vec![0u8; tid_len];
            recv.read_exact(&mut tid_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let tid = String::from_utf8_lossy(&tid_bytes).to_string();
            if let Some(expected) = tid_expected { if tid != expected { return Err(ERROR_TRANSFER_FAILED); } }
            let mut master_nonce = [0u8; 12];
            recv.read_exact(&mut master_nonce).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| ERROR_CRYPTO_FAILED)?;
            let mut buffer = vec![0u8; 8 + BLOCK_SIZE + 16];
            loop {
                if let Some(ref c) = cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
                let mut h_bytes = [0u8; 8];
                if let Err(_) = recv.read_exact(&mut h_bytes).await { break; }
                let chunk_idx = u32::from_be_bytes([h_bytes[0], h_bytes[1], h_bytes[2], h_bytes[3]]);
                let h_len_f = u32::from_be_bytes([h_bytes[4], h_bytes[5], h_bytes[6], h_bytes[7]]);
                let is_comp = (h_len_f & COMPRESSED_FLAG) != 0;
                let c_len = (h_len_f & LEN_MASK) as usize;
                if c_len > buffer.len() { return Err(ERROR_TRANSFER_FAILED); }
                recv.read_exact(&mut buffer[..c_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                let ct_len = c_len - 16;
                let (data, tag_slice) = buffer.split_at_mut(ct_len);
                let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_slice[..16]);
                let nonce_v = derive_nonce(&master_nonce, chunk_idx);
                cipher.decrypt_in_place_detached(Nonce::from_slice(&nonce_v), b"", data, tag).map_err(|_| ERROR_CRYPTO_FAILED)?;
                let mut pt = &data[..ct_len];
                let d_buf;
                if is_comp { d_buf = zstd::decode_all(pt).map_err(|_| ERROR_TRANSFER_FAILED)?; pt = &d_buf; }
                { let mut f = file.lock().await; f.seek(SeekFrom::Start((chunk_idx as u64) * (BLOCK_SIZE as u64))).await.map_err(|_| ERROR_TRANSFER_FAILED)?; f.write_all(pt).await.map_err(|_| ERROR_TRANSFER_FAILED)?; }
                if let Ok(mut h) = hasher.lock() { h.update(pt); } 
                let newly_rec = total_received.fetch_add(pt.len() as u64, Ordering::SeqCst) + pt.len() as u64;
                if progress_callback != 0 {
                    let cb: ProgressCallback = unsafe { std::mem::transmute(progress_callback) };
                    unsafe { cb(newly_rec as i64, expected_size, user_data as *mut c_void); }
                }
                if let Some(t) = &tracker { t.report_progress(&tid, newly_rec).await; }
            }
            Ok(())
        });
        stream_tasks.push(task);
    }
    for t in stream_tasks { let _ = t.await; }
    if hash_output != 0 {
        if let Ok(h) = shared_hasher.lock() {
            let result = h.clone().finalize();
            unsafe { slice::from_raw_parts_mut(hash_output as *mut u8, 32).copy_from_slice(&result); }
        }
    }
    drop(file); tokio::fs::rename(part_path, dest_path).await.map_err(|_| ERROR_TRANSFER_FAILED)?; Ok(())
}

pub async fn accept_session_fd(udp_fd: isize, local_priv_key: Option<&[u8]>) -> Result<(u32, SocketAddr), i32> {
    let socket = unsafe {
        #[cfg(unix)] { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)] { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };
    let endpoint = Endpoint::new(Default::default(), Some(cert::make_hydra_server_config(local_priv_key)), socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;
    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;
    let id = session::NEXT_SESSION_ID.fetch_add(1, Ordering::SeqCst);
    let (tx, rx) = mpsc::unbounded_channel();
    crate::system::runtime::RUNTIME.spawn(session::session_dispatcher(conn.clone(), tx, id));
    let addr = conn.remote_address();
    if let Ok(mut sessions) = session::SESSIONS.write() {
        sessions.insert(id, session::Session { 
            connections: vec![conn], 
            data_rx: Arc::new(tokio::sync::Mutex::new(rx)) 
        });
    }
    Ok((id, addr))
}

pub async fn run_quic_receive_session(
    session_id: u32,
    dest_path: String,
    expected_size: i64,
    _start_offset: i64,
    key: &[u8],
    hash_output: usize,
    _throttle_ms: i32,
    cancel_flag: usize,
    progress_callback: usize,
    consent_callback: usize,
    user_data: usize,
    tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
    _delta_map: Option<FileMap>,
    _local_priv_key: Option<&[u8]>,
    _expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let rx_queue = { 
        let sessions = session::SESSIONS.read().map_err(|_| ERROR_INVALID_FD)?;
        sessions.get(&session_id).ok_or(ERROR_INVALID_FD)?.data_rx.clone() 
    };
    let mut locked_rx = rx_queue.lock().await;
    let (_, mut recv_ctrl) = locked_rx.recv().await.ok_or(ERROR_TRANSFER_FAILED)?;
    drop(locked_rx);
    let mut h_len_bytes = [0u8; 4];
    recv_ctrl.read_exact(&mut h_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let h_len = u32::from_be_bytes(h_len_bytes) as usize;
    let mut h_bytes = vec![0u8; h_len];
    recv_ctrl.read_exact(&mut h_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    if consent_callback != 0 {
        let cb: ConsentCallback = unsafe { std::mem::transmute(consent_callback) };
        let h_cstr = CString::new(h_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;
        if unsafe { cb(h_cstr.as_ptr(), user_data as *mut c_void) } != SUCCESS { return Err(ERROR_CANCELLED); }
    }

    let part_path = format!("{}.part", dest_path);
    let file = Arc::new(tokio::sync::Mutex::new(OpenOptions::new().write(true).create(true).open(&part_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?));
    let shared_total_received = Arc::new(std::sync::atomic::AtomicU64::new(0));
    let shared_hasher = Arc::new(std::sync::Mutex::new(Sha256::new()));
    let atomic_cancel = if cancel_flag != 0 { Some(unsafe { Arc::new(&*(cancel_flag as *const AtomicI32)) }) } else { None };
    let key_arc = Arc::new(key.to_vec());
    let mut stream_tasks = Vec::new();

    while expected_size == 0 || shared_total_received.load(Ordering::SeqCst) < expected_size as u64 {
        if let Some(ref c) = atomic_cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
        let mut rx_guard = rx_queue.lock().await;
        let mut recv = match rx_guard.recv().await { Some((_, s)) => s, None => break };
        drop(rx_guard);
        let file = file.clone();
        let total_received = shared_total_received.clone();
        let hasher = shared_hasher.clone();
        let key = key_arc.clone();
        let cancel = atomic_cancel.clone();
        let tracker = tracker.clone();
        let tid_expected = transfer_id.clone();
        let task = crate::system::runtime::RUNTIME.spawn(async move {
            let mut tid_len_bytes = [0u8; 4];
            recv.read_exact(&mut tid_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let tid_len = u32::from_be_bytes(tid_len_bytes) as usize;
            let mut tid_bytes = vec![0u8; tid_len];
            recv.read_exact(&mut tid_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let tid = String::from_utf8_lossy(&tid_bytes).to_string();
            if let Some(expected) = tid_expected { if tid != expected { return Err(ERROR_TRANSFER_FAILED); } }
            let mut master_nonce = [0u8; 12];
            recv.read_exact(&mut master_nonce).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
            let cipher = Aes256Gcm::new_from_slice(&key).map_err(|_| ERROR_CRYPTO_FAILED)?;
            let mut buffer = vec![0u8; 8 + BLOCK_SIZE + 16];
            loop {
                if let Some(ref c) = cancel { if c.load(Ordering::Relaxed) != 0 { return Err(ERROR_CANCELLED); } }
                let mut h_bytes = [0u8; 8];
                if let Err(_) = recv.read_exact(&mut h_bytes).await { break; }
                let chunk_idx = u32::from_be_bytes([h_bytes[0], h_bytes[1], h_bytes[2], h_bytes[3]]);
                let h_len_f = u32::from_be_bytes([h_bytes[4], h_bytes[5], h_bytes[6], h_bytes[7]]);
                let is_comp = (h_len_f & COMPRESSED_FLAG) != 0;
                let c_len = (h_len_f & LEN_MASK) as usize;
                if c_len > buffer.len() { return Err(ERROR_TRANSFER_FAILED); }
                recv.read_exact(&mut buffer[..c_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
                let ct_len = c_len - 16;
                let (data, tag_slice) = buffer.split_at_mut(ct_len);
                let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_slice[..16]);
                let nonce_v = derive_nonce(&master_nonce, chunk_idx);
                cipher.decrypt_in_place_detached(Nonce::from_slice(&nonce_v), b"", data, tag).map_err(|_| ERROR_CRYPTO_FAILED)?;
                let mut pt = &data[..ct_len];
                let d_buf;
                if is_comp { d_buf = zstd::decode_all(pt).map_err(|_| ERROR_TRANSFER_FAILED)?; pt = &d_buf; }
                { let mut f = file.lock().await; f.seek(SeekFrom::Start((chunk_idx as u64) * (BLOCK_SIZE as u64))).await.map_err(|_| ERROR_TRANSFER_FAILED)?; f.write_all(pt).await.map_err(|_| ERROR_TRANSFER_FAILED)?; }
                if let Ok(mut h) = hasher.lock() { h.update(pt); } 
                let newly_rec = total_received.fetch_add(pt.len() as u64, Ordering::SeqCst) + pt.len() as u64;
                if progress_callback != 0 {
                    let cb: ProgressCallback = unsafe { std::mem::transmute(progress_callback) };
                    unsafe { cb(newly_rec as i64, expected_size, user_data as *mut c_void); }
                }
                if let Some(t) = &tracker { t.report_progress(&tid, newly_rec).await; }
            }
            Ok(())
        });
        stream_tasks.push(task);
    }
    for t in stream_tasks { let _ = t.await; }
    if hash_output != 0 {
        if let Ok(h) = shared_hasher.lock() {
            let result = h.clone().finalize();
            unsafe { slice::from_raw_parts_mut(hash_output as *mut u8, 32).copy_from_slice(&result); }
        }
    }
    drop(file); tokio::fs::rename(part_path, dest_path).await.map_err(|_| ERROR_TRANSFER_FAILED)?; Ok(())
}
