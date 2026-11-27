//! One tracing setup for every binary.
//!
//! Filter with `VICTORY_LOG` (falls back to `RUST_LOG`), e.g.
//! `VICTORY_LOG=victory_loader=trace,info`. Debug and trace output exist
//! only in builds with the `diagnostics` feature; a plain release build
//! logs info and above whatever the filter asks for.
//!
//! `VICTORY_LOG_FILE=<path>` appends the same lines to that file too (it is
//! made with its folder; a path inside the source tree is refused, as the
//! log names the title's code and data: docs/asset-policy.md).

use tracing_subscriber::EnvFilter;
use tracing_subscriber::filter::LevelFilter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

/// The most verbose level this build can log.
const CAP: LevelFilter = if cfg!(feature = "diagnostics") {
    LevelFilter::TRACE
} else {
    LevelFilter::INFO
};

pub fn init(default_level: &str) {
    let filter = std::env::var("VICTORY_LOG")
        .or_else(|_| std::env::var("RUST_LOG"))
        .ok()
        .and_then(|v| EnvFilter::try_new(v).ok())
        .unwrap_or_else(|| EnvFilter::new(default_level));
    let file = log_file();
    let _ = tracing_subscriber::registry()
        .with(CAP)
        .with(filter)
        .with(
            tracing_subscriber::fmt::layer()
                .with_target(true)
                .with_writer(std::io::stderr),
        )
        .with(file.map(|file| {
            tracing_subscriber::fmt::layer()
                .with_target(true)
                .with_ansi(false)
                .with_writer(std::sync::Mutex::new(file))
        }))
        .try_init();
}

/// The file `VICTORY_LOG_FILE` names, opened to be added to.
fn log_file() -> Option<std::fs::File> {
    let path = std::path::PathBuf::from(std::env::var_os("VICTORY_LOG_FILE").filter(|v| !v.is_empty())?);
    let opened = crate::policy::ensure_outside_repo(&path)
        .map_err(|e| e.to_string())
        .and_then(|()| {
            if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
                std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
            }
            std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(&path)
                .map_err(|e| e.to_string())
        });
    match opened {
        Ok(file) => Some(file),
        Err(e) => {
            // (Before any subscriber: plain text.)
            eprintln!("VICTORY_LOG_FILE {}: not written ({e})", path.display());
            None
        }
    }
}
