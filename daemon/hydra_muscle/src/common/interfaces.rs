use if_addrs::get_if_addrs;
use std::net::IpAddr;
use tracing::warn;

pub fn list_local_ips() -> Vec<IpAddr> {
    let mut ips = Vec::new();
    match get_if_addrs() {
        Ok(ifaces) => {
            for iface in ifaces {
                if !iface.is_loopback() {
                    ips.push(iface.ip());
                }
            }
        }
        Err(e) => {
            warn!("⚠️ Failed to list network interfaces: {}", e);
        }
    }
    ips
}
