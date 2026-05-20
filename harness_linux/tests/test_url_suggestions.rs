//! `url_suggestions` — typing in the URL bar surfaces the suggestions list.

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn url_suggestions_smoke() -> anyhow::Result<()> {
    if !atspi_available() {
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;

    driver::set_text_named(&conn, "Address bar", "exam").await?;
    async_std::task::sleep(Duration::from_millis(400)).await;
    driver::wait_for_named(&conn, "URL suggestions", Duration::from_secs(5)).await?;
    let _ = app.pid();
    Ok(())
}
