pub mod cert;
pub mod session;
pub mod client;
pub mod server;

use std::ffi::c_void;

pub type ProgressCallback = unsafe extern "C" fn(i64, i64, *mut c_void);
pub type ConsentCallback = unsafe extern "C" fn(*const std::os::raw::c_char, *mut c_void) -> i32;
pub type MessageCallback = unsafe extern "C" fn(*const std::os::raw::c_char, *mut c_void);

// Re-export core functions for lib.rs
pub use client::run_quic_transfer;
pub use client::run_quic_transfer_fd;
pub use client::open_session_fd_v2;
pub use client::session_send_message;
pub use client::run_quic_transfer_session;

pub use server::run_quic_receive;
pub use server::run_quic_receive_fd;
pub use server::accept_session_fd;
pub use server::run_quic_receive_session;

pub use session::register_session_callback;
pub use session::close_session;
