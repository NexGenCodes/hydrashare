use aes_gcm::{
    aead::{AeadInPlace, KeyInit},
    Aes256Gcm, Nonce,
};
use rand::Rng;
use std::ffi::c_void;
use std::slice;
use std::sync::Arc;
use quinn::{Endpoint, ServerConfig, ClientConfig};
use sha2::{Sha256, Digest};
use std::sync::atomic::{AtomicI32, Ordering};
use std::net::SocketAddr;

use crate::common::*;

pub async fn run_quic_transfer(
    target_addr: String,
    file_path: String,
    file_size: i64,
    start_offset: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> Result<(), i32> {
    use tokio::fs::File;
    use tokio::io::{AsyncReadExt, AsyncWriteExt, AsyncSeekExt};

    let addr: SocketAddr = target_addr.parse().map_err(|_| ERROR_QUIC_ERROR)?;
    let client_cfg = make_client_config();
    let mut endpoint = Endpoint::client("0.0.0.0:0".parse().unwrap()).map_err(|_| ERROR_QUIC_ERROR)?;
    endpoint.set_default_client_config(client_cfg);

    let conn = endpoint.connect(addr, "localhost")
        .map_err(|_| ERROR_QUIC_ERROR)?
        .await
        .map_err(|_| ERROR_QUIC_ERROR)?;

    let (mut send, _) = conn.open_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;

    // Setup Cipher
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();
    let mut rng = rand::thread_rng();
    let mut nonce_bytes = [0u8; 12];
    rng.fill(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    // Send Nonce
    send.write_all(&nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

    // Open File
    let mut file = File::open(file_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    if start_offset > 0 {
        file.seek(std::io::SeekFrom::Start(start_offset as u64)).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    }

    let mut buffer = vec![0u8; 1024 * 1024 + 16];
    let mut total_sent = start_offset;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while total_sent < file_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let bytes_to_read = std::cmp::min(1024 * 1024, file_size - total_sent) as usize;
        let read_len = file.read(&mut buffer[..bytes_to_read]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        if read_len == 0 { break; }

        hasher.update(&buffer[..read_len]);
        let tag = cipher.encrypt_in_place_detached(nonce, b"", &mut buffer[..read_len]).map_err(|_| ERROR_CRYPTO_FAILED)?;
        buffer[read_len..read_len+16].copy_from_slice(&tag);
        let ciphertext_len = read_len + 16;

        let len_bytes = (ciphertext_len as u32).to_be_bytes();
        send.write_all(&len_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        send.write_all(&buffer[..ciphertext_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        total_sent += read_len as i64;
        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = callback {
            unsafe { cb(total_sent, file_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    send.finish().map_err(|_| ERROR_TRANSFER_FAILED)?;
    Ok(())
}

pub async fn run_quic_receive(
    listen_addr: String,
    dest_path: String,
    expected_size: i64,
    key: &[u8],
    hash_output: *mut u8,
    throttle_ms: i32,
    cancel_flag: *const i32,
    callback: Option<ProgressCallback>,
    user_data: *mut c_void,
) -> Result<(), i32> {
    use tokio::fs::File;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    let addr: SocketAddr = listen_addr.parse().map_err(|_| ERROR_QUIC_ERROR)?;
    let server_cfg = make_server_config();
    let endpoint = Endpoint::server(server_cfg, addr).map_err(|_| ERROR_QUIC_ERROR)?;

    let incoming = endpoint.accept().await.ok_or(ERROR_QUIC_ERROR)?;
    let conn = incoming.await.map_err(|_| ERROR_QUIC_ERROR)?;

    let (_, mut recv) = conn.accept_bi().await.map_err(|_| ERROR_QUIC_ERROR)?;

    // Setup Cipher
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| ERROR_CRYPTO_FAILED)?;
    let mut hasher = Sha256::new();

    let mut nonce_bytes = [0u8; 12];
    recv.read_exact(&mut nonce_bytes).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    let mut file = File::create(dest_path).await.map_err(|_| ERROR_FILE_NOT_FOUND)?;
    let mut buffer = vec![0u8; 1024 * 1024 + 16];
    let mut total_received = 0i64;
    let atomic_cancel = if !cancel_flag.is_null() {
        Some(unsafe { &*(cancel_flag as *const AtomicI32) })
    } else {
        None
    };

    while total_received < expected_size {
        if let Some(cancel) = atomic_cancel {
            if cancel.load(Ordering::Relaxed) != 0 {
                return Err(ERROR_CANCELLED);
            }
        }

        let mut len_bytes = [0u8; 4];
        if let Err(_) = recv.read_exact(&mut len_bytes).await { break; }
        let chunk_len = u32::from_be_bytes(len_bytes) as usize;

        if chunk_len > buffer.len() {
            return Err(ERROR_TRANSFER_FAILED);
        }

        recv.read_exact(&mut buffer[..chunk_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;

        let plaintext_len = chunk_len - 16;
        let mut tag_bytes = [0u8; 16];
        tag_bytes.copy_from_slice(&buffer[plaintext_len..chunk_len]);
        let tag = aes_gcm::aead::Tag::<Aes256Gcm>::from_slice(&tag_bytes);

        cipher.decrypt_in_place_detached(nonce, b"", &mut buffer[..plaintext_len], tag).map_err(|_| ERROR_CRYPTO_FAILED)?;

        file.write_all(&buffer[..plaintext_len]).await.map_err(|_| ERROR_TRANSFER_FAILED)?;
        hasher.update(&buffer[..plaintext_len]);
        total_received += plaintext_len as i64;

        if throttle_ms > 0 {
            tokio::time::sleep(std::time::Duration::from_millis(throttle_ms as u64)).await;
        }
        if let Some(cb) = callback {
            unsafe { cb(total_received, expected_size, user_data); }
        }
    }

    if !hash_output.is_null() {
        let result = hasher.finalize();
        unsafe {
            let hash_slice = slice::from_raw_parts_mut(hash_output, 32);
            hash_slice.copy_from_slice(&result);
        }
    }

    Ok(())
}

fn make_client_config() -> ClientConfig {
    use rustls::client::danger::{ServerCertVerifier, ServerCertVerified, HandshakeSignatureValid};
    use rustls::{DigitallySignedStruct, SignatureScheme};
    use rustls::pki_types::{CertificateDer, ServerName, UnixTime};

    #[derive(Debug)]
    struct NoVerifier;
    impl ServerCertVerifier for NoVerifier {
        fn verify_server_cert(&self, _end_entity: &CertificateDer<'_>, _intermediates: &[CertificateDer<'_>], _server_name: &ServerName<'_>, _ocsp_response: &[u8], _now: UnixTime) -> Result<ServerCertVerified, rustls::Error> {
            Ok(ServerCertVerified::assertion())
        }
        fn verify_tls12_signature(&self, _message: &[u8], _cert: &CertificateDer<'_>, _dss: &DigitallySignedStruct) -> Result<HandshakeSignatureValid, rustls::Error> {
            Ok(HandshakeSignatureValid::assertion())
        }
        fn verify_tls13_signature(&self, _message: &[u8], _cert: &CertificateDer<'_>, _dss: &DigitallySignedStruct) -> Result<HandshakeSignatureValid, rustls::Error> {
            Ok(HandshakeSignatureValid::assertion())
        }
        fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
            vec![SignatureScheme::RSA_PSS_SHA256, SignatureScheme::ED25519, SignatureScheme::ECDSA_NISTP256_SHA256]
        }
    }

    let mut crypto = rustls::ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(NoVerifier))
        .with_no_client_auth();
    
    crypto.alpn_protocols = vec![b"hydra-p2p".to_vec()];

    ClientConfig::new(Arc::new(quinn::crypto::rustls::QuicClientConfig::try_from(crypto).unwrap()))
}

fn make_server_config() -> ServerConfig {
    let cert = rcgen::generate_simple_self_signed(vec!["localhost".into()]).unwrap();
    let cert_der = cert.cert.der().to_vec();
    let priv_key = cert.key_pair.serialize_der();
    
    let certificate = rustls::pki_types::CertificateDer::from(cert_der);
    let private_key = rustls::pki_types::PrivateKeyDer::try_from(priv_key).unwrap();

    let mut crypto = rustls::ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .with_no_client_auth()
        .with_single_cert(vec![certificate], private_key)
        .expect("bad certificate");
    
    crypto.alpn_protocols = vec![b"hydra-p2p".to_vec()];

    ServerConfig::with_crypto(Arc::new(quinn::crypto::rustls::QuicServerConfig::try_from(crypto).unwrap()))
}
