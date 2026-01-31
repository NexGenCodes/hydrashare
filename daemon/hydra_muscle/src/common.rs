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
