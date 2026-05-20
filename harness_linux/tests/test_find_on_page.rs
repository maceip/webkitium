//! `find_on_page` — find bar + match count label.

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn find_on_page_reports_match_count() -> anyhow::Result<()> {
    if !atspi_available() {
        return Ok(());
    }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_FIND", "1")])?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;

    driver::submit_address_bar(&conn, "data:text/plain,foo bar foo baz foo").await?;
    async_std::task::sleep(Duration::from_secs(1)).await;

    driver::set_text_named(&conn, "Find in page", "foo").await?;
    async_std::task::sleep(Duration::from_millis(600)).await;
    let count = driver::text_of_named(&conn, "Find match count").await?;
    assert!(
        count.contains("match"),
        "expected match count label, got '{count}'"
    );
    let _ = app.pid();
    Ok(())
}
