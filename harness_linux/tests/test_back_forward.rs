//! `back_forward_navigation` smoke test.
//!
//! Load wikipedia.org, click a link, click Back, assert the URL bar
//! reverts. Compile-only by default — pass `--ignored` to actually
//! drive the AT-SPI session.

use webkitium_harness_linux::{atspi_available, App};

#[async_std::test]
#[ignore = "requires running AT-SPI session bus + libwebkitgtk"]
async fn back_forward_navigation() -> anyhow::Result<()> {
    if !atspi_available() {
        eprintln!("AT-SPI bus unavailable on host; skipping");
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(std::time::Duration::from_secs(5))?;

    // TODO(linux-harness): drive via atspi
    //   1. find "Address bar" Entry
    //   2. type "https://en.wikipedia.org/wiki/Browser" + Enter
    //   3. wait for navigation-completed
    //   4. click a link in the WebView (use anchor accessible role)
    //   5. wait for navigation
    //   6. click "Back" button (accessible-name "Back")
    //   7. read Address-bar text == /Browser$/
    let _ = app.pid(); // silence unused-warning until step bodies land

    Ok(())
}
