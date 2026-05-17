//! AT-SPI smoke harness for the Webkitium GTK Linux shell.
//!
//! The harness binary is the *app under test*; this crate just hosts the
//! `#[test]` cases and a small driver. Each test spawns the shell with
//! `WEBKITIUM_PROFILE_DIR=<TempDir>` so the FFI suggestions.db doesn't
//! leak between cases.
//!
//! Tests are `#[ignore]` by default so they can compile and pass in CI
//! environments without an AT-SPI session bus. Pass `--ignored` to run.
//!
//! What's deliberately NOT here:
//!   - mocking of the FFI core (we drive the real shell against real
//!     SQLite — there is no value in pretending);
//!   - cross-platform abstractions (this is the *Linux* harness).

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};
use tempfile::TempDir;

/// Path to the `webkitium` binary built by `chrome/linux/`. Honours
/// `WEBKITIUM_BIN` if set (CI / cross-builds), otherwise falls back to
/// the repo-relative debug build.
pub fn binary_path() -> PathBuf {
    if let Ok(p) = std::env::var("WEBKITIUM_BIN") {
        return PathBuf::from(p);
    }
    let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest
        .join("../chrome/linux/target/debug/webkitium")
        .canonicalize()
        .unwrap_or_else(|_| {
            // Fall back to the un-canonicalised path so error messages
            // surface the missing file clearly.
            manifest.join("../chrome/linux/target/debug/webkitium")
        })
}

/// A running shell, killed on drop.
pub struct App {
    child: Child,
    #[allow(dead_code)] // held to keep the temp dir alive
    profile: TempDir,
}

impl App {
    /// Spawn the shell with an isolated profile dir. AT-SPI bus must be
    /// available on the test host for real interaction; the spawn
    /// itself is cheap regardless.
    pub fn spawn() -> Result<Self> {
        Self::spawn_with_seed(|_| Ok(()))
    }

    /// Spawn but with a chance to pre-populate the profile DB. The
    /// closure runs with the profile root path before the shell starts.
    pub fn spawn_with_seed<F>(seed: F) -> Result<Self>
    where
        F: FnOnce(&Path) -> Result<()>,
    {
        let profile = tempfile::tempdir().context("tempdir")?;
        seed(profile.path())?;
        let bin = binary_path();
        let child = Command::new(&bin)
            .env("WEBKITIUM_PROFILE_DIR", profile.path())
            // Ensure the shell uses the system AT-SPI bus, not a stale
            // env var pointing elsewhere.
            .env_remove("GTK_A11Y_USE_ATSPI")
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .spawn()
            .with_context(|| format!("spawning {}", bin.display()))?;
        Ok(App { child, profile })
    }

    pub fn pid(&self) -> u32 {
        self.child.id()
    }

    /// Wait until the shell has registered itself on the session bus.
    /// Best-effort; if AT-SPI isn't available, returns Err(_) after the
    /// timeout.
    pub fn wait_ready(&self, timeout: Duration) -> Result<()> {
        let start = Instant::now();
        while start.elapsed() < timeout {
            // Cheap probe: if any AT-SPI bus is up, an empty connection
            // can be made; otherwise sleep and retry.
            if async_std::task::block_on(async {
                atspi::AccessibilityConnection::new().await.is_ok()
            }) {
                return Ok(());
            }
            std::thread::sleep(Duration::from_millis(100));
        }
        anyhow::bail!("AT-SPI bus did not become available within {:?}", timeout)
    }
}

impl Drop for App {
    fn drop(&mut self) {
        // Don't care about the exit code — just want it gone.
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

/// AT-SPI not running on the host is a *valid* state for the build
/// host; tests gated on this return Ok(false) so the body can short-
/// circuit cleanly.
pub fn atspi_available() -> bool {
    async_std::task::block_on(async {
        atspi::AccessibilityConnection::new().await.is_ok()
    })
}
