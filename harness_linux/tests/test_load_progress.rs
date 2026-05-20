//! `load_progress` — progress indicator accessible exists during load.

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn load_progress_smoke() -> anyhow::Result<()> {
    if !atspi_available() {
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;

    driver::submit_address_bar(&conn, "https://example.com").await?;
    // Progress bar is always present; may be 0 after load finishes.
    driver::wait_for_named(&conn, "Load progress indicator", Duration::from_secs(8)).await?;
    let _ = app.pid();
    Ok(())
}
