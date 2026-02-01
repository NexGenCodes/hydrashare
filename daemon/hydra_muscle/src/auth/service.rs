use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use crate::discovery::pairing::PinPairing;
use crate::db::Database;
use tracing::{info, warn};
use rand::{Rng, thread_rng};
use pbkdf2::pbkdf2_hmac;
use sha2::Sha256;
use hmac::{Hmac, Mac};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD, engine::general_purpose::STANDARD};

type HmacSha256 = Hmac<Sha256>;

pub struct AuthService {
    db: Arc<Database>,
    active_pins: Mutex<HashMap<String, String>>, // PIN -> SessionKey
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
            db,
            active_pins: Mutex::new(HashMap::new()),
            pin_salts: Mutex::new(HashMap::new()),
            token_secret: Mutex::new(secret),
        }
    }

    pub fn generate_credentials(&self) -> (String, String) {
        let pin = PinPairing::generate_pin();
        
        // Generate Salt
        let mut salt_bytes = [0u8; 16];
        thread_rng().fill(&mut salt_bytes);
        let salt = STANDARD.encode(salt_bytes);

        // Generate Session Key
        let mut key_bytes = [0u8; 32];
        thread_rng().fill(&mut key_bytes);
        let session_key = STANDARD.encode(key_bytes);

        let mut pins = self.active_pins.lock().unwrap();
        let mut salts = self.pin_salts.lock().unwrap();
        
        pins.insert(pin.clone(), session_key.clone());
        salts.insert(pin.clone(), salt);
        
        info!("🔑 Generated new credentials. PIN: {}", pin);
        (pin, session_key)
    }

    pub fn hash_pin(&self, pin: &str, salt: &str) -> String {
        let mut dk = [0u8; 32];
        pbkdf2_hmac::<Sha256>(pin.as_bytes(), salt.as_bytes(), 100_000, &mut dk);
        STANDARD.encode(dk)
    }

    pub fn verify_pin_proof(&self, _remote_ip: &str, proof: &str) -> Option<String> {
        let mut pins = self.active_pins.lock().unwrap();
        let mut salts = self.pin_salts.lock().unwrap();
        
        let mut pin_to_remove = None;
        for (pin, salt) in salts.iter() {
            if self.hash_pin(pin, salt) == proof {
                pin_to_remove = Some(pin.clone());
                break;
            }
        }

        if let Some(pin) = pin_to_remove {
            salts.remove(&pin);
            pins.remove(&pin)
        } else {
            None
        }
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
}
