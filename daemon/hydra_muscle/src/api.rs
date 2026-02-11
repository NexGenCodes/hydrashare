use flutter_rust_bridge::frb;
pub use crate::ffi::{DaemonEvent, DaemonCommand};
use crate::ffi::handle_command;
use crate::frb_generated::StreamSink;
use std::sync::Mutex;
use once_cell::sync::Lazy;

pub static EVENT_SINK: Lazy<Mutex<Option<StreamSink<DaemonEvent>>>> = Lazy::new(|| Mutex::new(None));

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Start the event stream from Rust to Flutter.
/// This will be called by Flutter to listen for any DaemonEvent.
pub fn create_event_stream(sink: StreamSink<DaemonEvent>) {
    let mut guard = EVENT_SINK.lock().unwrap();
    *guard = Some(sink);
}

/// Send a structured command to the daemon.
pub fn handle_daemon_command(cmd: DaemonCommand) -> i32 {
    handle_command(cmd)
}

/// Explicit start command for convenient FRB usage
pub fn init_daemon(data_dir: String) -> i32 {
    handle_command(DaemonCommand::Init { data_dir })
}

pub fn start_engine() -> i32 {
    handle_command(DaemonCommand::StartEngine)
}

pub fn stop_engine() {
    handle_command(DaemonCommand::StopEngine);
}

pub fn send_file(peer_id: String, file_path: String) -> i32 {
    handle_command(DaemonCommand::SendFile { peer_id, file_path })
}

pub fn accept_file(offer_id: String, peer_id: String, file_size: u64, dest_path: String) -> i32 {
    handle_command(DaemonCommand::AcceptFile { offer_id, peer_id, file_size, dest_path })
}

pub fn cancel_transfer(transfer_id: String) -> i32 {
    handle_command(DaemonCommand::CancelTransfer { transfer_id })
}

pub fn mark_messages_read(peer_id: String) -> i32 {
    handle_command(DaemonCommand::MarkMessagesRead { peer_id })
}

pub fn save_message(message: String) -> i32 {
    handle_command(DaemonCommand::SaveMessage { message })
}

pub fn get_messages(peer_id: String) -> i32 {
    handle_command(DaemonCommand::GetMessages { peer_id })
}

pub fn send_message(peer_id: String, text: String) -> i32 {
    handle_command(DaemonCommand::SendMessage { peer_id, text })
}

pub fn reject_file(offer_id: String, peer_id: String) -> i32 {
    handle_command(DaemonCommand::RejectFile { offer_id, peer_id })
}

pub fn generate_credentials() -> i32 {
    handle_command(DaemonCommand::GenerateCredentials)
}

pub fn generate_qr_payload() -> i32 {
    handle_command(DaemonCommand::GenerateQrPayload)
}

pub fn join_session(pin: String) -> i32 {
    handle_command(DaemonCommand::JoinSession { pin })
}

pub fn set_settings(key: String, text: String) -> i32 {
    handle_command(DaemonCommand::SetSettings { key, text })
}

pub fn get_settings(key: String) -> i32 {
    handle_command(DaemonCommand::GetSettings { key })
}

pub fn generate_session_code() -> i32 {
    handle_command(DaemonCommand::GenerateSessionCode)
}

pub fn join_session_code(text: String) -> i32 {
    handle_command(DaemonCommand::JoinSessionCode { text })
}

pub fn set_device_name(name: String) -> i32 {
    handle_command(DaemonCommand::SetDeviceName { name })
}

pub fn start_discovery() -> i32 {
    handle_command(DaemonCommand::StartDiscovery)
}

pub fn stop_discovery() -> i32 {
    handle_command(DaemonCommand::StopDiscovery)
}

pub fn generate_code() -> i32 {
    handle_command(DaemonCommand::GenerateCode)
}

pub fn connect_peer(peer_id: String, address: String, port: u16, encryption_key: Option<String>) -> i32 {
    handle_command(DaemonCommand::ConnectPeer { 
        peer_id, 
        address, 
        port, 
        encryption_key 
    })
}

pub fn disconnect_peer(peer_id: String) -> i32 {
    handle_command(DaemonCommand::DisconnectPeer { peer_id })
}
