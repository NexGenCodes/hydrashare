use serde::{Serialize, Deserialize};
use tracing::{info, error};
use std::time::Duration;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SignalingPayload {
    pub peer_id: String,
    pub public_addr: String,
    pub local_ips: Vec<String>,
    pub bt_addr: Option<u64>,
    pub spake_msg: Option<String>,
    pub timestamp: u64,
    pub signature: Option<String>,
}

pub struct SignalingClient {
    relay_url: String,
    client: reqwest::Client,
}

impl SignalingClient {
    pub fn new(relay_url: &str) -> Self {
        Self {
            relay_url: relay_url.to_string(),
            client: reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .build()
                .unwrap(),
        }
    }

    /// Post local info to the relay under a specific PIN mailbox
    pub async fn announce(&self, pin: &str, payload: SignalingPayload) -> anyhow::Result<()> {
        let url = format!("{}/mailbox/{}", self.relay_url, pin);
        let res = self.client.post(&url)
            .json(&payload)
            .send()
            .await?;

        if res.status().is_success() {
            info!("📡 Announced to relay mailbox {}", pin);
            Ok(())
        } else {
            error!("❌ Failed to announce: {}", res.status());
            anyhow::bail!("Relay error: {}", res.status())
        }
    }

    /// Poll the mailbox for other peers
    pub async fn poll(&self, pin: &str, my_peer_id: &str) -> anyhow::Result<Vec<SignalingPayload>> {
        let url = format!("{}/mailbox/{}", self.relay_url, pin);
        let res = self.client.get(&url).send().await?;

        if res.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(vec![]);
        }

        let payloads: Vec<SignalingPayload> = res.json().await?;

        // Filter out my own payload
        let others: Vec<_> = payloads.into_iter()
            .filter(|p| p.peer_id != my_peer_id)
            .collect();

        Ok(others)
    }
}
