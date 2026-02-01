use std::ffi::c_void;

pub type ProgressCallback = unsafe extern "C" fn(i64, i64, *mut c_void);

pub const SUCCESS: i32 = 0;
pub const ERROR_INVALID_FD: i32 = -1;
pub const ERROR_TRANSFER_FAILED: i32 = -2;
pub const ERROR_CANCELLED: i32 = -3;
pub const ERROR_FILE_NOT_FOUND: i32 = -4;
pub const ERROR_HASH_FAILED: i32 = -5;
pub const ERROR_CRYPTO_FAILED: i32 = -6;
pub const ERROR_NETWORK_TIMEOUT: i32 = -7;
pub const ERROR_QUIC_ERROR: i32 = -8;
pub const ERROR_SESSION_CLOSED: i32 = -9;
pub const ERROR_UNAUTHORIZED: i32 = -10;

pub fn error_to_string(code: i32) -> &'static str {
    match code {
        SUCCESS => "Success",
        ERROR_INVALID_FD => "Invalid File Descriptor / Argument",
        ERROR_TRANSFER_FAILED => "Transfer Failed",
        ERROR_CANCELLED => "Cancelled",
        ERROR_FILE_NOT_FOUND => "File Not Found",
        ERROR_HASH_FAILED => "Hash Verification Failed",
        ERROR_CRYPTO_FAILED => "Crypto / Decryption Failed",
        ERROR_NETWORK_TIMEOUT => "Network User Timeout",
        ERROR_QUIC_ERROR => "QUIC Protocol Error",
        ERROR_SESSION_CLOSED => "Session Closed",
        ERROR_UNAUTHORIZED => "Unauthorized / Pinning Failed",
        _ => "Unknown Error",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_mapping() {
        assert_eq!(error_to_string(SUCCESS), "Success");
        assert_eq!(error_to_string(ERROR_CANCELLED), "Cancelled");
        assert_eq!(error_to_string(-999), "Unknown Error");
    }
}
