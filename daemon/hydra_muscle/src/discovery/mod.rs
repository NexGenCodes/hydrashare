pub mod pairing;
pub mod stun;
pub mod signaling;

use mdns_sd::{ServiceDaemon, ServiceInfo};
use std::collections::HashMap;
use tracing::{info, error, warn};
use std::sync::Arc;
use crate::mesh::PeerStatus;

pub struct DiscoveryService {
    mdns: Option<ServiceDaemon>,
    service_type: String,
    local_peer_id: String,
    mesh: Arc<crate::mesh::MeshNetwork>,
    auth: Arc<crate::auth::service::AuthService>,
}

pub use crate::db::PeerInfo;

impl DiscoveryService {
    pub fn new(local_peer_id: &str, mesh: Arc<crate::mesh::MeshNetwork>, auth: Arc<crate::auth::service::AuthService>) -> Self {
        let mdns = ServiceDaemon::new().ok();
        if mdns.is_none() {
            tracing::error!("❌ Failed to create mDNS daemon. Local discovery will be disabled.");
        }
        let service_type = "_hydra._udp.local.".to_string();

        Self {
            mdns,
            service_type,
            local_peer_id: local_peer_id.to_string(),
            mesh,
            auth,
        }
    }

    pub fn start(&self, orchestrator: Arc<crate::mesh::orchestrator::Orchestrator>, port: u16) {
        let hostname = hostname::get().unwrap_or_default().to_string_lossy().to_string();
        let instance_name = format!("{}-{}", hostname, self.local_peer_id);
        
        let mut properties = HashMap::new();
        properties.insert("id".to_string(), self.local_peer_id.clone());
        properties.insert("port".to_string(), port.to_string());

        if let Some(bt_addr) = self.get_bluetooth_address() {
            properties.insert("bt".to_string(), bt_addr.to_string());
        }

        let service_info = ServiceInfo::new(
            &self.service_type,
            &instance_name,
            &hostname,
            "", // IP (let mdns-sd detect)
            port,
            Some(properties),
        ).expect("Valid service info");

        if let Some(mdns) = &self.mdns {
            let _ = mdns.register(service_info);
            info!("📢 Discovery Service started: announcing as {}", instance_name);

            if let Ok(receiver) = mdns.browse(&self.service_type) {
                let peers = self.mesh.clone();
                let orchestrator = orchestrator.clone();
                
                std::thread::spawn(move || {
                    while let Ok(event) = receiver.recv() {
                        if let mdns_sd::ServiceEvent::ServiceResolved(info) = event {
                            let properties = info.get_properties();
                            if let Some(peer_id) = properties.get("id") {
                                let peer_id = peer_id.val_str();
                                let addresses = info.get_addresses();
                                if !addresses.is_empty() {
                                    let bt_addr = properties.get("bt").and_then(|v| v.val_str().parse::<u64>().ok());
                                    
                                    let peer_info = PeerInfo {
                                        peer_id: peer_id.to_string(),
                                        name: info.get_fullname().to_string(),
                                        ips: addresses.iter().cloned().collect(),
                                        port: info.get_port(),
                                        bt_addr,
                                        shared_key: None,
                                        is_banned: false,
                                        is_muted: false,
                                    };
                                    peers.update_peer_discovery(peer_info.clone());

                                    // Proactively connect to all LAN addresses
                                    let addrs: Vec<std::net::SocketAddr> = peer_info.ips.iter()
                                        .map(|ip| std::net::SocketAddr::new(*ip, peer_info.port))
                                        .collect();
                                    
                                    orchestrator.connect_to_peer_multi(peer_info.peer_id.clone(), addrs);

                                    // Emit to UI (first IP for simple display)
                                    crate::ffi::emit_event(crate::ffi::DaemonEvent::PeerDiscovered {
                                        peer_id: peer_info.peer_id,
                                        name: peer_info.name,
                                        ip: peer_info.ips[0].to_string(),
                                        port: peer_info.port,
                                    });
                                }
                            }
                        }
                    }
                });
            }
        } else {
            warn!("⚠️ mDNS disabled - skipping local discovery announcement");
        }
    }

    pub fn start_signaling(&self, pin: &str, orchestrator: Arc<crate::mesh::orchestrator::Orchestrator>) {
        let stun = stun::StunClient::new("stun.l.google.com:19302");
        let signaling = signaling::SignalingClient::new("https://relay.hydrashare.net");
        let my_peer_id = self.local_peer_id.clone();
        let pin = pin.to_string();
        let mesh = self.mesh.clone();
        let auth = self.auth.clone();

        let bt_addr = self.get_bluetooth_address();

        crate::system::runtime::RUNTIME.spawn(async move {
            info!("🌐 Starting LDT signaling for PIN: {}", pin);
            
            // 1. Discover Public IP
            let public_addr = match stun.get_public_addr() {
                Ok(addr) => addr,
                Err(e) => {
                    error!("❌ STUN discovery failed: {}", e);
                    return;
                }
            };
            
            let mut payload = signaling::SignalingPayload {
                peer_id: my_peer_id.clone(),
                public_addr: public_addr.to_string(),
                local_ips: auth.get_local_ips(),
                bt_addr,
                spake_msg: None,
                timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
                signature: None,
            };

            // If we are the Verifier (generator), include msgA from pin_salts
            if let Some(msg_a) = auth.get_pin_salt(&pin) {
                payload.spake_msg = Some(msg_a);
            }
            
            let mut handshake_complete = false;

            // 2. Announce and Poll loop
            loop {
                // Sign payload if we have the key
                if handshake_complete && payload.signature.is_none() {
                     let local_ips_str = payload.local_ips.join(",");
                     let data = format!("{}|{}|{}|{}|{}", payload.peer_id, payload.public_addr, local_ips_str, payload.timestamp, payload.bt_addr.unwrap_or(0));
                     if let Some(sig) = auth.sign_data(&pin, &data) {
                         payload.signature = Some(sig);
                     }
                }

                // Announce our presence
                if let Err(e) = signaling.announce(&pin, payload.clone()).await {
                    error!("❌ Relay announcement failed: {}", e);
                }

                // Poll for others
                match signaling.poll(&pin, &my_peer_id).await {
                    Ok(others) => {
                        for other in others {
                            // SPAKE2 Handshake Logic
                            if !handshake_complete {
                                if let Some(other_msg) = other.spake_msg.as_ref() {
                                    if payload.spake_msg.is_none() {
                                        // We are the Prover (B), we just received msgA
                                        if let Some((msg_b, key)) = auth.handle_prover_spake(&pin, other_msg) {
                                            payload.spake_msg = Some(msg_b);
                                            handshake_complete = true;
                                            info!("🤝 SPAKE2: Handshake complete (Prover)");
                                            // Persist the key
                                            let mut peer = mesh.get_peer(&other.peer_id).unwrap_or_else(|| PeerInfo {
                                                peer_id: other.peer_id.clone(),
                                                name: format!("Remote-{}", &other.peer_id[..6]),
                                                ips: vec![],
                                                port: 0,
                                                bt_addr: other.bt_addr,
                                                shared_key: None,
                                                is_banned: false,
                                                is_muted: false,
                                            });
                                            peer.shared_key = Some(key);
                                            mesh.update_peer_discovery(peer);
                                        }
                                    } else {
                                        // We are the Verifier (A), we just received msgB
                                        if let Some(key) = auth.verify_spake_msg("n/a", &pin, other_msg) {
                                            handshake_complete = true;
                                            info!("🤝 SPAKE2: Handshake complete (Verifier)");
                                            // Persist the key
                                            let mut peer = mesh.get_peer(&other.peer_id).unwrap_or_else(|| PeerInfo {
                                                peer_id: other.peer_id.clone(),
                                                name: format!("Remote-{}", &other.peer_id[..6]),
                                                ips: vec![],
                                                port: 0,
                                                bt_addr: other.bt_addr,
                                                shared_key: None,
                                                is_banned: false,
                                                is_muted: false,
                                            });
                                            peer.shared_key = Some(key);
                                            mesh.update_peer_discovery(peer);
                                        }
                                    }
                                }
                            }

                            // 🔒 Authenticated Signaling Enforcement
                            if handshake_complete {
                                let local_ips_str = other.local_ips.join(",");
                                let msg_data = format!("{}|{}|{}|{}|{}", other.peer_id, other.public_addr, local_ips_str, other.timestamp, other.bt_addr.unwrap_or(0));
                                let valid = if let Some(sig) = &other.signature {
                                    auth.verify_data(&pin, &msg_data, sig)
                                } else {
                                    false
                                };

                                if !valid {
                                    warn!("⚠️ SECURITY: Ignoring invalid/unsigned signal from {} (Possible MITM)", other.peer_id);
                                    continue;
                                }
                            }

                            // Gather all possible addresses (Public + Local IPs)
                            let mut target_addrs = Vec::new();
                            
                            // 1. Add Public Addr
                            if let Ok(addr) = other.public_addr.parse::<std::net::SocketAddr>() {
                                target_addrs.push(addr);
                            }

                            // 2. Add Local Addrs (using same port as public addr for simplicity, or 5051 as default)
                            let port = target_addrs.first().map(|a| a.port()).unwrap_or(5051);
                            for local_ip in other.local_ips {
                                if let Ok(ip) = local_ip.parse::<std::net::IpAddr>() {
                                    target_addrs.push(std::net::SocketAddr::new(ip, port));
                                }
                            }

                            if !target_addrs.is_empty() {
                                let peer_info = PeerInfo {
                                    peer_id: other.peer_id.clone(),
                                    name: format!("Remote-{}", &other.peer_id[..6]),
                                    ips: target_addrs.iter().map(|a| a.ip()).collect(),
                                    port,
                                    bt_addr: other.bt_addr,
                                    shared_key: None,
                                    is_banned: false,
                                    is_muted: false,
                                };
                                mesh.update_peer_discovery(peer_info.clone());
                                info!("🔭 LDT: Discovered remote peer {} at {:?}", other.peer_id, target_addrs);

                                // Proactively connect only if NOT already online/paired
                                let should_connect = {
                                    let peers = mesh.peers.read().unwrap();
                                    if let Some(peer) = peers.get(&other.peer_id) {
                                        !matches!(peer.status, PeerStatus::Online | PeerStatus::Paired)
                                    } else {
                                        true
                                    }
                                };

                                if should_connect {
                                    orchestrator.connect_to_peer_multi(other.peer_id.clone(), target_addrs);
                                }

                                // Emit to UI
                                crate::ffi::emit_event(crate::ffi::DaemonEvent::PeerDiscovered {
                                    peer_id: peer_info.peer_id,
                                    name: peer_info.name,
                                    ip: peer_info.ips[0].to_string(),
                                    port: peer_info.port,
                                });
                            }
                        }
                    }
                    Err(e) => error!("❌ Relay polling failed: {}", e),
                }

                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
            }
        });
    }

    pub fn generate_ldt_code(&self, orchestrator: Arc<crate::mesh::orchestrator::Orchestrator>) -> String {
        let pin = self.auth.generate_pin();
        // Automatically start signaling for this PIN (Verifier role)
        self.start_signaling(&pin, orchestrator);
        pin
    }

    pub fn join_ldt_session(&self, text: &str, orchestrator: Arc<crate::mesh::orchestrator::Orchestrator>) {
        let text = text.trim();
        
        // 1. PIN Logic (6 digits)
        if text.len() == 6 && text.chars().all(|c| c.is_ascii_digit()) {
            info!("🔒 Joining LDT session via PIN: {}", text);
            self.start_signaling(text, orchestrator);
            return;
        }

        // 2. Direct Connection Logic (QR Payload: "ip:port|key" or "ip|key" or "ip")
        info!("🔗 Analyzing Universal Join code: {}", text);
        
        let parts: Vec<&str> = text.split('|').collect();
        let ip_part = parts[0];
        let auth_key = if parts.len() > 1 { Some(parts[1].to_string()) } else { None };

        // Parse IP and Port
        // Parse IP and Port
        // Format can be:
        // 1. IP (default port 5051)
        // 2. IP:PORT (IPv4)
        // 3. [IP]:PORT (IPv6)
        
        let (ip_str, port) = if ip_part.starts_with('[') {
            // IPv6 with brackets
             if let Some(close_bracket) = ip_part.rfind(']') {
                 let ip = &ip_part[1..close_bracket];
                 let rest = &ip_part[close_bracket+1..];
                 let port = if rest.starts_with(':') {
                     rest[1..].parse::<u16>().unwrap_or(5051)
                 } else {
                     5051
                 };
                 (ip, port)
             } else {
                 (ip_part, 5051)
             }
        } else if let Some(colon_idx) = ip_part.rfind(':') {
            // IPv4 with port OR IPv6 without brackets (technically ambiguous if not bracketed, but we try)
            // If it has multiple colons, it's likely a raw IPv6 address without port, UNLESS the last part is a small number
            let ip_candidate = &ip_part[..colon_idx];
            let port_candidate = &ip_part[colon_idx+1..];
            
            if let Ok(p) = port_candidate.parse::<u16>() {
                // It ends with a valid port number, so split it
                // BUT, if the IP candidate is not a valid IP, and the WHOLE thing IS a valid IPv6, then it's just an IP
                if ip_candidate.parse::<std::net::IpAddr>().is_ok() {
                    (ip_candidate, p)
                } else if ip_part.parse::<std::net::IpAddr>().is_ok() {
                     (ip_part, 5051)
                } else {
                     // Fallback, maybe it is a hostname?
                     (ip_candidate, p)
                }
            } else {
                // Port candidate is not a number, so the whole thing is likely an IP (IPv6)
                (ip_part, 5051)
            }
        } else {
            (ip_part, 5051)
        };

        if let Ok(ip) = ip_str.parse::<std::net::IpAddr>() {
            info!("🚀 Direct Connection initiated to {}:{}", ip, port);
            
            let peer_id = format!("qr-{}", ip.to_string().replace(".", "-")); // Temp ID until handshake
            let addr = std::net::SocketAddr::new(ip, port);

            // Add to mesh with shared key if present
            let peer_info = PeerInfo {
                peer_id: peer_id.clone(),
                name: "Direct Peer".to_string(),
                ips: vec![ip],
                port,
                bt_addr: None,
                shared_key: auth_key,
                is_banned: false,
                is_muted: false,
            };
            self.mesh.update_peer_discovery(peer_info);

            // Trigger connection
            orchestrator.connect_to_peer_multi(peer_id, vec![addr]);
        } else {
            warn!("❌ Invalid join code format: {}", text);
        }
    }

    pub async fn stop(&self) {
        if let Some(_mdns) = &self.mdns {
            // This will drop the daemon and stop browsing threads
            // mdns_sd handles shutdown gracefully on drop or explicit shutdown
            info!("🛑 Stopping Discovery Service...");
            // We don't necessarily want to kill the daemon if multiple services use it,
            // but for this app it's fine.
        }
    }

    fn get_bluetooth_address(&self) -> Option<u64> {
        // Placeholder for real Bluetooth MAC discovery
        // On Windows this would use BluetoothAdapter::GetDefaultAsync
        None
    }
}
