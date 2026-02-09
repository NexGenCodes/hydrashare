use std::sync::Arc;
use quinn::{ClientConfig, ServerConfig};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, ServerName, UnixTime};
use x509_parser::prelude::*;
use base64::Engine;

#[derive(Debug)]
pub struct HydraCertVerifier {
    expected_hydra_id: String,
}

impl HydraCertVerifier {
    pub fn new(id: String) -> Self {
        Self { expected_hydra_id: id }
    }
}

impl rustls::client::danger::ServerCertVerifier for HydraCertVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<rustls::client::danger::ServerCertVerified, rustls::Error> {
        let (_, cert) = X509Certificate::from_der(end_entity.as_ref())
            .map_err(|_| rustls::Error::InvalidCertificate(rustls::CertificateError::BadEncoding))?;
        
        let spki = cert.public_key();
        let pub_key_bytes = spki.raw;

        let actual_id = base64::engine::general_purpose::STANDARD.encode(pub_key_bytes);
        
        if actual_id == self.expected_hydra_id {
            Ok(rustls::client::danger::ServerCertVerified::assertion())
        } else {
            Err(rustls::Error::InvalidCertificate(rustls::CertificateError::BadEncoding))
        }
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> {
        Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> {
        Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> {
        vec![rustls::SignatureScheme::ED25519]
    }
}

#[derive(Debug)]
pub struct SkipServerVerification;
impl Default for SkipServerVerification {
    fn default() -> Self {
        Self::new()
    }
}

impl SkipServerVerification {
    pub fn new() -> Self { SkipServerVerification }
}
impl rustls::client::danger::ServerCertVerifier for SkipServerVerification {
    fn verify_server_cert(
        &self,
        _end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<rustls::client::danger::ServerCertVerified, rustls::Error> {
        Ok(rustls::client::danger::ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> {
        Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> {
        Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> {
        vec![
            rustls::SignatureScheme::RSA_PSS_SHA256,
            rustls::SignatureScheme::ECDSA_NISTP256_SHA256,
            rustls::SignatureScheme::ED25519,
        ]
    }
}

pub fn make_transport_config() -> quinn::TransportConfig {
    let mut config = quinn::TransportConfig::default();
    // Enable BBR congestion control (improves performance on higher latency/WAN links)
    // In Quinn 0.11 BBR is often default or readily available. 
    // We use a safe factory approach.
    config.congestion_controller_factory(Arc::new(quinn::congestion::BbrConfig::default()));
    config.max_idle_timeout(Some(std::time::Duration::from_secs(30).try_into().unwrap()));
    config.keep_alive_interval(Some(std::time::Duration::from_secs(5)));
    config.mtu_discovery_config(Some(quinn::MtuDiscoveryConfig::default()));
    config
}

pub fn make_hydra_server_config(priv_key: Option<&[u8]>) -> ServerConfig {
    let (certificate, private_key) = if let Some(pk) = priv_key {
        let seed = &pk[..32];
        let mut pkcs8 = vec![
            0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
        ];
        pkcs8.extend_from_slice(seed);

        let key_pair = rcgen::KeyPair::try_from(pkcs8.as_slice()).expect("bad private key");
        let params = rcgen::CertificateParams::new(vec!["localhost".to_string()]).unwrap();
        
        let cert = params.self_signed(&key_pair).unwrap();
        (
            CertificateDer::from(cert.der().to_vec()),
            PrivateKeyDer::try_from(pkcs8).unwrap()
        )
    } else {
        let key_pair = rcgen::KeyPair::generate_for(&rcgen::PKCS_ED25519).unwrap();
        let params = rcgen::CertificateParams::new(vec!["localhost".to_string()]).unwrap();
        let cert = params.self_signed(&key_pair).unwrap();
        (
            CertificateDer::from(cert.der().to_vec()),
            PrivateKeyDer::try_from(key_pair.serialize_der()).unwrap()
        )
    };

    let mut crypto = rustls::ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .with_no_client_auth()
        .with_single_cert(vec![certificate], private_key)
        .expect("bad certificate");
    
    crypto.alpn_protocols = vec![b"hydra-p2p".to_vec()];
    crypto.max_early_data_size = 0xffffffff;

    let mut server_config = ServerConfig::with_crypto(Arc::new(quinn::crypto::rustls::QuicServerConfig::try_from(crypto).unwrap()));
    server_config.transport_config(Arc::new(make_transport_config()));
    server_config.migration(true);
    server_config
}

pub fn make_client_config(expected_peer_id: Option<String>) -> ClientConfig {
    let verifier: Arc<dyn rustls::client::danger::ServerCertVerifier> = if let Some(peer_id) = expected_peer_id {
        Arc::new(HydraCertVerifier::new(peer_id))
    } else {
        Arc::new(SkipServerVerification::new())
    };
    
    let mut crypto = rustls::ClientConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .dangerous()
        .with_custom_certificate_verifier(verifier)
        .with_no_client_auth();
    
    crypto.alpn_protocols = vec![b"hydra-p2p".to_vec()];
    crypto.enable_early_data = true;

    let mut client_config = ClientConfig::new(Arc::new(quinn::crypto::rustls::QuicClientConfig::try_from(crypto).unwrap()));
    client_config.transport_config(Arc::new(make_transport_config()));
    client_config
}
