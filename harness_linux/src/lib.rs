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

pub mod driver;
pub mod smokes;

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
        .join("../chrome/linux/target/release/webkitium")
        .canonicalize()
        .unwrap_or_else(|_| {
            // Fall back to the un-canonicalised path so error messages
            // surface the missing file clearly.
            manifest.join("../chrome/linux/target/debug/webkitium")
        })
}

enum ProfileSlot {
    Owned(TempDir),
    External(PathBuf),
}

/// A running shell, killed on drop.
pub struct App {
    child: Child,
    profile: ProfileSlot,
}

fn prepare_harness_profile(path: &Path) -> Result<()> {
    std::fs::create_dir_all(path)?;
    std::fs::write(path.join(".welcome_done"), "1").ok();
    Ok(())
}

impl App {
    /// Profile directory used for this instance.
    pub fn profile_path(&self) -> &Path {
        match &self.profile {
            ProfileSlot::Owned(t) => t.path(),
            ProfileSlot::External(p) => p.as_path(),
        }
    }

    /// Spawn the shell with an isolated profile dir. AT-SPI bus must be
    /// available on the test host for real interaction; the spawn
    /// itself is cheap regardless.
    pub fn spawn() -> Result<Self> {
        Self::spawn_with_env(&[])
    }

    /// Spawn against an existing profile path (caller keeps the directory alive).
    pub fn spawn_with_profile_dir(dir: &Path) -> Result<Self> {
        prepare_harness_profile(dir)?;
        Self::spawn_at(dir, &[("WEBKITIUM_HARNESS_RESTORE", "1")])
    }

    /// Spawn with extra environment variables (harness-only hooks).
    pub fn spawn_with_env(vars: &[(&str, &str)]) -> Result<Self> {
        Self::spawn_with_seed_and_env(vars, |_| Ok(()))
    }

    /// Spawn but with a chance to pre-populate the profile DB. The
    /// closure runs with the profile root path before the shell starts.
    pub fn spawn_with_seed<F>(seed: F) -> Result<Self>
    where
        F: FnOnce(&Path) -> Result<()>,
    {
        Self::spawn_with_seed_and_env(&[], seed)
    }

    pub fn spawn_with_seed_and_env<F>(vars: &[(&str, &str)], seed: F) -> Result<Self>
    where
        F: FnOnce(&Path) -> Result<()>,
    {
        let profile = tempfile::tempdir().context("tempdir")?;
        let profile_path = profile.path().to_path_buf();
        prepare_harness_profile(&profile_path)?;
        seed(&profile_path)?;
        Self::launch(&profile_path, vars, ProfileSlot::Owned(profile), true)
    }

    fn spawn_at(path: &Path, vars: &[(&str, &str)]) -> Result<Self> {
        Self::launch(path, vars, ProfileSlot::External(path.to_path_buf()), false)
    }

    fn launch(
        path: &Path,
        vars: &[(&str, &str)],
        profile: ProfileSlot,
        mark_harness: bool,
    ) -> Result<Self> {
        let bin = binary_path();
        let mut cmd = Command::new(&bin);
        cmd.env("WEBKITIUM_PROFILE_DIR", path)
            .arg(format!("--profile-dir={}", path.display()))
            .env(
                "GDK_BACKEND",
                std::env::var("GDK_BACKEND").unwrap_or_else(|_| "wayland".into()),
            )
            .env("GTK_A11Y", "atspi");
        if mark_harness {
            cmd.env("WEBKITIUM_HARNESS", "1");
        }
        for (k, v) in vars {
            cmd.env(k, v);
        }
        let child = cmd
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
    /// Fresh AT-SPI connection for the test body.
    pub async fn connection() -> anyhow::Result<atspi::connection::AccessibilityConnection> {
        atspi::connection::AccessibilityConnection::new()
            .await
            .context("AT-SPI connection")
    }

    pub fn wait_for_exit(&mut self, timeout: Duration) -> Result<()> {
        let start = Instant::now();
        loop {
            if let Ok(Some(status)) = self.child.try_wait() {
                if !status.success() {
                    // Harness only needs a clean DB flush, not exit code 0.
                }
                return Ok(());
            }
            if start.elapsed() >= timeout {
                anyhow::bail!("webkitium did not exit within {:?}", timeout);
            }
            std::thread::sleep(Duration::from_millis(100));
        }
    }

    pub fn wait_ready(&self, timeout: Duration) -> Result<()> {
        let start = Instant::now();
        while start.elapsed() < timeout {
            let ready = async_std::task::block_on(async {
                let Ok(conn) = App::connection().await else {
                    return false;
                };
                driver::wait_for_named(&conn, "Address bar", Duration::from_millis(800))
                    .await
                    .is_ok()
            });
            if ready {
                return Ok(());
            }
            std::thread::sleep(Duration::from_millis(200));
        }
        anyhow::bail!("webkitium UI did not expose Address bar within {:?}", timeout)
    }
}

impl Drop for App {
    fn drop(&mut self) {
        #[cfg(unix)]
        {
            use std::time::Instant;
            unsafe {
                libc::kill(self.child.id() as i32, libc::SIGTERM);
            }
            let start = Instant::now();
            while start.elapsed() < Duration::from_secs(8) {
                if let Ok(Some(_)) = self.child.try_wait() {
                    return;
                }
                std::thread::sleep(Duration::from_millis(100));
            }
        }
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
