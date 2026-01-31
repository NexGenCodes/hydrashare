pub mod common;
pub mod hash;
pub mod tcp;
pub mod quic;

use std::ffi::c_void;
use std::slice;
use tokio::runtime::Runtime;

pub use common::*;

/// FFI-safe transfer function
#[no_mangle]
pub unsafe extern "C" fn transfer_data(
    source_fd: isize,
    dest_fd: isize,
    file_size: i64,
    start_offset: i64,
    key_ptr: *const u8,
    key_len: usize,
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> i32 {
    if source_fd <= 0 || dest_fd <= 0 || file_size <= 0 || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let key_slice = slice::from_raw_parts(key_ptr, key_len);

    let result = tcp::transfer_data_encrypted(
        source_fd,
        dest_fd,
        file_size,
        start_offset,
        key_slice,
        hash_output,
        throttle_ms,
        cancel_flag,
        callback,
        user_data,
    );

    match result {
        Ok(_) => SUCCESS,
        Err(code) => code,
    }
}

/// FFI-safe receive function
#[no_mangle]
pub unsafe extern "C" fn receive_data(
    source_fd: isize,
    dest_fd: isize,
    expected_size: i64,
    key_ptr: *const u8,
    key_len: usize,
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> i32 {
    if source_fd <= 0 || dest_fd <= 0 || expected_size <= 0 || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let key_slice = slice::from_raw_parts(key_ptr, key_len);

    let result = tcp::receive_data_encrypted(
        source_fd,
        dest_fd,
        expected_size,
        key_slice,
        hash_output,
        throttle_ms,
        cancel_flag,
        callback,
        user_data,
    );

    match result {
        Ok(_) => SUCCESS,
        Err(code) => code,
    }
}

/// FFI-safe QUIC transfer function
#[no_mangle]
pub unsafe extern "C" fn transfer_data_quic(
    target_addr_ptr: *const std::os::raw::c_char,
    file_path_ptr: *const std::os::raw::c_char,
    file_size: i64,
    start_offset: i64,
    key_ptr: *const u8,
    key_len: usize,
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> i32 {
    use std::ffi::CStr;
    
    if target_addr_ptr.is_null() || file_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let target_addr = CStr::from_ptr(target_addr_ptr).to_string_lossy().into_owned();
    let file_path = CStr::from_ptr(file_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::run_quic_transfer(target_addr, file_path, file_size, start_offset, &key, hash_output, throttle_ms, cancel_flag, callback, user_data).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
}

/// FFI-safe QUIC receive function
#[no_mangle]
pub unsafe extern "C" fn receive_data_quic(
    listen_addr_ptr: *const std::os::raw::c_char,
    dest_path_ptr: *const std::os::raw::c_char,
    expected_size: i64,
    key_ptr: *const u8,
    key_len: usize,
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> i32 {
    use std::ffi::CStr;

    if listen_addr_ptr.is_null() || dest_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let listen_addr = CStr::from_ptr(listen_addr_ptr).to_string_lossy().into_owned();
    let dest_path = CStr::from_ptr(dest_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::run_quic_receive(listen_addr, dest_path, expected_size, &key, hash_output, throttle_ms, cancel_flag, callback, user_data).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
}

/// Calculate SHA-256 hash of a file
#[no_mangle]
pub unsafe extern "C" fn calculate_file_hash(
    file_path: *const std::os::raw::c_char,
    hash_output: *mut u8,
    hash_len: usize,
) -> i32 {
    hash::calculate_file_hash_internal(file_path, hash_output, hash_len)
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
