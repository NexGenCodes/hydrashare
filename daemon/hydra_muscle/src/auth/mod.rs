pub mod service;

use ed25519_dalek::SigningKey;
use rand::rngs::OsRng;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use anyhow::{Result, Context};
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Clone)]
pub struct Identity {
    pub peer_id: String, // Base64 encoded public key
    #[serde(skip_serializing)]
    keypair: Option<Vec<u8>>, // Serialized signing key bytes
}

impl Identity {
    pub fn generate() -> Self {
        let mut csprng = OsRng;
        let signing_key = SigningKey::generate(&mut csprng);
        let peer_id = STANDARD.encode(signing_key.verifying_key().as_bytes());
        
        Self {
            peer_id,
            keypair: Some(signing_key.to_bytes().to_vec()),
        }
    }

    pub fn from_saved(priv_key_b64: &str) -> Result<Self> {
        let bytes = STANDARD.decode(priv_key_b64).context("Failed to decode private key")?;
        let bytes_array: [u8; 32] = bytes.try_into().map_err(|_| anyhow::anyhow!("Invalid key length"))?;
        let signing_key = SigningKey::from_bytes(&bytes_array);
        let peer_id = STANDARD.encode(signing_key.verifying_key().as_bytes());

        Ok(Self {
            peer_id,
            keypair: Some(bytes_array.to_vec()),
        })
    }
    
    pub fn get_private_key(&self) -> Option<Vec<u8>> {
        self.keypair.clone()
    }
}
