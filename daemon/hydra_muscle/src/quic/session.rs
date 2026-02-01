use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use once_cell::sync::Lazy;
use std::sync::atomic::AtomicU32;
use tokio::sync::mpsc;
use quinn::Connection;
use std::ffi::c_void;
use crate::quic::MessageCallback;

pub struct Session {
    pub connection: Connection,
    pub data_rx: Arc<tokio::sync::Mutex<mpsc::UnboundedReceiver<(quinn::SendStream, quinn::RecvStream)>>>,
}

pub static SESSIONS: Lazy<RwLock<HashMap<u32, Session>>> = Lazy::new(|| RwLock::new(HashMap::new()));
pub static SESSION_CALLBACKS: Lazy<RwLock<HashMap<u32, (MessageCallback, usize)>>> = Lazy::new(|| RwLock::new(HashMap::new()));
pub static NEXT_SESSION_ID: AtomicU32 = AtomicU32::new(1);

pub fn close_session(session_id: u32) {
    if let Some(session) = SESSIONS.write().unwrap().remove(&session_id) {
        session.connection.close(0u32.into(), b"closed");
    }
    SESSION_CALLBACKS.write().unwrap().remove(&session_id);
}

pub async fn session_dispatcher(
    conn: Connection,
    data_tx: mpsc::UnboundedSender<(quinn::SendStream, quinn::RecvStream)>,
    session_id: u32,
) {
    loop {
        match conn.accept_bi().await {
            Ok((send, mut recv)) => {
                let mut type_bytes = [0u8; 4];
                if let Err(_) = recv.read_exact(&mut type_bytes).await {
                    break;
                }
                let stype = u32::from_be_bytes(type_bytes);
                if stype == 1 {
                    let _ = data_tx.send((send, recv));
                } else {
                    let mut len_bytes = [0u8; 4];
                    if let Ok(_) = recv.read_exact(&mut len_bytes).await {
                        let len = u32::from_be_bytes(len_bytes) as usize;
                        let mut buf = vec![0u8; len];
                        if let Ok(_) = recv.read_exact(&mut buf).await {
                            if let Ok(msg_str) = String::from_utf8(buf) {
                                if let Some((cb, user_data)) = SESSION_CALLBACKS.read().unwrap().get(&session_id) {
                                    let c_str = std::ffi::CString::new(msg_str).unwrap();
                                    unsafe { (cb)(c_str.as_ptr(), *user_data as *mut c_void); }
                                }
                            }
                        }
                    }
                }
            }
            Err(_) => break,
        }
    }
    close_session(session_id);
}

pub fn register_session_callback(session_id: u32, callback: MessageCallback, user_data: *mut c_void) {
    SESSION_CALLBACKS.write().unwrap().insert(session_id, (callback, user_data as usize));
}
