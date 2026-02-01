use std::sync::Arc;
use std::ffi::c_void;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicI32, Ordering};
use std::slice;
use quinn::Endpoint;
use aes_gcm::{aead::{AeadInPlace, KeyInit}, Aes256Gcm, Nonce};
use sha2::{Sha256, Digest};
use tokio::fs::File;
use tokio::io::AsyncWriteExt;
use tokio::sync::mpsc;
use std::ffi::CString;

use crate::common::*;
use crate::quic::{ProgressCallback, ConsentCallback, cert, session};

#[cfg(unix)]
use std::os::unix::io::FromRawFd;
#[cfg(windows)]
use std::os::windows::io::FromRawSocket;

pub async fn run_quic_receive(
    listen_addr: String,
    dest_path: String,
    expected_size: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
    tracker: Option<Arc<crate::transfer::TransferTracker>>,
    transfer_id: Option<String>,
) -> Result<(), i32> {
    let addr: SocketAddr = listen_addr.parse().map_err(|_| ERROR_QUIC_ERROR)?;
    let server_cfg = cert::make_hydra_server_config(None);
    let endpoint = Endpoint::server(server_cfg, addr).map_err(|_| ERROR_QUIC_ERROR)?;

    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;

    let (_, mut recv) = conn.accept_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;

    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();

    let mut nonce_bytes = [0u8; 12];
    recv.read_exact(&mut nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    let mut file = File::create(dest_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    let mut buffer = vec![0u8; 4 + 1024 * 1024 + 16];
    let mut total_received = 0i64;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while expected_size == 0 || total_received < expected_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let mut len_bytes = [0u8; 4];
        if let Err(_) = recv.read_exact(&mut len_bytes).await { break; }
        let chunk_len = u32::from_be_bytes(len_bytes) as usize;

        if chunk_len > buffer.len() {
            return Err(ERROR_TRANSFER_FAILED);
        }

        recv.read_exact(&mut buffer[..chunk_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        let plaintext_len = chunk_len - 16;
        let mut tag_bytes = [0u8; 16];
        tag_bytes.copy_from_slice(&buffer[plaintext_len..chunk_len]);
        let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_bytes);

        cipher.decrypt_in_place_detached(nonce, b"", &mut buffer[..plaintext_len], tag).map_err(|_| ERROR_CRYPTO_FAILED)?;

        file.write_all(&buffer[..plaintext_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        hasher.update(&buffer[..plaintext_len]);
        total_received += plaintext_len as i64;

        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = callback {
            unsafe { cb(total_received, expected_size, user_data); }
        }
        if let (Some(t), Some(tid)) = (&tracker, &transfer_id) {
            t.report_progress(tid, total_received as u64).await;
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    Ok(())
}

pub async fn run_quic_receive_fd(
    udp_fd: isize,
    dest_path: String,
    expected_size: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    progress_callback: Option<ProgressCallback>,
    consent_callback: Option<ConsentCallback>,
    user_data: *mut c_void,
    local_priv_key: Option<&[u8]>,
) -> Result<(), i32> {
    let socket = unsafe {
        #[cfg(unix)]
        { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)]
        { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };
    
    let server_cfg = cert::make_hydra_server_config(local_priv_key);
    let endpoint = Endpoint::new(Default::default(), Some(server_cfg), socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;

    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;

    let (_, mut recv) = conn.accept_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;

    let mut header_len_bytes = [0u8; 4];
    recv.read_exact(&mut header_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let header_len = u32::from_be_bytes(header_len_bytes) as usize;
    let mut header_bytes = vec![0u8; header_len];
    recv.read_exact(&mut header_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    if let Some(cb) = consent_callback {
        let header_cstr = CString::new(header_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;
        let decision = unsafe { cb(header_cstr.as_ptr(), user_data) };
        if decision != SUCCESS {
            return Err(ERROR_CANCELLED);
        }
    }

    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();

    let mut nonce_bytes = [0u8; 12];
    recv.read_exact(&mut nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    let mut file = File::create(dest_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    let mut buffer = vec![0u8; 4 + 1024 * 1024 + 16];
    let mut total_received = 0i64;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while expected_size == 0 || total_received < expected_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let mut len_bytes = [0u8; 4];
        if let Err(_) = recv.read_exact(&mut len_bytes).await { break; }
        let chunk_len = u32::from_be_bytes(len_bytes) as usize;

        if chunk_len > buffer.len() {
            return Err(ERROR_TRANSFER_FAILED);
        }

        recv.read_exact(&mut buffer[..chunk_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        let plaintext_len = chunk_len - 16;
        let mut tag_bytes = [0u8; 16];
        tag_bytes.copy_from_slice(&buffer[plaintext_len..chunk_len]);
        let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_bytes);

        cipher.decrypt_in_place_detached(nonce, b"", &mut buffer[..plaintext_len], tag).map_err(|_| ERROR_CRYPTO_FAILED)?;

        file.write_all(&buffer[..plaintext_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        hasher.update(&buffer[..plaintext_len]);
        total_received += plaintext_len as i64;

        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = progress_callback {
            unsafe { cb(total_received, expected_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    Ok(())
}

pub async fn accept_session_fd(udp_fd: isize, local_priv_key: Option<&[u8]>) -> Result<(u32, SocketAddr), i32> {
    let socket = unsafe {
        #[cfg(unix)]
        { std::net::UdpSocket::from_raw_fd(udp_fd as i32) }
        #[cfg(windows)]
        { std::net::UdpSocket::from_raw_socket(udp_fd as u64) }
    };

    let server_cfg = cert::make_hydra_server_config(local_priv_key);
    let endpoint = Endpoint::new(Default::default(), Some(server_cfg), socket, Arc::new(quinn::TokioRuntime)).map_err(|_| ERROR_QUIC_ERROR)?;

    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;
    let remote_addr = conn.remote_address();

    let (tx, rx) = mpsc::unbounded_channel();
    let id = session::NEXT_SESSION_ID.fetch_add(1, Ordering::SeqCst);
    
    let session_conn = conn.clone();
    tokio::spawn(session::session_dispatcher(session_conn, tx, id));

    session::SESSIONS.write().unwrap().insert(id, session::Session { 
        connection: conn,
        data_rx: Arc::new(tokio::sync::Mutex::new(rx)),
    });
    Ok((id, remote_addr))
}

pub async fn run_quic_receive_session(
    session_id: u32,
    dest_path: String,
    expected_size: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    progress_callback: Option<ProgressCallback>,
    consent_callback: Option<ConsentCallback>,
    user_data: *mut c_void,
    _tracker: Option<Arc<crate::transfer::TransferTracker>>,
    _transfer_id: Option<String>,
) -> Result<(), i32> {
    let rx_queue = {
        let guard = session::SESSIONS.read().unwrap();
        guard.get(&session_id).ok_or(ERROR_INVALID_FD)?.data_rx.clone()
    };

    let mut locked_rx = rx_queue.lock().await;
    let (_, mut recv) = locked_rx.recv().await.ok_or(ERROR_TRANSFER_FAILED)?;
    drop(locked_rx); // Release lock immediately

    let mut header_len_bytes = [0u8; 4];
    recv.read_exact(&mut header_len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let header_len = u32::from_be_bytes(header_len_bytes) as usize;
    let mut header_bytes = vec![0u8; header_len];
    recv.read_exact(&mut header_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    if let Some(cb) = consent_callback {
        let header_cstr = CString::new(header_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;
        let decision = unsafe { cb(header_cstr.as_ptr(), user_data) };
        if decision != SUCCESS {
            return Err(ERROR_CANCELLED);
        }
    }

    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();

    let mut nonce_bytes = [0u8; 12];
    recv.read_exact(&mut nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    let mut file = File::create(dest_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    let mut buffer = vec![0u8; 4 + 1024 * 1024 + 16];
    let mut total_received = 0i64;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while expected_size == 0 || total_received < expected_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let mut len_bytes = [0u8; 4];
        if let Err(_) = recv.read_exact(&mut len_bytes).await { break; }
        let chunk_len = u32::from_be_bytes(len_bytes) as usize;

        if chunk_len > buffer.len() {
            return Err(ERROR_TRANSFER_FAILED);
        }

        recv.read_exact(&mut buffer[..chunk_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        let plaintext_len = chunk_len - 16;
        let mut tag_bytes = [0u8; 16];
        tag_bytes.copy_from_slice(&buffer[plaintext_len..chunk_len]);
        let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_bytes);

        cipher.decrypt_in_place_detached(nonce, b"", &mut buffer[..plaintext_len], tag).map_err(|_| ERROR_CRYPTO_FAILED)?;

        file.write_all(&buffer[..plaintext_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        hasher.update(&buffer[..plaintext_len]);
        total_received += plaintext_len as i64;

        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = progress_callback {
            unsafe { cb(total_received, expected_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    Ok(())
}
