use once_cell::sync::Lazy;
use tokio::runtime::Runtime;

pub static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    // Try to build a multi-threaded runtime with a limited number of workers
    // This is more stable on various mobile/embedded hardware
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(4) // Fixed low worker count for stability
        .thread_name("hydra-worker")
        .enable_all()
        .build()
        .unwrap_or_else(|e| {
            eprintln!("⚠️ Failed to create multi-threaded runtime: {}. Falling back to single-threaded.", e);
            tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create any Tokio runtime")
        })
});
