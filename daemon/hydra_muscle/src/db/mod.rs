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
        db.run_migrations()?;
        Ok(db)
    }

    fn run_migrations(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();

        // 1. Peer Table Migrations (is_banned, is_muted)
        let mut has_banned = false;
        let mut has_muted = false;

        {
            let mut stmt = conn.prepare("PRAGMA table_info(peers)")?;
            let mut rows = stmt.query([])?;
            while let Some(row) = rows.next()? {
                let name: String = row.get(1)?;
                if name == "is_banned" { has_banned = true; }
                if name == "is_muted" { has_muted = true; }
            }
        }

        if !has_banned {
            info!("MIGRATION: Adding is_banned to peers table");
            conn.execute("ALTER TABLE peers ADD COLUMN is_banned INTEGER DEFAULT 0", [])?;
        }
        if !has_muted {
            info!("MIGRATION: Adding is_muted to peers table");
            conn.execute("ALTER TABLE peers ADD COLUMN is_muted INTEGER DEFAULT 0", [])?;
        }

        Ok(())
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
                is_banned INTEGER DEFAULT 0,
                is_muted INTEGER DEFAULT 0,
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
        
        conn.execute(
            "CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                peer_id TEXT,
                text TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                is_me INTEGER,
                msg_type TEXT,
                FOREIGN KEY(peer_id) REFERENCES peers(hydra_id)
            )",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_messages_peer ON messages(peer_id)",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_messages_time ON messages(timestamp)",
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
        let mut stmt = conn.prepare("SELECT hydra_id, name, last_ip, public_port, bt_addr, shared_key, is_banned, is_muted FROM peers WHERE hydra_id = ?1")?;
        let mut rows = stmt.query([hydra_id])?;
        
        if let Some(row) = rows.next()? {
            let ips_str: String = row.get(2)?;
            let ips = ips_str.split(',')
                .filter_map(|s| s.parse().ok())
                .collect::<Vec<std::net::IpAddr>>();
            
            let is_banned: i32 = row.get(6)?;
            let is_muted: i32 = row.get(7)?;

            Ok(Some(PeerInfo {
                peer_id: row.get(0)?,
                name: row.get(1)?,
                ips,
                port: row.get(3)?,
                bt_addr: row.get(4).ok(),
                shared_key: row.get(5).ok(),
                is_banned: is_banned != 0,
                is_muted: is_muted != 0,
            }))
        } else {
            Ok(None)
        }
    }

    pub fn save_peer(&self, info: &PeerInfo) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let ips_str = info.ips.iter().map(|ip| ip.to_string()).collect::<Vec<_>>().join(",");

        // Use INSERT OR IGNORE first, then UPDATE to preserve banned/muted status if we're doing a generic "save"
        conn.execute(
            "INSERT OR IGNORE INTO peers (hydra_id, name, last_ip, public_port, bt_addr, shared_key, is_banned, is_muted) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            (&info.peer_id, &info.name, &ips_str, info.port, info.bt_addr, &info.shared_key, if info.is_banned { 1 } else { 0 }, if info.is_muted { 1 } else { 0 }),
        )?;

        conn.execute(
            "UPDATE peers SET name=?1, last_ip=?2, public_port=?3, bt_addr=?4, shared_key=COALESCE(?5, shared_key) WHERE hydra_id=?6",
            (&info.name, &ips_str, info.port, info.bt_addr, &info.shared_key, &info.peer_id),
        )?;

        Ok(())
    }

    pub fn set_peer_status(&self, peer_id: &str, banned: bool, muted: bool) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE peers SET is_banned = ?1, is_muted = ?2 WHERE hydra_id = ?3",
            (if banned { 1 } else { 0 }, if muted { 1 } else { 0 }, peer_id),
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

    pub fn get_all_peers(&self) -> Result<Vec<PeerInfo>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT hydra_id, name, last_ip, public_port, bt_addr, shared_key, is_banned, is_muted FROM peers")?;
        let rows = stmt.query_map([], |row| {
            let ips_str: String = row.get(2)?;
            let ips = ips_str.split(',')
                .filter_map(|s| s.parse().ok())
                .collect::<Vec<std::net::IpAddr>>();
            
            let is_banned: i32 = row.get(6)?;
            let is_muted: i32 = row.get(7)?;

            Ok(PeerInfo {
                peer_id: row.get(0)?,
                name: row.get(1)?,
                ips,
                port: row.get(3)?,
                bt_addr: row.get(4).ok(),
                shared_key: row.get(5).ok(),
                is_banned: is_banned != 0,
                is_muted: is_muted != 0,
            })
        })?;
        
        let mut peers = Vec::new();
        for peer in rows {
            peers.push(peer?);
        }
        Ok(peers)
    }
    pub fn mark_all_messages_read(&self, _peer_id: &str) -> Result<()> {
        // Message history is currently stored entirely in the Flutter frontend (StorageService).
        // This command is a no-op in the daemon for now, but kept for API compatibility.
        // Future improvements could move message exclusivity to the daemon.
        info!("mark_all_messages_read: Handled by frontend storage (no-op in daemon).");
        Ok(())
    }

    pub fn save_message(&self, msg: &MessageInfo) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        // Use CURRENT_TIMESTAMP if msg.timestamp is empty or placeholder
        let timestamp = if msg.timestamp.is_empty() || msg.timestamp == "PENDING" || msg.timestamp == "RECEIVED" {
            "CURRENT_TIMESTAMP".to_string()
        } else {
            format!("'{}'", msg.timestamp)
        };

        let sql = format!(
            "INSERT INTO messages (id, peer_id, text, timestamp, is_me, msg_type) VALUES (?1, ?2, ?3, {}, ?4, ?5)",
            timestamp
        );

        conn.execute(
            &sql,
            (&msg.id, &msg.peer_id, &msg.text, if msg.is_me { 1 } else { 0 }, &msg.msg_type),
        )?;
        Ok(())
    }

    pub fn get_messages(&self, peer_id: &str) -> Result<Vec<MessageInfo>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, peer_id, text, timestamp, is_me, msg_type FROM messages WHERE peer_id = ?1 ORDER BY timestamp ASC")?;
        let rows = stmt.query_map([peer_id], |row| {
            let is_me_int: i32 = row.get(4)?;
            Ok(MessageInfo {
                id: row.get(0)?,
                peer_id: row.get(1)?,
                text: row.get(2)?,
                timestamp: row.get(3)?,
                is_me: is_me_int != 0,
                msg_type: row.get(5)?,
            })
        })?;
        
        let mut messages = Vec::new();
        for msg in rows {
            messages.push(msg?);
        }
        Ok(messages)
    }

    pub fn cleanup_history(&self) -> Result<usize> {
        let conn = self.conn.lock().unwrap();
        
        // 1. Cleanup messages older than 7 days
        let msgs_removed = conn.execute(
            "DELETE FROM messages WHERE timestamp < datetime('now', '-7 days')",
            [],
        )?;
        
        // 2. Cleanup transfers older than 7 days
        let transfers_removed = conn.execute(
            "DELETE FROM transfers WHERE created_at < datetime('now', '-7 days')",
            [],
        )?;
        
        if msgs_removed > 0 || transfers_removed > 0 {
            info!("🧹 Database Cleanup: Removed {} messages and {} transfers older than 7 days", msgs_removed, transfers_removed);
        }
        
        Ok(msgs_removed + transfers_removed)
    }
}

#[derive(Clone, serde::Serialize, serde::Deserialize, Debug)]
pub struct MessageInfo {
    pub id: String,
    pub peer_id: String,
    pub text: String,
    pub timestamp: String,
    pub is_me: bool,
    pub msg_type: String,
}

#[derive(Clone, serde::Serialize, serde::Deserialize, Debug)]
pub struct PeerInfo {
    pub peer_id: String,
    pub name: String,
    pub ips: Vec<std::net::IpAddr>,
    pub port: u16,
    pub bt_addr: Option<u64>,
    pub shared_key: Option<String>,
    pub is_banned: bool,
    pub is_muted: bool,
}
