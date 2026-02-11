use anyhow::Result;
use hydra_muscle::api;
use std::path::PathBuf;
use tokio::signal;

#[tokio::main]
async fn main() -> Result<()> {
    // 1. Determine data directory
    let data_dir = if let Some(proj_dirs) = directories::ProjectDirs::from("com", "hydrashare", "HydraShare") {
        proj_dirs.data_dir().to_path_buf()
    } else {
        PathBuf::from("./data")
    };

    println!("🌊 HydraShare Daemon starting...");
    println!("📁 Data directory: {:?}", data_dir);

    // 2. Initialize the daemon
    let data_dir_str = data_dir.to_string_lossy().to_string();
    let res = api::init_daemon(data_dir_str);
    if res != 0 {
        eprintln!("❌ Failed to initialize daemon: {}", res);
        std::process::exit(1);
    }

    // 3. Start the engine
    let res = api::start_engine();
    if res != 0 {
        eprintln!("❌ Failed to start engine: {}", res);
        std::process::exit(1);
    }

    println!("✅ HydraShare Engine is running.");
    println!("🚀 Press Ctrl+C to stop.");

    // 4. Wait for Ctrl+C
    signal::ctrl_c().await?;

    println!("🛑 Stopping engine...");
    api::stop_engine();
    println!("👋 Goodbye!");

    Ok(())
}
