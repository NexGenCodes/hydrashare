pub mod common;
pub mod system;
pub mod hash;
pub mod tcp;
pub mod quic;
pub mod auth;
pub mod db;
pub mod core;
pub mod discovery;
pub mod mesh;
pub mod transfer;
pub mod transport;
pub mod ffi;

use std::ffi::{c_void, CStr};
use std::os::raw::c_char;
use std::slice;

pub use common::*;
pub use quic::{ProgressCallback, ConsentCallback, MessageCallback};

/// FFI function for sending JSON commands from Flutter
/// This provides compatibility while we migrate to binary rkyv format
#[no_mangle]
pub unsafe extern "C" fn send_command_json(json_ptr: *const c_char) -> i32 {
    if json_ptr.is_null() {
        return -1;
    }
    
    let result = std::panic::catch_unwind(|| {
        let json_str = match CStr::from_ptr(json_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        };
        
        match serde_json::from_str::<ffi::DaemonCommand>(json_str) {
            Ok(cmd) => ffi::handle_command(cmd),
            Err(e) => {
                eprintln!("❌ JSON FFI: Failed to deserialize command: {}", e);
                -2
            }
        }
    });

    match result {
        Ok(res) => res,
        Err(e) => {
            let msg = if let Some(s) = e.downcast_ref::<&str>() { s.to_string() }
            else if let Some(s) = e.downcast_ref::<String>() { s.clone() }
            else { "Unknown panic".to_string() };
            eprintln!("❌ JSON FFI Panicked: {}", msg);
            -5
        }
    }
}

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
    if source_fd <= 0 || dest_fd <= 0 || file_size <= 0 || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let key_slice = slice::from_raw_parts(key_ptr, key_len);
    let result = tcp::transfer_data_encrypted(source_fd, dest_fd, file_size, start_offset, key_slice, hash_output, throttle_ms, cancel_flag, callback, user_data);
    match result { Ok(_) => SUCCESS, Err(code) => code }
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
    if source_fd <= 0 || dest_fd <= 0 || expected_size <= 0 || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let key_slice = slice::from_raw_parts(key_ptr, key_len);
    let result = tcp::receive_data_encrypted(source_fd, dest_fd, expected_size, key_slice, hash_output, throttle_ms, cancel_flag, callback, user_data);
    match result { Ok(_) => SUCCESS, Err(code) => code }
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
    if target_addr_ptr.is_null() || file_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let target_addr = CStr::from_ptr(target_addr_ptr).to_string_lossy().into_owned();
    let file_path = CStr::from_ptr(file_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::run_quic_transfer(target_addr, file_path, file_size, start_offset, &key, hash_output as usize, throttle_ms, cancel_flag as usize, callback.map(|f| f as usize).unwrap_or(0), 0, user_data as usize, None, None, None, None, None).await {
                Ok(_) => SUCCESS, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

/// FFI-safe QUIC transfer function using existing FD
#[no_mangle]
pub unsafe extern "C" fn transfer_data_quic_fd(
    udp_fd: isize,
    remote_addr_ptr: *const std::os::raw::c_char,
    header_json_ptr: *const std::os::raw::c_char,
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
    peer_id_ptr: *const std::os::raw::c_char,
) -> i32 {
    use std::ffi::CStr;
    use std::net::SocketAddr;
    if remote_addr_ptr.is_null() || header_json_ptr.is_null() || file_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let remote_addr: SocketAddr = CStr::from_ptr(remote_addr_ptr).to_string_lossy().parse().unwrap_or("0.0.0.0:0".parse().unwrap());
    let header_json = CStr::from_ptr(header_json_ptr).to_string_lossy().into_owned();
    let file_path = CStr::from_ptr(file_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    let expected_peer_id = if !peer_id_ptr.is_null() { Some(CStr::from_ptr(peer_id_ptr).to_string_lossy().into_owned()) } else { None };
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::run_quic_transfer_fd(udp_fd, remote_addr, header_json, file_path, file_size, start_offset, &key, hash_output as usize, throttle_ms, cancel_flag as usize, callback.map(|f| f as usize).unwrap_or(0), 0, user_data as usize, None, None, None, None, expected_peer_id).await {
                Ok(_) => SUCCESS, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
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
    if listen_addr_ptr.is_null() || dest_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let listen_addr = CStr::from_ptr(listen_addr_ptr).to_string_lossy().into_owned();
    let dest_path = CStr::from_ptr(dest_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::run_quic_receive(listen_addr, dest_path, expected_size, 0, &key, hash_output as usize, throttle_ms, cancel_flag as usize, callback.map(|f| f as usize).unwrap_or(0), 0, user_data as usize, None, None, None, None, None).await {
                Ok(_) => SUCCESS, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

/// FFI-safe QUIC receive function using existing FD
#[no_mangle]
pub unsafe extern "C" fn receive_data_quic_fd(
    udp_fd: isize,
    dest_path_ptr: *const std::os::raw::c_char,
    expected_size: i64,
    key_ptr: *const u8,
    key_len: usize,
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    progress_callback: Option<ProgressCallback>,
    consent_callback: Option<ConsentCallback>,
    user_data: *mut c_void,
    priv_key_ptr: *const u8,
    priv_key_len: usize,
) -> i32 {
    use std::ffi::CStr;
    if dest_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let dest_path = CStr::from_ptr(dest_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    let local_priv_key = if !priv_key_ptr.is_null() && priv_key_len > 0 { Some(slice::from_raw_parts(priv_key_ptr, priv_key_len)) } else { None };
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::run_quic_receive_fd(udp_fd, dest_path, expected_size, 0, &key, hash_output as usize, throttle_ms, cancel_flag as usize, progress_callback.map(|f| f as usize).unwrap_or(0), consent_callback.map(|f| f as usize).unwrap_or(0), user_data as usize, None, None, None, local_priv_key, None).await {
                Ok(_) => SUCCESS, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

/// Calculate SHA-256 hash of a file
#[no_mangle]
pub unsafe extern "C" fn calculate_file_hash(
    file_path: *const std::os::raw::c_char,
    hash_output: *mut u8,
    _hash_len: usize,
) -> i32 {
    let result = std::panic::catch_unwind(|| {
        hash::calculate_file_hash_internal(file_path, hash_output, 32)
    });
    match result {
        Ok(res) => res,
        Err(_) => -5,
    }
}

#[no_mangle]
pub unsafe extern "C" fn open_quic_session_v2(
    udp_fd: isize,
    remote_addr_ptr: *const std::os::raw::c_char,
    ticket_ptr: *const u8,
    ticket_len: usize,
    _ticket_out_ptr: *mut u8,
    _ticket_out_len_ptr: *mut usize,
    peer_id_ptr: *const std::os::raw::c_char,
) -> i32 {
    use std::ffi::CStr;
    use std::net::SocketAddr;
    if remote_addr_ptr.is_null() { return ERROR_INVALID_FD; }
    let remote_addr: SocketAddr = CStr::from_ptr(remote_addr_ptr).to_string_lossy().parse().unwrap_or("0.0.0.0:0".parse().unwrap());
    let ticket = if !ticket_ptr.is_null() && ticket_len > 0 { Some(slice::from_raw_parts(ticket_ptr, ticket_len).to_vec()) } else { None };
    let expected_peer_id = if !peer_id_ptr.is_null() { Some(CStr::from_ptr(peer_id_ptr).to_string_lossy().into_owned()) } else { None };
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async { match quic::open_session_fd_v2(udp_fd, remote_addr, ticket, expected_peer_id).await { Ok((id, _)) => id as i32, Err(e) => e } })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

#[no_mangle]
pub unsafe extern "C" fn accept_quic_session_v2(
    udp_fd: isize,
    remote_addr_ptr: *mut std::os::raw::c_char,
    addr_len: usize,
    priv_key_ptr: *const u8,
    priv_key_len: usize,
) -> i32 {
    let local_priv_key = if !priv_key_ptr.is_null() && priv_key_len > 0 { Some(slice::from_raw_parts(priv_key_ptr, priv_key_len)) } else { None };
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::accept_session_fd(udp_fd, local_priv_key).await {
                Ok((id, addr)) => {
                    if !remote_addr_ptr.is_null() {
                        let c_str = std::ffi::CString::new(addr.to_string()).unwrap();
                        let bytes = c_str.as_bytes_with_nul();
                        std::ptr::copy_nonoverlapping(bytes.as_ptr(), remote_addr_ptr as *mut u8, std::cmp::min(bytes.len(), addr_len));
                    }
                    id as i32
                }, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

#[no_mangle]
pub unsafe extern "C" fn register_quic_message_callback(session_id: i32, callback: MessageCallback, user_data: *mut c_void) {
    quic::register_session_callback(session_id as u32, callback, user_data);
}

#[no_mangle]
pub unsafe extern "C" fn send_quic_message(session_id: i32, message_ptr: *const std::os::raw::c_char) -> i32 {
    use std::ffi::CStr;
    if message_ptr.is_null() { return ERROR_INVALID_FD; }
    let message = CStr::from_ptr(message_ptr).to_string_lossy().into_owned();
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async { match quic::session_send_message(session_id as u32, message).await { Ok(_) => SUCCESS, Err(e) => e } })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

#[no_mangle]
pub unsafe extern "C" fn transfer_data_quic_session(
    session_id: i32,
    header_json_ptr: *const std::os::raw::c_char,
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
    if header_json_ptr.is_null() || file_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let header_json = CStr::from_ptr(header_json_ptr).to_string_lossy().into_owned();
    let file_path = CStr::from_ptr(file_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::run_quic_transfer_session(session_id as u32, header_json, file_path, file_size, start_offset, &key, hash_output as usize, throttle_ms, cancel_flag as usize, callback.map(|f| f as usize).unwrap_or(0), 0, user_data as usize, None, None, None, None, None).await {
                Ok(_) => SUCCESS, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

#[no_mangle]
pub unsafe extern "C" fn receive_data_quic_session(
    session_id: i32,
    dest_path_ptr: *const std::os::raw::c_char,
    expected_size: i64,
    key_ptr: *const u8,
    key_len: usize,
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    progress_callback: Option<ProgressCallback>,
    consent_callback: Option<ConsentCallback>,
    user_data: *mut c_void,
) -> i32 {
    use std::ffi::CStr;
    if dest_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 { return ERROR_INVALID_FD; }
    let dest_path = CStr::from_ptr(dest_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    
    let result = std::panic::catch_unwind(|| {
        crate::system::runtime::RUNTIME.block_on(async {
            match quic::run_quic_receive_session(session_id as u32, dest_path, expected_size, 0, &key, hash_output as usize, throttle_ms, cancel_flag as usize, progress_callback.map(|f| f as usize).unwrap_or(0), consent_callback.map(|f| f as usize).unwrap_or(0), user_data as usize, None, None, None, None, None).await {
                Ok(_) => SUCCESS, Err(e) => e
            }
        })
    });
    match result { Ok(res) => res, Err(_) => -5 }
}

#[no_mangle]
pub unsafe extern "C" fn close_quic_session(session_id: i32) {
    quic::close_session(session_id as u32);
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_error_codes() { assert_eq!(SUCCESS, 0); assert!(ERROR_INVALID_FD < 0); }
}
