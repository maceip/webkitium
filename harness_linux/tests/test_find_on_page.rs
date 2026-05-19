//! `find_on_page` smoke test.
//!
//! Load a known page (data: URI with literal text), Ctrl+F to open the
//! find revealer, type a substring known to match, assert match-count
//! label reads "N matches" with N ≥ 1.

use webkitium_harness_linux::{atspi_available, App};

#[async_std::test]
#[ignore = "requires WEBKIT_GTK_BUILD engine + running webkitium binary"]
async fn find_on_page_reports_match_count() -> anyhow::Result<()> {
    if !atspi_available() {
        eprintln!("AT-SPI bus unavailable on host; skipping");
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(std::time::Duration::from_secs(5))?;

    // TODO(linux-harness):
    //   1. navigate to data:text/plain,foo bar foo baz foo
    //   2. send Ctrl+F via virtual keyboard or trigger win.find action
    //   3. find Entry "Find in page", type "foo"
    //   4. read Label accessible-name "Find match count" → "3 matches"
    let _ = app.pid();

    Ok(())
}
