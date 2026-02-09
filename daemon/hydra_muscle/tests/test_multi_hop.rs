use hydra_muscle::mesh::orchestrator::{Orchestrator, MeshMessage};
use hydra_muscle::db::Database;
use hydra_muscle::auth::service::AuthService;
use hydra_muscle::discovery::DiscoveryService;
use hydra_muscle::mesh::MeshNetwork;
use std::sync::Arc;
use tokio::time::{sleep, Duration};
use tempfile::tempdir;

async fn create_node(id: &str) -> (Arc<Orchestrator>, u16) {
    let dir = tempdir().expect("Failed to create temp dir");
    // We need to keep the dir alive if we want to keep the DB alive, 
    // but in this test we don't care after creation.
    let db_path = dir.path().join("hydra.db");
    let db = Arc::new(Database::new(&db_path).expect("Failed to create DB"));
    let auth = Arc::new(AuthService::new(db.clone()));
    let mesh = Arc::new(MeshNetwork::new());
    let discovery = Arc::new(DiscoveryService::new(id, mesh.clone(), auth.clone()));
    let orchestrator = Arc::new(Orchestrator::new(id, mesh.clone(), discovery, db.clone()));
    let port = orchestrator.start().await.expect("Failed to start orchestrator");
    (orchestrator, port)
}

#[tokio::test]
async fn test_multi_hop_forwarding() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_test_writer()
        .try_init();

    // 1. Setup 3 nodes
    let (node_a, port_a) = create_node("node_a").await;
    let (node_b, port_b) = create_node("node_b").await;
    let (_node_c, port_c) = create_node("node_c").await;

    println!("🏗️ Mesh Topology: Node A ({}) -> Node B ({}) -> Node C ({})", port_a, port_b, port_c);

    // 2. Connect A -> B and B -> C
    println!("🤝 Establishing path A -> B...");
    node_a.connect_to_peer("node_b".to_string(), format!("127.0.0.1:{}", port_b).parse().unwrap());
    sleep(Duration::from_millis(500)).await;
    
    println!("🤝 Establishing path B -> C...");
    node_b.connect_to_peer("node_c".to_string(), format!("127.0.0.1:{}", port_c).parse().unwrap());

    // Give time for handshakes to complete and connections to be registered
    println!("⏱️ Waiting for QUIC handshakes to complete...");
    
    // Poll for connections instead of hard sleep
    let start = std::time::Instant::now();
    let mut connected = false;
    while start.elapsed() < Duration::from_secs(30) {
        if node_b.has_connection("node_a") && node_b.has_connection("node_c") {
            connected = true;
            break;
        }
        sleep(Duration::from_millis(500)).await;
    }

    // 3. Verify connections on Node B
    println!("🔍 Verifying Node B connection topology...");
    if !node_b.has_connection("node_a") {
        println!("❌ Node B misses connection to Node A");
    }
    if !node_b.has_connection("node_c") {
        println!("❌ Node B misses connection to Node C");
    }
    assert!(connected, "Node B failed to establish connections to A and C within timeout");
    println!("✅ Connections verified: A->B and B->C");

    // 4. Node A sends a chat meant for Node C, but sends it to Node B
    // Our logic in handle_message should detect the target_peer_id and forward it.
    let msg = MeshMessage::Chat {
        text: "Trans-Mesh Hello".to_string(),
        target_peer_id: Some("node_c".to_string()),
    };

    println!("🚀 Node A sending relayed chat to Node C via Node B...");
    node_a.send_to_peer("node_b", msg).await.expect("Node A failed to send to Node B");

    // Give time for relaying
    sleep(Duration::from_secs(2)).await;

    println!("✨ Multi-hop test complete. Verification relies on Orchestrator logs for forwarding.");
}
