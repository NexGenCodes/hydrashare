use tracing_appender::non_blocking::WorkerGuard;
use tracing_subscriber::{fmt, prelude::*, EnvFilter};
use std::path::PathBuf;

pub struct LogGuard {
    _guard: WorkerGuard,
}

pub fn init_logging(log_dir: PathBuf) -> LogGuard {
    let file_appender = tracing_appender::rolling::daily(&log_dir, "hydra_daemon.log");
    let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);

    let file_layer = fmt::layer()
        .with_file(true)
        .with_line_number(true)
        .with_writer(non_blocking)
        .with_target(false)
        .with_ansi(false);

    let console_layer = fmt::layer()
        .with_writer(std::io::stdout)
        .with_target(false);

    // Filter: Debug for our crate, Info for others
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("hydra_muscle=debug,info"));

    // Cleanup old logs (keep last 7 days)
    clean_old_logs(&log_dir);

    tracing_subscriber::registry()
        .with(filter)
        .with(file_layer)
        .with(console_layer)
        .init();
    
    LogGuard { _guard: guard }
}

fn clean_old_logs(log_dir: &std::path::Path) {
    if let Ok(entries) = std::fs::read_dir(log_dir) {
        let now = std::time::SystemTime::now();
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                if name.starts_with("hydra_daemon.log") {
                    if let Ok(metadata) = std::fs::metadata(&path) {
                        if let Ok(modified) = metadata.modified() {
                            if let Ok(age) = now.duration_since(modified) {
                                if age.as_secs() > 7 * 24 * 3600 {
                                    let _ = std::fs::remove_file(path);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
