use std::net::{UdpSocket, SocketAddr};
use stun::message::{Message, BINDING_REQUEST, Getter};
use stun::agent::TransactionId;
use stun::xoraddr::XorMappedAddress;
use tracing::debug;
use std::time::Duration;

pub struct StunClient {
    stun_server: SocketAddr,
}

impl StunClient {
    pub fn new(stun_server: &str) -> Self {
        let addr = stun_server.parse().unwrap_or_else(|_| {
            "74.125.143.127:19302".parse().unwrap() // stun.l.google.com
        });
        Self { stun_server: addr }
    }

    pub fn get_public_addr(&self) -> anyhow::Result<SocketAddr> {
        let mut last_err = anyhow::anyhow!("STUN discovery failed after 3 tries");
        
        for i in 1..=3 {
            match self.try_get_public_addr() {
                Ok(addr) => return Ok(addr),
                Err(e) => {
                    tracing::warn!("⚠️ STUN try {} failed: {}", i, e);
                    last_err = e;
                    std::thread::sleep(Duration::from_millis(500 * i as u64));
                }
            }
        }
        
        Err(last_err)
    }

    fn try_get_public_addr(&self) -> anyhow::Result<SocketAddr> {
        let socket = UdpSocket::bind("0.0.0.0:0")?;
        socket.set_read_timeout(Some(Duration::from_secs(3)))?;
        socket.connect(self.stun_server)?;

        let mut msg = Message::new();
        msg.build(&[
            Box::new(TransactionId::default()),
            Box::new(BINDING_REQUEST),
        ])?;

        socket.send(&msg.raw)?;

        let mut buf = [0u8; 1500];
        let (len, _) = socket.recv_from(&mut buf)?;

        let mut response = Message::new();
        response.write(&buf[..len])?;

        let mut xor_addr = XorMappedAddress::default();
        xor_addr.get_from(&response)?;

        let public_addr = SocketAddr::new(xor_addr.ip, xor_addr.port);
        debug!("🌐 Discovered public IP: {}", public_addr);

        Ok(public_addr)
    }
}
