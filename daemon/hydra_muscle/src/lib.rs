pub mod common;
pub mod hash;
pub mod tcp;
pub mod quic;
pub mod auth;
pub mod db;
pub mod core;
pub mod discovery;
pub mod mesh;
pub mod transfer;
pub mod ffi;

use std::ffi::c_void;
use std::slice;
use tokio::runtime::Runtime;

pub use common::*;
pub use quic::{ProgressCallback, ConsentCallback, MessageCallback};

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
        match quic::run_quic_transfer(target_addr, file_path, file_size, start_offset, &key, hash_output, throttle_ms, cancel_flag, callback, user_data, None, None).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
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
    
    if remote_addr_ptr.is_null() || header_json_ptr.is_null() || file_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let remote_addr_str = CStr::from_ptr(remote_addr_ptr).to_string_lossy();
    let remote_addr: SocketAddr = match remote_addr_str.parse() {
        Ok(a) => a,
        Err(_) => return ERROR_QUIC_ERROR,
    };
    let header_json = CStr::from_ptr(header_json_ptr).to_string_lossy().into_owned();
    let file_path = CStr::from_ptr(file_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    let expected_peer_id = if !peer_id_ptr.is_null() {
        Some(CStr::from_ptr(peer_id_ptr).to_string_lossy().into_owned())
    } else {
        None
    };

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::run_quic_transfer_fd(udp_fd, remote_addr, header_json, file_path, file_size, start_offset, &key, hash_output, throttle_ms, cancel_flag, callback, user_data, expected_peer_id).await {
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
        match quic::run_quic_receive(listen_addr, dest_path, expected_size, &key, hash_output, throttle_ms, cancel_flag, callback, user_data, None, None).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
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

    if dest_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let dest_path = CStr::from_ptr(dest_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();
    let local_priv_key = if !priv_key_ptr.is_null() && priv_key_len > 0 {
        Some(slice::from_raw_parts(priv_key_ptr, priv_key_len))
    } else {
        None
    };

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::run_quic_receive_fd(udp_fd, dest_path, expected_size, &key, hash_output, throttle_ms, cancel_flag, progress_callback, consent_callback, user_data, local_priv_key).await {
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

#[no_mangle]
pub unsafe extern "C" fn open_quic_session_v2(
    udp_fd: isize,
    remote_addr_ptr: *const std::os::raw::c_char,
    ticket_ptr: *const u8,
    ticket_len: usize,
    ticket_out_ptr: *mut u8,
    ticket_out_len_ptr: *mut usize,
    peer_id_ptr: *const std::os::raw::c_char,
) -> i32 {
    use std::ffi::CStr;
    use std::net::SocketAddr;

    if remote_addr_ptr.is_null() { return ERROR_INVALID_FD; }
    let remote_addr_str = CStr::from_ptr(remote_addr_ptr).to_string_lossy();
    let remote_addr: SocketAddr = match remote_addr_str.parse() {
        Ok(a) => a,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    let ticket = if !ticket_ptr.is_null() && ticket_len > 0 {
        Some(slice::from_raw_parts(ticket_ptr, ticket_len).to_vec())
    } else {
        None
    };

    let expected_peer_id = if !peer_id_ptr.is_null() {
        Some(CStr::from_ptr(peer_id_ptr).to_string_lossy().into_owned())
    } else {
        None
    };

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::open_session_fd_v2(udp_fd, remote_addr, ticket, expected_peer_id).await {
            Ok((id, ticket_out)) => {
                if let Some(t) = ticket_out {
                    if !ticket_out_ptr.is_null() && !ticket_out_len_ptr.is_null() {
                        let max_len = *ticket_out_len_ptr;
                        let copy_len = std::cmp::min(t.len(), max_len);
                        std::ptr::copy_nonoverlapping(t.as_ptr(), ticket_out_ptr, copy_len);
                        *ticket_out_len_ptr = t.len();
                    }
                } else if !ticket_out_len_ptr.is_null() {
                    *ticket_out_len_ptr = 0;
                }
                id as i32
            },
            Err(e) => e,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn accept_quic_session_v2(
    udp_fd: isize,
    remote_addr_ptr: *mut std::os::raw::c_char,
    addr_len: usize,
    priv_key_ptr: *const u8,
    priv_key_len: usize,
) -> i32 {
    let local_priv_key = if !priv_key_ptr.is_null() && priv_key_len > 0 {
        Some(slice::from_raw_parts(priv_key_ptr, priv_key_len))
    } else {
        None
    };

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::accept_session_fd(udp_fd, local_priv_key).await {
            Ok((id, addr)) => {
                if !remote_addr_ptr.is_null() {
                    let addr_str = addr.to_string();
                    let c_str = std::ffi::CString::new(addr_str).unwrap();
                    let bytes = c_str.as_bytes_with_nul();
                    let copy_len = std::cmp::min(bytes.len(), addr_len);
                    std::ptr::copy_nonoverlapping(bytes.as_ptr(), remote_addr_ptr as *mut u8, copy_len);
                }
                id as i32
            },
            Err(e) => e,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn register_quic_message_callback(
    session_id: i32,
    callback: MessageCallback,
    user_data: *mut c_void,
) {
    quic::register_session_callback(session_id as u32, callback, user_data);
}

#[no_mangle]
pub unsafe extern "C" fn send_quic_message(
    session_id: i32,
    message_ptr: *const std::os::raw::c_char,
) -> i32 {
    use std::ffi::CStr;
    if message_ptr.is_null() { return ERROR_INVALID_FD; }
    let message = CStr::from_ptr(message_ptr).to_string_lossy().into_owned();

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::session_send_message(session_id as u32, message).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
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
    if header_json_ptr.is_null() || file_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let header_json = CStr::from_ptr(header_json_ptr).to_string_lossy().into_owned();
    let file_path = CStr::from_ptr(file_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::run_quic_transfer_session(session_id as u32, header_json, file_path, file_size, start_offset, &key, hash_output, throttle_ms, cancel_flag, callback, user_data, None, None).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
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
    if dest_path_ptr.is_null() || key_ptr.is_null() || key_len != 32 {
        return ERROR_INVALID_FD;
    }

    let dest_path = CStr::from_ptr(dest_path_ptr).to_string_lossy().into_owned();
    let key = slice::from_raw_parts(key_ptr, key_len).to_vec();

    let rt = match Runtime::new() {
        Ok(r) => r,
        Err(_) => return ERROR_QUIC_ERROR,
    };

    rt.block_on(async {
        match quic::run_quic_receive_session(session_id as u32, dest_path, expected_size, &key, hash_output, throttle_ms, cancel_flag, progress_callback, consent_callback, user_data, None, None).await {
            Ok(_) => SUCCESS,
            Err(e) => e,
        }
    })
}

#[no_mangle]
pub unsafe extern "C" fn close_quic_session(session_id: i32) {
    quic::close_session(session_id as u32);
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
