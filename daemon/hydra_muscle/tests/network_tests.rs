use hydra_muscle::common::networks::{classify_network, NetworkType};


#[test]
fn test_network_classification() {
    // Android Hotspot
    assert_eq!(classify_network("192.168.43.5".parse().unwrap()), NetworkType::Hotspot);
    
    // iOS Hotspot
    assert_eq!(classify_network("172.20.10.2".parse().unwrap()), NetworkType::Hotspot);
    
    // Link-local (Wired)
    assert_eq!(classify_network("169.254.1.1".parse().unwrap()), NetworkType::Ethernet);
    
    // Standard LAN
    assert_eq!(classify_network("192.168.1.1".parse().unwrap()), NetworkType::WiFi);
    
    // Public IP (LDT)
    assert_eq!(classify_network("8.8.8.8".parse().unwrap()), NetworkType::LDT);
}
