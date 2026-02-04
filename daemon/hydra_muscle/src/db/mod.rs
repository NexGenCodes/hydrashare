use rusqlite::{Connection, Result};
use std::path::Path;
use std::sync::Mutex;
use tracing::info;

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn new<P: AsRef<Path>>(path: P) -> Result<Self> {
        let conn = Connection::open(path)?;
        
        // Enable WAL mode for better concurrency
        conn.pragma_update(None, "journal_mode", "WAL")?;
        
        let db = Self { conn: Mutex::new(conn) };
        db.init_schema()?;
        Ok(db)
    }

    fn init_schema(&self) -> Result<()> {
        info!("Initializing database schema...");
        
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "CREATE TABLE IF NOT EXISTS config (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS peers (
                hydra_id TEXT PRIMARY KEY,
                name TEXT,
                last_ip TEXT,
                public_port INTEGER,
                bt_addr INTEGER,
                pin_hash TEXT,
                salt TEXT,
                shared_key TEXT,
                last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS transfers (
                id TEXT PRIMARY KEY,
                file_path TEXT,
                file_size INTEGER,
                offset INTEGER,
                status TEXT, -- 'PENDING', 'RUNNING', 'COMPLETED', 'FAILED'
                direction TEXT, -- 'SEND', 'RECV'
                peer_id TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(peer_id) REFERENCES peers(hydra_id)
            )",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_transfers_peer ON transfers(peer_id)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status)",
            [],
        )?;

        Ok(())
    }

    pub fn get_config(&self, key: &str) -> Result<Option<String>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT value FROM config WHERE key = ?1")?;
        let mut rows = stmt.query([key])?;
        
        if let Some(row) = rows.next()? {
            Ok(Some(row.get(0)?))
        } else {
            Ok(None)
        }
    }

    pub fn set_config(&self, key: &str, value: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO config (key, value) VALUES (?1, ?2)",
            [key, value],
        )?;
        Ok(())
    }

    pub fn get_peer(&self, hydra_id: &str) -> Result<Option<PeerInfo>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT hydra_id, name, last_ip, public_port, bt_addr, shared_key FROM peers WHERE hydra_id = ?1")?;
        let mut rows = stmt.query([hydra_id])?;
        
        if let Some(row) = rows.next()? {
            let ips_str: String = row.get(2)?;
            let ips = ips_str.split(',')
                .filter_map(|s| s.parse().ok())
                .collect::<Vec<std::net::IpAddr>>();
            
            Ok(Some(PeerInfo {
                peer_id: row.get(0)?,
                name: row.get(1)?,
                ips,
                port: row.get(3)?,
                bt_addr: row.get(4).ok(),
                shared_key: row.get(5).ok(),
            }))
        } else {
            Ok(None)
        }
    }

    pub fn save_peer(&self, info: &PeerInfo) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let ips_str = info.ips.iter().map(|ip| ip.to_string()).collect::<Vec<_>>().join(",");
        conn.execute(
            "INSERT OR REPLACE INTO peers (hydra_id, name, last_ip, public_port, bt_addr, shared_key) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            (&info.peer_id, &info.name, &ips_str, info.port, info.bt_addr, &info.shared_key),
        )?;
        Ok(())
    }

    pub fn save_transfer(&self, id: &str, file_path: &str, size: u64, offset: u64, status: &str, peer_id: &str, direction: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO transfers (id, file_path, file_size, offset, status, direction, peer_id) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            (id, file_path, size as i64, offset as i64, status, direction, peer_id),
        )?;
        Ok(())
    }
}

#[derive(Clone, serde::Serialize, serde::Deserialize, Debug)]
pub struct PeerInfo {
    pub peer_id: String,
    pub name: String,
    pub ips: Vec<std::net::IpAddr>,
    pub port: u16,
    pub bt_addr: Option<u64>,
    pub shared_key: Option<String>,
}
