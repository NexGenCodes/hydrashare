use if_addrs::get_if_addrs;
use std::net::IpAddr;
use tracing::warn;

pub fn list_local_ips() -> Vec<IpAddr> {
    let mut ips = Vec::new();
    match get_if_addrs() {
        Ok(ifaces) => {
            for iface in ifaces {
                if iface.is_loopback() {
                    continue;
                }

                let name = iface.name.to_lowercase();
                // Filter out common virtual/tunnel interfaces
                if name.contains("docker") 
                    || name.contains("veth") 
                    || name.contains("br-") 
                    || name.contains("vboxnet")
                    || name.contains("vmnet")
                    || name.contains("vethernet")
                    || name.contains("tun")
                    || name.contains("tap")
                {
                    continue;
                }

                ips.push(iface.ip());
            }
        }
        Err(e) => {
            warn!("⚠️ Failed to list network interfaces: {}", e);
        }
    }

    // Sort: IPv4 first, then IPv6, then by value
    ips.sort_by(|a, b| {
        match (a, b) {
            (IpAddr::V4(_), IpAddr::V6(_)) => std::cmp::Ordering::Less,
            (IpAddr::V6(_), IpAddr::V4(_)) => std::cmp::Ordering::Greater,
            _ => a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal),
        }
    });

    ips
}
