//! `navigate_back_forward` — Back/Forward button state after two navigations.

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn navigate_back_forward_smoke() -> anyhow::Result<()> {
    if !atspi_available() {
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;

    driver::wait_for_named(&conn, "Address bar", Duration::from_secs(15)).await?;
    driver::submit_address_bar(&conn, "https://example.org").await?;
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::submit_address_bar(&conn, "https://example.com").await?;
    async_std::task::sleep(Duration::from_secs(2)).await;

    assert!(
        driver::button_enabled(&conn, "Back").await?,
        "Back should be enabled after second navigation"
    );
    driver::click_named(&conn, "Back").await?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    assert!(
        driver::button_enabled(&conn, "Forward").await?,
        "Forward should be enabled after Back"
    );
    let _ = app.pid();
    Ok(())
}
