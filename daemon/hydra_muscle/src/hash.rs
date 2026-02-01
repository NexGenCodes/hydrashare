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

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::ffi::CString;

    #[test]
    fn test_calculate_file_hash() {
        // Create a temporary file with known content
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_hash.txt");
        let mut file = File::create(&file_path).unwrap();
        file.write_all(b"hello world").unwrap();

        // SHA-256 of "hello world"
        let expected_hash = hex::decode("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9").unwrap();

        let path_c_str = CString::new(file_path.to_str().unwrap()).unwrap();
        let mut hash_output = vec![0u8; 32];

        unsafe {
            let result = calculate_file_hash_internal(
                path_c_str.as_ptr(),
                hash_output.as_mut_ptr(),
                hash_output.len(),
            );
            assert_eq!(result, SUCCESS);
        }

        assert_eq!(hash_output, expected_hash);

        // Cleanup
        std::fs::remove_file(file_path).ok();
    }
    
    #[test]
    fn test_hash_invalid_file() {
         let path_c_str = CString::new("non_existent_file_12345.txt").unwrap();
         let mut hash_output = vec![0u8; 32];
         
         unsafe {
            let result = calculate_file_hash_internal(
                path_c_str.as_ptr(),
                hash_output.as_mut_ptr(),
                hash_output.len(),
            );
            assert_eq!(result, ERROR_FILE_NOT_FOUND);
        }
    }
}
