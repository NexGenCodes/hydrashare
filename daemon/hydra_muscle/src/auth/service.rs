use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use crate::discovery::pairing::PinPairing;
use crate::db::Database;
use tracing::info;
use rand::{Rng, thread_rng};
use sha2::Sha256;
use hmac::{Hmac, Mac};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD, engine::general_purpose::STANDARD};
use spake2::{Ed25519Group, Spake2, Password, Identity};

type HmacSha256 = Hmac<Sha256>;

#[derive(serde::Serialize, serde::Deserialize, Debug)]
pub struct QrHandshakePayload {
    pub id: String,
    pub key: String,
    pub addrs: Vec<String>,
    pub port: u16,
}

pub struct AuthService {
    _db: Arc<Database>,
    active_pins: Mutex<HashMap<String, String>>, // PIN -> SessionKey (Derived)
    active_spake: Mutex<HashMap<String, Spake2<Ed25519Group>>>, // PIN -> Handshake state
    pin_salts: Mutex<HashMap<String, String>>,   // PIN -> Salt
    token_secret: Mutex<Vec<u8>>,
}

impl AuthService {
    pub fn new(db: Arc<Database>) -> Self {
        let secret = match db.get_config("auth_token_secret") {
            Ok(Some(s)) => STANDARD.decode(s).unwrap_or_else(|_| vec![0u8; 32]),
            _ => {
                let mut s = vec![0u8; 32];
                thread_rng().fill(&mut s[..]);
                let _ = db.set_config("auth_token_secret", &STANDARD.encode(&s));
                s
            }
        };

        Self {
            _db: db,
            active_pins: Mutex::new(HashMap::new()),
            active_spake: Mutex::new(HashMap::new()),
            pin_salts: Mutex::new(HashMap::new()),
            token_secret: Mutex::new(secret),
        }
    }

    pub fn generate_credentials(&self) -> (String, String) {
        let pin = self.generate_pin();
        
        // Use SPAKE2 for Zero-Knowledge Key Exchange
        // A is the generator (Verifier), B is the joiner (Prover)
        let (state, msg_a_bytes) = Spake2::<Ed25519Group>::start_a(
            &Password::new(pin.as_bytes()),
            &Identity::new(b"hydra_verifier"),
            &Identity::new(b"hydra_prover")
        );
        
        let msg_a_b64 = STANDARD.encode(&msg_a_bytes);

        let mut spake_states = self.active_spake.lock().unwrap();
        let mut salts = self.pin_salts.lock().unwrap();
        
        spake_states.insert(pin.clone(), state);
        salts.insert(pin.clone(), msg_a_b64.clone()); // We use msg_a as the "salt/challenge"
        
        info!("🔑 Generated ZK-PAKE credentials. PIN: {}", pin);
        (pin, msg_a_b64)
    }

    pub fn generate_pin(&self) -> String {
        PinPairing::generate_pin()
    }

    pub fn verify_spake_msg(&self, _remote_ip: &str, pin: &str, msg_b_b64: &str) -> Option<String> {
        let mut spake_states = self.active_spake.lock().unwrap();
        let mut pins = self.active_pins.lock().unwrap();
        let mut salts = self.pin_salts.lock().unwrap();
        
        if let Some(state) = spake_states.remove(pin) {
            salts.remove(pin);
            let msg_b_bytes = STANDARD.decode(msg_b_b64).ok()?;
            
            if let Ok(shared_key) = state.finish(&msg_b_bytes) {
                let session_key = STANDARD.encode(shared_key);
                pins.insert(pin.to_string(), session_key.clone());
                return Some(session_key);
            }
        }
        None
    }

    pub fn handle_prover_spake(&self, pin: &str, msg_a_b64: &str) -> Option<(String, String)> {
        let msg_a_bytes = STANDARD.decode(msg_a_b64).ok()?;
        
        let (state, msg_b_bytes) = Spake2::<Ed25519Group>::start_b(
            &Password::new(pin.as_bytes()),
            &Identity::new(b"hydra_verifier"),
            &Identity::new(b"hydra_prover")
        );
        
        if let Ok(shared_key) = state.finish(&msg_a_bytes) {
            let session_key = STANDARD.encode(shared_key);
            let msg_b_b64 = STANDARD.encode(&msg_b_bytes);
            
            let mut pins = self.active_pins.lock().unwrap();
            pins.insert(pin.to_string(), session_key.clone());
            
            return Some((msg_b_b64, session_key));
        }
        None
    }

    pub fn get_pin_salt(&self, pin: &str) -> Option<String> {
        let salts = self.pin_salts.lock().unwrap();
        salts.get(pin).cloned()
    }

    pub fn sign_data(&self, pin: &str, data: &str) -> Option<String> {
        let pins = self.active_pins.lock().unwrap();
        if let Some(key_b64) = pins.get(pin) {
            if let Ok(key) = STANDARD.decode(key_b64) {
                if let Ok(mut mac) = HmacSha256::new_from_slice(&key) {
                    mac.update(data.as_bytes());
                    return Some(STANDARD.encode(mac.finalize().into_bytes()));
                }
            }
        }
        None
    }

    pub fn verify_data(&self, pin: &str, data: &str, signature: &str) -> bool {
        if let Some(expected_sig) = self.sign_data(pin, data) {
            return expected_sig == signature;
        }
        false
    }

    pub fn generate_session_code(&self, hydra_id: &str, ip: &str, port: u16) -> String {
        let expires = (std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs() + 86400) as u64;

        let data = format!("{}|{}|{}|{}", hydra_id, ip, port, expires);
        
        let secret = self.token_secret.lock().unwrap();
        let mut mac = HmacSha256::new_from_slice(&secret).unwrap();
        mac.update(data.as_bytes());
        let token = URL_SAFE_NO_PAD.encode(mac.finalize().into_bytes());

        format!("hydra://{}@{}:{}?t={}&e={}", hydra_id, ip, port, token, expires)
    }

    pub fn generate_qr_payload(&self, hydra_id: &str, port: u16) -> QrHandshakePayload {
        // Generate a one-time random key for this QR session
        let mut key_bytes = [0u8; 32];
        thread_rng().fill(&mut key_bytes);
        let temp_key = STANDARD.encode(key_bytes);

        // Store this key as an "active" pairing credential (similar to PIN)
        let qr_id = format!("qr_{}", hydra_id);
        self.active_pins.lock().unwrap().insert(qr_id.clone(), temp_key.clone());

        QrHandshakePayload {
            id: hydra_id.to_string(),
            key: temp_key,
            addrs: self.get_local_ips(),
            port,
        }
    }

    pub fn get_local_ips(&self) -> Vec<String> {
        let mut ips = Vec::new();
        if let Ok(interfaces) = if_addrs::get_if_addrs() {
            for iface in interfaces {
                if !iface.is_loopback() {
                    ips.push(iface.ip().to_string());
                }
            }
        }
        ips.sort();
        ips
    }
}
