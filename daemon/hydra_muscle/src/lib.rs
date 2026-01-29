// No common imports needed here, they are scoped to platform-specific implementations


/// Progress callback function pointer from Go
/// Arguments: bytes_transferred, total_bytes
/// Progress callback function pointer from Go
/// Arguments: transferred, total, user_data
pub type ProgressCallback = unsafe extern "C" fn(i64, i64, *mut std::ffi::c_void);


/// Error codes returned to Go
pub const SUCCESS: i32 = 0;
pub const ERROR_INVALID_FD: i32 = -1;
pub const ERROR_TRANSFER_FAILED: i32 = -2;
pub const ERROR_CANCELLED: i32 = -3;

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
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut std::ffi::c_void,
) -> i32 {
    if source_fd <= 0 || dest_fd <= 0 || file_size <= 0 {
        return ERROR_INVALID_FD;
    }

    // Platform-specific implementation
    match transfer_data_impl(source_fd, dest_fd, file_size, cancel_flag, callback, user_data) {
        Ok(_) => SUCCESS,
        Err(code) => code,
    }
}


#[cfg(windows)]
unsafe fn transfer_data_impl(
    source_fd: isize,
    dest_fd: isize,
    file_size: i64,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut std::ffi::c_void,
) -> Result<(), i32> {

    use windows_sys::Win32::Networking::WinSock::TransmitFile;
    use windows_sys::Win32::Foundation::HANDLE;
    use std::ptr;
    use std::sync::atomic::{AtomicI32, Ordering};

    let source_handle = source_fd as HANDLE;
    let dest_socket = dest_fd as usize;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(&*(cancel_flag as *const AtomicI32))
    } else {
        None
    };

    const CHUNK_SIZE: u32 = 64 * 1024 * 1024; // 64MB chunks
    let mut total_sent: i64 = 0;
    
    while total_sent < file_size {
        // Check cancellation
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_send = std::cmp::min(CHUNK_SIZE as i64, file_size - total_sent) as u32;
        
        // Call TransmitFile
        // Note: For large files, we send in chunks to provide progress updates
        let result = TransmitFile(
            dest_socket,
            source_handle,
            bytes_to_send,
            0,
            ptr::null_mut(),
            ptr::null(),
            0,
        );
        
        if result == 0 {
            return Err(ERROR_TRANSFER_FAILED);
        }
        
        total_sent += bytes_to_send as i64;
        
        if let Some(cb) = callback {
            cb(total_sent, file_size, user_data);
        }

    }
    
    Ok(())
}

#[cfg(unix)]
unsafe fn transfer_data_impl(
    source_fd: isize,
    dest_fd: isize,
    file_size: i64,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut std::ffi::c_void,
) -> Result<(), i32> {

    use libc::{sendfile, off_t};
    use std::sync::atomic::{AtomicI32, Ordering};
    
    let mut offset: off_t = 0;
    let mut total_sent: i64 = 0;
    const CHUNK_SIZE: usize = 64 * 1024 * 1024; // 64MB chunks
    
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(&*(cancel_flag as *const AtomicI32))
    } else {
        None
    };

    while total_sent < file_size {
        // Check cancellation
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_send = std::cmp::min(CHUNK_SIZE, (file_size - total_sent) as usize);
        
        #[cfg(any(target_os = "linux", target_os = "android"))]
        let sent = sendfile(dest_fd as i32, source_fd as i32, &mut offset, bytes_to_send);
        
        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        let sent = {
            let mut len = bytes_to_send as off_t;
            let result = libc::sendfile(
                source_fd as i32,
                dest_fd as i32,
                offset,
                &mut len,
                std::ptr::null_mut(),
                0,
            );
            if result == 0 { len as isize } else { -1 }
        };
        
        if sent <= 0 {
            return Err(ERROR_TRANSFER_FAILED);
        }
        
        total_sent += sent as i64;
        
        if let Some(cb) = callback {
            cb(total_sent, file_size, user_data);
        }

    }
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_error_codes() {
        assert_eq!(SUCCESS, 0);
        assert!(ERROR_INVALID_FD < 0);
        assert!(ERROR_TRANSFER_FAILED < 0);
    }
}
