//! `bookmarks_persist` smoke test.
//!
//! Load a URL, click the bookmark star, assert star is filled.
//! Restart shell with the same profile dir, re-load that URL, assert
//! star is filled at startup (persistence proof).

use webkitium_harness_linux::{atspi_available, App};

#[async_std::test]
#[ignore = "requires WEBKIT_GTK_BUILD engine + running webkitium binary"]
async fn bookmark_persists_across_restart() -> anyhow::Result<()> {
    if !atspi_available() {
        eprintln!("AT-SPI bus unavailable on host; skipping");
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(std::time::Duration::from_secs(5))?;

    // TODO(linux-harness):
    //   1. type a URL + Enter, wait for navigation
    //   2. find Button "Bookmark this page" → trigger
    //   3. read its image accessible-name; expect "starred-symbolic"
    //   4. drop(app); spawn second instance against same profile path
    //      (needs `App::spawn_in(path)`)
    //   5. re-navigate to same URL
    //   6. read star icon → still starred
    let _ = app.pid();

    Ok(())
}
