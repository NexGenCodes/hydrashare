pub mod pairing;

use mdns_sd::{ServiceDaemon, ServiceInfo};
use std::collections::HashMap;
use tracing::info;
use std::sync::Arc;
use std::net::IpAddr;

pub struct DiscoveryService {
    mdns: ServiceDaemon,
    service_type: String,
    local_peer_id: String,
    port: u16,
    mesh: Arc<crate::mesh::MeshNetwork>,
}

#[derive(Clone, Debug)]
pub struct PeerInfo {
    pub peer_id: String,
    pub name: String,
    pub ip: IpAddr,
    pub port: u16,
}

impl DiscoveryService {
    pub fn new(local_peer_id: &str, port: u16, mesh: Arc<crate::mesh::MeshNetwork>) -> Self {
        let mdns = ServiceDaemon::new().expect("Failed to create mDNS daemon");
        let service_type = "_hydra._udp.local.".to_string();

        Self {
            mdns,
            service_type,
            local_peer_id: local_peer_id.to_string(),
            port,
            mesh,
        }
    }

    pub fn start(&self) {
        let hostname = hostname::get().unwrap_or_default().to_string_lossy().to_string();
        let instance_name = format!("{}-{}", hostname, self.local_peer_id);
        
        let mut properties = HashMap::new();
        properties.insert("id".to_string(), self.local_peer_id.clone());
        properties.insert("port".to_string(), self.port.to_string());

        let service_info = ServiceInfo::new(
            &self.service_type,
            &instance_name,
            &hostname,
            "", // IP (let mdns-sd detect)
            self.port,
            Some(properties),
        ).expect("Valid service info");

        self.mdns.register(service_info).expect("Failed to register mDNS service");
        info!("📢 Discovery Service started: announcing as {}", instance_name);

        // Start browsing
        let receiver = self.mdns.browse(&self.service_type).expect("Failed to browse");
        let peers = self.mesh.clone();
        
        std::thread::spawn(move || {
            while let Ok(event) = receiver.recv() {
                match event {
                    mdns_sd::ServiceEvent::ServiceResolved(info) => {
                        let properties = info.get_properties();
                        if let Some(peer_id) = properties.get("id") {
                            let peer_id = peer_id.val_str();
                            if let Some(ip) = info.get_addresses().iter().next() {
                                let peer_info = PeerInfo {
                                    peer_id: peer_id.to_string(),
                                    name: info.get_fullname().to_string(),
                                    ip: *ip,
                                    port: info.get_port(),
                                };
                                peers.update_peer_discovery(peer_info.clone());

                                // Emit to UI
                                crate::ffi::emit_event(crate::ffi::DaemonEvent::PeerDiscovered {
                                    peer_id: peer_info.peer_id,
                                    name: peer_info.name,
                                    ip: peer_info.ip.to_string(),
                                    port: peer_info.port,
                                });
                            }
                        }
                    }
                    _ => {}
                }
            }
        });
    }
}
