use std::sync::Arc;
use crate::db::Database;
use crate::mesh::{MeshNetwork, orchestrator::Orchestrator};
use crate::discovery::DiscoveryService;
use crate::transfer::TransferManager;
use crate::auth::service::AuthService;

pub struct EngineState {
    pub db: Arc<Database>,
    pub mesh: Arc<MeshNetwork>,
    pub discovery: Arc<DiscoveryService>,
    pub transfer: Arc<TransferManager>,
    pub orchestrator: Arc<Orchestrator>,
    pub auth: Arc<AuthService>,
}

impl EngineState {
    pub fn new(
        db: Arc<Database>, 
        mesh: Arc<MeshNetwork>, 
        discovery: Arc<DiscoveryService>, 
        transfer: Arc<TransferManager>,
        orchestrator: Arc<Orchestrator>,
        auth: Arc<AuthService>,
    ) -> Self {
        Self {
            db,
            mesh,
            discovery,
            transfer,
            orchestrator,
            auth,
        }
    }
}
