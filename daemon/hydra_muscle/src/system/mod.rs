pub mod runtime;

use sysinfo::System;
use std::sync::{Arc, RwLock};
use once_cell::sync::Lazy;
use tracing::debug;

use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum SystemHealth {
    Optimal,
    Throttled,   // Battery < 20% or High Temp
    Emergency,   // Battery < 5% or Critical Temp
}

pub struct Intelligence {
    sys: System,
    health: SystemHealth,
}

impl Intelligence {
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        Self {
            sys,
            health: SystemHealth::Optimal,
        }
    }

    pub fn refresh(&mut self) {
        self.sys.refresh_all();
        
        // Intelligence Logic: Determine health based on battery and thermal
        let mut new_health = SystemHealth::Optimal;

        // Placeholder for real battery check
        let cpu_load = self.sys.global_cpu_info().cpu_usage();
        if cpu_load > 90.0 {
            new_health = SystemHealth::Throttled;
        }

        self.health = new_health;
    }

    pub fn get_health(&self) -> SystemHealth {
        self.health
    }
}

pub static INTELLIGENCE: Lazy<Arc<RwLock<Intelligence>>> = Lazy::new(|| {
    Arc::new(RwLock::new(Intelligence::new()))
});

pub fn start_intelligence_loop() {
    let intel = INTELLIGENCE.clone();
    
    // Use the daemon-wide runtime
    self::runtime::RUNTIME.spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_secs(30)).await;
            if let Ok(mut guard) = intel.write() {
                guard.refresh();
                debug!("🧠 System Intelligence updated: {:?}", guard.get_health());
            }
        }
    });
}
