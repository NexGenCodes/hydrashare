use rand::{Rng, thread_rng};
use sha2::{Sha256, Digest};
use base64::{Engine as _, engine::general_purpose::STANDARD};

pub struct PinPairing;

impl PinPairing {
    pub fn generate_pin() -> String {
        let mut rng = thread_rng();
        let pin: u32 = rng.gen_range(100000..999999);
        pin.to_string()
    }

    pub fn hash_pin(pin: &str, salt: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(pin.as_bytes());
        hasher.update(salt.as_bytes());
        STANDARD.encode(hasher.finalize())
    }

    pub fn verify_pin(pin: &str, salt: &str, expected_hash: &str) -> bool {
        let hash = Self::hash_pin(pin, salt);
        hash == expected_hash
    }
}
