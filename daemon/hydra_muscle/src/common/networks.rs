use std::net::IpAddr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum NetworkType {
    Ethernet = 100,
    WiFi = 80,
    Hotspot = 60,
    LDT = 20,
    Unknown = 0,
}

pub fn classify_network(ip: IpAddr) -> NetworkType {
    match ip {
        IpAddr::V4(ipv4) => {
            let octets = ipv4.octets();
            
            // Common Hotspot Subnets
            if octets[0] == 192 && octets[1] == 168 && octets[2] == 43 {
                return NetworkType::Hotspot; // Android
            }
            if octets[0] == 192 && octets[1] == 168 && octets[2] == 137 {
                return NetworkType::Hotspot; // Windows
            }
            if octets[0] == 172 && octets[1] == 20 && octets[2] == 10 {
                return NetworkType::Hotspot; // iOS
            }
            
            // Link-local (Direct cable)
            if octets[0] == 169 && octets[1] == 254 {
                return NetworkType::Ethernet;
            }
            
            // Assume 192.168.x.x or 10.x.x.x is likely WiFi/LAN
            if (octets[0] == 192 && octets[1] == 168) || octets[0] == 10 || (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) {
                return NetworkType::WiFi;
            }
            
            // Public IPs (simplified)
            NetworkType::LDT
        }
        IpAddr::V6(_) => NetworkType::WiFi, // Placeholder for IPv6
    }
}
