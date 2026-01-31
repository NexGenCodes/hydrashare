use std::ffi::CStr;
use std::fs::File;
use std::io::Read;
use std::slice;
use sha2::{Sha256, Digest};
use crate::common::*;

pub unsafe fn calculate_file_hash_internal(
    file_path: *const std::os::raw::c_char,
    hash_output: *mut u8,
    hash_len: usize,
) -> i32 {
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
