//! `multiple_tabs` smoke test.
//!
//! Click New Tab → assert tab count goes 1→2. Close one of the tabs →
//! assert count back to 1. Compile-only by default.

use webkitium_harness_linux::{atspi_available, App};

#[async_std::test]
#[ignore = "requires WEBKIT_GTK_BUILD engine + running webkitium binary"]
async fn new_and_close_tab() -> anyhow::Result<()> {
    if !atspi_available() {
        eprintln!("AT-SPI bus unavailable on host; skipping");
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(std::time::Duration::from_secs(5))?;

    // TODO(linux-harness):
    //   1. find HeaderBar accessible, count children with role=TabList descendants → 1
    //   2. find Button accessible-name "New tab", trigger Action
    //   3. wait then re-count → 2
    //   4. find Button accessible-name starting with "Close tab:", trigger Action
    //   5. re-count → 1
    let _ = app.pid();

    Ok(())
}
