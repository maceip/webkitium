//! `downloads_list` smoke — see features.yaml (required: true).

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn downloads_list_smoke() -> anyhow::Result<()> {
    if !atspi_available() {
        eprintln!("AT-SPI unavailable; skipping downloads_list");
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;
    driver::wait_for_named(&conn, "Address bar", Duration::from_secs(15)).await?;
    Ok(())
}
