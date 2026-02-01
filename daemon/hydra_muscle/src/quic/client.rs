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

#[cfg(unix)]
use std::os::unix::io::FromRawFd;
#[cfg(windows)]
use std::os::windows::io::FromRawSocket;

pub async fn run_quic_transfer(
    target_addr: String,
    file_path: String,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
    _tracker: Option<Arc<crate::transfer::TransferTracker>>,
    _transfer_id: Option<String>,
) -> Result<(), i32> {
    let addr: SocketAddr = target_addr.parse().map_err(|_| ERROR_QUIC_ERROR)?;
    let client_cfg = cert::make_client_config(None);
    let mut endpoint = Endpoint::client("0.0.0.0:0".parse().unwrap()).map_err(|_| ERROR_QUIC_ERROR)?;
    endpoint.set_default_client_config(client_cfg);

    let conn = endpoint.connect(addr, "localhost")
        .map_err(|_| ERROR_QUIC_ERROR)?
        .await
        .map_err(|_| ERROR_QUIC_ERROR)?;

    let (mut send, _) = conn.open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;

    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();
    let mut rng = rand::thread_rng();
    let mut nonce_bytes = [0u8; 12];
    rng.fill(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    send.write_all(&nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    let mut file = File::open(file_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    if start_offset > 0 {
        file.seek(std::io::SeekFrom::Start(start_offset as u64)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    }

    let mut buffer = vec![0u8; 4 + 1024 * 1024 + 16];
    let mut total_sent = start_offset;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while total_sent < file_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_read = std::cmp::min(1024 * 1024, file_size - total_sent) as usize;
        let read_len = file.read(&mut buffer[4..4 + bytes_to_read]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        if read_len == 0 { break; }

        hasher.update(&buffer[4..4 + read_len]);
        let tag = cipher.encrypt_in_place_detached(nonce, b"", &mut buffer[4..4 + read_len]).map_err(|_| ERROR_CRYPTO_FAILED)?;
        buffer[4 + read_len..4 + read_len + 16].copy_from_slice(&tag);
        let ciphertext_len = (read_len + 16) as u32;

        buffer[0..4].copy_from_slice(&ciphertext_len.to_be_bytes());
        send.write_all(&buffer[..4 + ciphertext_len as usize]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        total_sent += read_len as i64;
        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = callback {
            unsafe { cb(total_sent, file_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    let _ = send.finish();
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
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
    expected_peer_id: Option<String>,
) -> Result<(), i32> {
    let socket = unsafe {
        #[cfg(unix)]
        { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)]
        { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };

    let client_cfg = cert::make_client_config(expected_peer_id);
    let endpoint = Endpoint::new(Default::default(), None, socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;
    
    let conn = endpoint.connect_with(client_cfg, remote_addr, "localhost")
        .map_err(|_| ERROR_QUIC_ERROR)?
        .await
        .map_err(|_| ERROR_QUIC_ERROR)?;

    let (mut send, _) = conn.open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;

    let h_bytes = header_json.into_bytes();
    let h_len_bytes = (h_bytes.len() as u32).to_be_bytes();
    send.write_all(&h_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send.write_all(&h_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();
    let mut rng = rand::thread_rng();
    let mut nonce_bytes = [0u8; 12];
    rng.fill(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    send.write_all(&nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    let mut file = File::open(file_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    if start_offset > 0 {
        file.seek(std::io::SeekFrom::Start(start_offset as u64)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    }

    let mut buffer = vec![0u8; 4 + 1024 * 1024 + 16];
    let mut total_sent = start_offset;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while total_sent < file_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_read = std::cmp::min(1024 * 1024, file_size - total_sent) as usize;
        let read_len = file.read(&mut buffer[4..4 + bytes_to_read]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        if read_len == 0 { break; }

        hasher.update(&buffer[4..4 + read_len]);
        let tag = cipher.encrypt_in_place_detached(nonce, b"", &mut buffer[4..4 + read_len]).map_err(|_| ERROR_CRYPTO_FAILED)?;
        buffer[4 + read_len..4 + read_len + 16].copy_from_slice(&tag);
        let ciphertext_len = (read_len + 16) as u32;

        buffer[0..4].copy_from_slice(&ciphertext_len.to_be_bytes());
        send.write_all(&buffer[..4 + ciphertext_len as usize]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        total_sent += read_len as i64;
        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = callback {
            unsafe { cb(total_sent, file_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    let _ = send.finish();
    Ok(())
}

pub async fn open_session_fd_v2(
    udp_fd: isize, 
    remote_addr: SocketAddr,
    _ticket: Option<Vec<u8>>,
    expected_peer_id: Option<String>,
) -> Result<(u32, Option<Vec<u8>>), i32> {
    let socket = unsafe {
        #[cfg(unix)]
        { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)]
        { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };

    let client_cfg = cert::make_client_config(expected_peer_id);

    let endpoint = Endpoint::new(Default::default(), None, socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;
    
    let connecting = endpoint.connect_with(client_cfg, remote_addr, "localhost")
        .map_err(|_| ERROR_QUIC_ERROR)?;

    let conn = match connecting.into_0rtt() {
        Ok((conn, _)) => conn,
        Err(connecting) => connecting.await.map_err(|_| ERROR_QUIC_ERROR)?,
    };

    let _ = conn.handshake_data();

    let (tx, rx) = mpsc::unbounded_channel();
    let id = session::NEXT_SESSION_ID.fetch_add(1, Ordering::SeqCst);
    
    let session_conn = conn.clone();
    tokio::spawn(session::session_dispatcher(session_conn, tx, id));

    let ticket_out: Option<Vec<u8>> = None;

    session::SESSIONS.write().unwrap().insert(id, session::Session { 
        connection: conn,
        data_rx: Arc::new(tokio::sync::Mutex::new(rx)),
    });
    Ok((id, ticket_out))
}

pub async fn session_send_message(session_id: u32, message: String) -> Result<(), i32> {
    let conn = {
        let guard = session::SESSIONS.read().unwrap();
        guard.get(&session_id).ok_or(ERROR_INVALID_FD)?.connection.clone()
    };
    
    let (mut send, _) = conn.open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;
    let type_bytes_ctrl = 0u32.to_be_bytes(); 
    
    let bytes = message.into_bytes();
    let len_bytes = (bytes.len() as u32).to_be_bytes();
    
    send.write_all(&type_bytes_ctrl).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send.write_all(&len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send.write_all(&bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let _ = send.finish();
    Ok(())
}

pub async fn run_quic_transfer_session(
    session_id: u32,
    header_json: String,
    file_path: String,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
    _tracker: Option<Arc<crate::transfer::TransferTracker>>,
    _transfer_id: Option<String>,
) -> Result<(), i32> {
    let conn = {
        let guard = session::SESSIONS.read().unwrap();
        guard.get(&session_id).ok_or(ERROR_INVALID_FD)?.connection.clone()
    };
    
    let (mut send, _) = conn.open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;
    let type_bytes_data = 1u32.to_be_bytes();
    send.write_all(&type_bytes_data).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    
    let h_bytes = header_json.into_bytes();
    let h_len_bytes = (h_bytes.len() as u32).to_be_bytes();
    send.write_all(&h_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    send.write_all(&h_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();
    let mut rng = rand::thread_rng();
    let mut nonce_bytes = [0u8; 12];
    rng.fill(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    send.write_all(&nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    let mut file = File::open(file_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    if start_offset > 0 {
        file.seek(std::io::SeekFrom::Start(start_offset as u64)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    }

    let mut buffer = vec![0u8; 4 + 1024 * 1024 + 16];
    let mut total_sent = start_offset;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while total_sent < file_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_read = std::cmp::min(1024 * 1024, file_size - total_sent) as usize;
        let read_len = file.read(&mut buffer[4..4 + bytes_to_read]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        if read_len == 0 { break; }

        hasher.update(&buffer[4..4 + read_len]);
        let tag = cipher.encrypt_in_place_detached(nonce, b"", &mut buffer[4..4 + read_len]).map_err(|_| ERROR_CRYPTO_FAILED)?;
        buffer[4 + read_len..4 + read_len + 16].copy_from_slice(&tag);
        let ciphertext_len = (read_len + 16) as u32;

        buffer[0..4].copy_from_slice(&ciphertext_len.to_be_bytes());
        send.write_all(&buffer[..4 + ciphertext_len as usize]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        total_sent += read_len as i64;
        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = callback {
            unsafe { cb(total_sent, file_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    let _ = send.finish();
    Ok(())
}
