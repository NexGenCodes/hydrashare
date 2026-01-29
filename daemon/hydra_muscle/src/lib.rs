// No common imports needed here, they are scoped to platform-specific implementations
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use rand::Rng;
use std::ffi::c_void;
use std::fs::File;
use std::io::{Read, Write};
use std::slice;

#[cfg(unix)]
use std::os::unix::io::FromRawFd;
#[cfg(windows)]
use std::os::windows::io::{FromRawHandle, FromRawSocket};

/// Progress callback function pointer from Go
/// Arguments: transferred, total, user_data
pub type ProgressCallback = unsafe extern "C" fn(i64, i64, *mut c_void);

/// Error codes returned to Go
pub const SUCCESS: i32 = 0;
pub const ERROR_INVALID_FD: i32 = -1;
pub const ERROR_TRANSFER_FAILED: i32 = -2;
pub const ERROR_CANCELLED: i32 = -3;
pub const ERROR_FILE_NOT_FOUND: i32 = -4;
pub const ERROR_HASH_FAILED: i32 = -5;
pub const ERROR_CRYPTO_FAILED: i32 = -6;

/// FFI-safe transfer function
///
/// # Safety
/// This function is unsafe because it deals with raw file descriptors/handles
/// and function pointers from FFI boundary.
#[no_mangle]
pub unsafe extern "C" fn transfer_data(
    source_fd: isize,
    dest_fd: isize,
    file_size: i64,
    start_offset: i64,
    key_ptr: *const u8,
    key_len: usize,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> i32 {
    if source_fd <= 0 || dest_fd <= 0 || file_size <= 0 || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let key_slice = slice::from_raw_parts(key_ptr, key_len);

    let result = transfer_data_encrypted(
        source_fd,
        dest_fd,
        file_size,
        start_offset,
        key_slice,
        cancel_flag,
        callback,
        user_data,
    );

    match result {
        Ok(_) => SUCCESS,
        Err(code) => code,
    }
}

unsafe fn transfer_data_encrypted(
    source_fd: isize,
    dest_fd: isize,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> Result<(), i32> {
    use std::io::{BufReader, Seek, SeekFrom};
    use std::mem::ManuallyDrop;
    use std::sync::atomic::{AtomicI32, Ordering};

    // 1. Setup Cipher
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;

    // 2. Generate and Send Nonce (12 bytes)
    let mut rng = rand::thread_rng();
    let mut nonce_bytes = [0u8; 12];
    rng.fill(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    // 3. Convert FDs to Rust Streams (ManuallyDrop to prevent closing)
    #[cfg(unix)]
    let mut source_file = ManuallyDrop::new(File::from_raw_fd(source_fd as i32));
    #[cfg(unix)]
    let mut dest_stream = ManuallyDrop::new(File::from_raw_fd(dest_fd as i32)); // Using File for socket works on Unix

    #[cfg(windows)]
    let mut source_file = ManuallyDrop::new(File::from_raw_handle(source_fd as *mut c_void));
    #[cfg(windows)]
    // SOCKET on Windows is not a File handle. We use TcpStream implicitly via FromRawSocket.
    // Note: Windows SOCKET is usize/u64, casting locally.
    let mut dest_stream = ManuallyDrop::new(std::net::TcpStream::from_raw_socket(dest_fd as u64));

    // Send Nonce
    dest_stream.write_all(&nonce_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;

    // 4. Seek to start offset
    if start_offset > 0 {
        source_file.seek(SeekFrom::Start(start_offset as u64)).map_err(|_| ERROR_TRANSFER_FAILED)?;
    }

    // 5. Transfer Loop (1MB Buffer)
    const CHUNK_SIZE: usize = 1024 * 1024; // 1MB
    let mut buffer = vec![0u8; CHUNK_SIZE];
    let mut total_sent: i64 = start_offset;

    let atomic_cancel = if !cancel_flag.is_null() {
        Some(&*(cancel_flag as *const AtomicI32))
    } else {
        None
    };

    while total_sent < file_size {
        // Check Cancellation
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        // Read Chunk
        let bytes_to_read = std::cmp::min(CHUNK_SIZE as i64, file_size - total_sent) as usize;
        let read_len = source_file
            .read(&mut buffer[..bytes_to_read])
            .map_err(|_| ERROR_TRANSFER_FAILED)?;
        
        if read_len == 0 {
            break; // EOF
        }

        // Encrypt Chunk
        // Result is Vec<u8> (ciphertext + tag)
        let ciphertext = cipher
            .encrypt(nonce, &buffer[..read_len])
            .map_err(|_| ERROR_CRYPTO_FAILED)?;

        // Send Length Pre-header (4 bytes, Big Endian)
        let len_bytes = (ciphertext.len() as u32).to_be_bytes();
        dest_stream.write_all(&len_bytes).map_err(|_| ERROR_TRANSFER_FAILED)?;

        // Send Ciphertext
        dest_stream.write_all(&ciphertext).map_err(|_| ERROR_TRANSFER_FAILED)?;

        total_sent += read_len as i64;

        if let Some(cb) = callback {
            cb(total_sent, file_size, user_data);
        }
    }

    Ok(())
}

/// Calculate SHA-256 hash of a file
/// 
/// # Safety
/// This function is unsafe because it deals with raw C strings from FFI boundary.
#[no_mangle]
pub unsafe extern "C" fn calculate_file_hash(
    file_path: *const std::os::raw::c_char,
    hash_output: *mut u8,
    hash_len: usize,
) -> i32 {
    use std::ffi::CStr;
    use std::fs::File;
    use std::io::Read;
    use sha2::{Sha256, Digest};

    if file_path.is_null() || hash_output.is_null() || hash_len < 32 {
        return ERROR_INVALID_FD;
    }

    let path_str = match CStr::from_ptr(file_path).to_str() {
        Ok(s) => s,
        Err(_) => return ERROR_INVALID_FD,
    };

    let mut file = match File::open(path_str) {
        Ok(f) => f,
        Err(_) => return ERROR_FILE_NOT_FOUND,
    };

    let mut hasher = Sha256::new();
    let mut buffer = vec![0u8; 8192];
    
    loop {
        match file.read(&mut buffer) {
            Ok(0) => break, // EOF
            Ok(n) => hasher.update(&buffer[..n]),
            Err(_) => return ERROR_HASH_FAILED,
        }
    }

    let result = hasher.finalize();
    let hash_slice = slice::from_raw_parts_mut(hash_output, hash_len);
    hash_slice[..32].copy_from_slice(&result[..]);

    SUCCESS
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_error_codes() {
        assert_eq!(SUCCESS, 0);
        assert!(ERROR_INVALID_FD < 0);
    }
}
