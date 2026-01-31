use aes_gcm::{
    aead::{AeadInPlace, KeyInit},
    Aes256Gcm, Nonce,
};
use rand::Rng;
use std::ffi::c_void;
use std::fs::File;
use std::io::{Read, Write};
use std::slice;
use std::sync::atomic::{AtomicI32, Ordering};
use sha2::{Sha256, Digest};
use std::time::Duration;
use std::io::{Seek, SeekFrom};
use std::mem::ManuallyDrop;

#[cfg(unix)]
use std::os::unix::io::FromRawFd;
#[cfg(windows)]
use std::os::windows::io::{FromRawHandle, FromRawSocket};

use crate::common::*;

pub unsafe fn transfer_data_encrypted(
    source_fd: isize,
    dest_fd: isize,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> Result<(), i32> {
    // 1. Setup Cipher and Hasher
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();

    // 2. Generate and Send Nonce (12 bytes)
    let mut rng = rand::thread_rng();
    let mut nonce_bytes = [0u8; 12];
    rng.fill(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    // 3. Convert FDs to Rust Streams
    #[cfg(unix)]
    let mut source_file = ManuallyDrop::new(File::from_raw_fd(source_fd as i32));
    #[cfg(unix)]
    let mut dest_stream = ManuallyDrop::new(std::net::TcpStream::from_raw_fd(dest_fd as i32));

    #[cfg(windows)]
    let mut source_file = ManuallyDrop::new(File::from_raw_handle(source_fd as *mut c_void));
    #[cfg(windows)]
    let mut dest_stream = ManuallyDrop::new(std::net::TcpStream::from_raw_socket(dest_fd as u64));

    // Set Timeouts (Protocol Hardening)
    let _ = dest_stream.set_write_timeout(Some(Duration::from_secs(10)));

    // Send Nonce
    dest_stream.write_all(&nonce_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;

    // 4. Seek if needed
    if start_offset > 0 {
        source_file.seek(SeekFrom::Start(start_offset as u64)).map_err(|_| ERROR_TRANSFER_FAILED)?;
    }

    // 5. Transfer Loop
    const CHUNK_SIZE: usize = 1024 * 1024; // 1MB
    let mut buffer = vec![0u8; CHUNK_SIZE + 16];
    let mut total_sent: i64 = start_offset;

    let atomic_cancel = if !cancel_flag.is_null() {
        Some(&*(cancel_flag as *const AtomicI32))
    } else {
        None
    };

    while total_sent < file_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_read = std::cmp::min(CHUNK_SIZE as i64, file_size - total_sent) as usize;
        let read_len = source_file
            .read(&mut buffer[..bytes_to_read])
            .map_err(|_| ERROR_TRANSFER_FAILED)?;
        
        if read_len == 0 { break; }

        // Update Hasher (Streaming Hash)
        hasher.update(&buffer[..read_len]);

        // Encrypt In-Place Detached
        let tag = cipher
            .encrypt_in_place_detached(nonce, b"", &mut buffer[..read_len])
            .map_err(|_| ERROR_CRYPTO_FAILED)?;

        // Append Tag
        buffer[read_len..read_len+16].copy_from_slice(&tag);

        let ciphertext_len = read_len + 16;

        // Send Length + Ciphertext
        let len_bytes = (ciphertext_len as u32).to_be_bytes();
        dest_stream.write_all(&len_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;
        dest_stream.write_all(&buffer[..ciphertext_len]).map_err(|_| ERROR_TRANSFER_FAILED)?;

        total_sent += read_len as i64;

        if throttle_ms > 0 {
            std::thread::sleep(std::time::Duration::from_millis(throttle_ms as u64));
        }

        if let Some(cb) = callback {
            cb(total_sent, file_size, user_data);
        }
    }

    // Finalize Hash
    if !hash_output.is_null() {
        let result = hasher.finalize();
        let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
        hash_slice.copy_from_slice(&result);
    }

    Ok(())
}

pub unsafe fn receive_data_encrypted(
    source_fd: isize,
    dest_fd: isize,
    expected_size: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> Result<(), i32> {
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();

    #[cfg(unix)]
    let mut source_stream = ManuallyDrop::new(std::net::TcpStream::from_raw_fd(source_fd as i32));
    #[cfg(unix)]
    let mut dest_file = ManuallyDrop::new(File::from_raw_fd(dest_fd as i32));

    #[cfg(windows)]
    let mut source_stream = ManuallyDrop::new(std::net::TcpStream::from_raw_socket(source_fd as u64));
    #[cfg(windows)]
    let mut dest_file = ManuallyDrop::new(File::from_raw_handle(dest_fd as *mut c_void));

    // Set Timeouts
    let _ = source_stream.set_read_timeout(Some(Duration::from_secs(10)));

    // 1. Read Nonce
    let mut nonce_bytes = [0u8; 12];
    source_stream.read_exact(&mut nonce_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    // 2. Receive Loop
    let mut total_received: i64 = 0;
    let mut buffer = vec![0u8; 1024 * 1024 + 16]; // 1MB + Tag

    let atomic_cancel = if !cancel_flag.is_null() {
        Some(&*(cancel_flag as *const AtomicI32))
    } else {
        None
    };

    while total_received < expected_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        // Read Chunk Length
        let mut len_bytes = [0u8; 4];
        if let Err(_) = source_stream.read_exact(&mut len_bytes) {
            break; // Likely EOF
        }
        let chunk_len = u32::from_be_bytes(len_bytes) as usize;

        if chunk_len > buffer.len() || chunk_len < 16 {
            return Err(ERROR_TRANSFER_FAILED);
        }

        // Read Ciphertext
        source_stream.read_exact(&mut buffer[..chunk_len]).map_err(|_| ERROR_TRANSFER_FAILED)?;

        // Decryption Logic:
        let plaintext_len = chunk_len - 16;
        let mut tag_bytes = [0u8; 16];
        tag_bytes.copy_from_slice(&buffer[plaintext_len..chunk_len]);
        let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_bytes);

        cipher
            .decrypt_in_place_detached(nonce, b"", &mut buffer[..plaintext_len], tag)
            .map_err(|_| ERROR_CRYPTO_FAILED)?;

        // Write to Disk
        dest_file.write_all(&buffer[..plaintext_len]).map_err(|_| ERROR_TRANSFER_FAILED)?;

        // Update Hasher
        hasher.update(&buffer[..plaintext_len]);

        total_received += plaintext_len as i64;

        if throttle_ms > 0 {
            std::thread::sleep(std::time::Duration::from_millis(throttle_ms as u64));
        }

        if let Some(cb) = callback {
            cb(total_received, expected_size, user_data);
        }
    }

    // Finalize Hash
    if !hash_output.is_null() {
        let result = hasher.finalize();
        let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
        hash_slice.copy_from_slice(&result);
    }

    Ok(())
}
