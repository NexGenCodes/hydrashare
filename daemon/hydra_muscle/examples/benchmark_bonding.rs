use hydra_muscle::quic::{client, server, cert};
use std::net::{SocketAddr, UdpSocket};
use tokio::time::Instant;
use std::sync::Arc;
use std::fs;
use std::io::Write;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 0. Setup Logging
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::DEBUG)
        .finish();
    tracing::subscriber::set_global_default(subscriber)?;

    println!("🚀 Starting HydraShare Performance Benchmark...");

    // 1. Prepare Test Data
    let file_size: i64 = 100 * 1024 * 1024; // 100 MB
    let file_path = "bench_input.dat";
    let dest_path = "bench_output.dat";
    let key = [0u8; 32];
    
    println!("📦 Generating {} MB test file...", file_size / (1024 * 1024));
    {
        let mut f = fs::File::create(file_path)?;
        let data = vec![0u8; 1024 * 1024];
        for _ in 0..100 {
            f.write_all(&data)?;
        }
    }

    // 2. Setup Server
    let server_socket = UdpSocket::bind("127.0.0.1:0")?;
    let server_addr = server_socket.local_addr()?;
    let server_fd = {
        #[cfg(windows)] { 
            use std::os::windows::io::AsRawSocket;
            server_socket.as_raw_socket() as isize 
        }
        #[cfg(unix)] { 
            use std::os::unix::io::AsRawFd;
            server_socket.as_raw_fd() as isize 
        }
    };

    println!("🎨 Server listening on {}", server_addr);

    let server_handle = tokio::spawn(async move {
        println!("👂 Server thread started");
        let res = server::run_quic_receive_fd(
            server_fd,
            dest_path.to_string(),
            file_size,
            0,
            &key,
            0,
            0,
            0,
            0,
            0,
            0,
            None,
            Some("bench-transfer-id".to_string()),
            None,
            None,
            None,
        ).await;
        println!("🏁 Server thread finished with result: {:?}", res);
        res
    });

    // 3. Setup Client & Run Transfer
    tokio::time::sleep(tokio::time::Duration::from_millis(1000)).await;
    
    let start_time = Instant::now();
    println!("🛰️ Starting 100MB transfer...");

    // We use a dummy progress callback to see it's alive
    extern "C" fn progress_cb(sent: i64, total: i64, _data: *mut std::ffi::c_void) {
        if sent % (10 * 1024 * 1024) == 0 {
            println!("📊 Progress: {} / {} bytes", sent, total);
        }
    }

    let res = client::run_quic_transfer(
        server_addr.to_string(),
        file_path.to_string(),
        file_size,
        0,
        &key,
        0,
        0,
        0,
        progress_cb as usize,
        0,
        0,
        None,
        Some("bench-transfer-id".to_string()),
        None,
        None,
        None, // In benchmark we skip peer_id check if possible or use localhost
    ).await;

    if let Err(e) = res {
        println!("❌ Client error: {}", e);
    }

    let _ = server_handle.await?;
    let duration = start_time.elapsed();
    
    // 4. Results
    let speed_mbps = (file_size as f64 / 1024.0 / 1024.0) / duration.as_secs_f64();
    println!("\n✅ Benchmark Complete!");
    println!("⏱️ Time: {:.2?}", duration);
    println!("🚀 Speed: {:.2} MB/s", speed_mbps);

    // Cleanup
    let _ = fs::remove_file(file_path);
    if fs::metadata(dest_path).is_ok() { let _ = fs::remove_file(dest_path); }
    let part_path = format!("{}.part", dest_path);
    if fs::metadata(&part_path).is_ok() { let _ = fs::remove_file(&part_path); }

    Ok(())
}
