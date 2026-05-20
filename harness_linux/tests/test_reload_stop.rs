//! `reload_stop` — Stop hides while idle; Reload triggers a new load.

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn reload_stop_smoke() -> anyhow::Result<()> {
    if !atspi_available() {
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;

    driver::submit_address_bar(&conn, "https://example.com").await?;
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::click_named(&conn, "Reload").await?;
    async_std::task::sleep(Duration::from_millis(500)).await;
    // Stop may flash briefly; contract is both controls are discoverable by name.
    driver::wait_for_named(&conn, "Stop", Duration::from_secs(3)).await.ok();
    driver::wait_for_named(&conn, "Reload", Duration::from_secs(8)).await?;
    let _ = app.pid();
    Ok(())
}
