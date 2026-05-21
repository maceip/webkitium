//! Required platform:linux-gtk-wayland AT-SPI smokes (generated).

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, smokes, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn navigate_to_url_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::navigate_to_url(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn navigate_back_forward_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.org"),("WEBKITIUM_HARNESS_NAV_URL_2", "https://example.com"),("WEBKITIUM_HARNESS_NAV_URL_2_DELAY_SEC", "4"),("WEBKITIUM_HARNESS_CLICK", "Back"),("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "9")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::navigate_back_forward(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn reload_stop_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com"),("WEBKITIUM_HARNESS_CLICK", "Reload")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::reload_stop(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn load_progress_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::load_progress(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn new_tab_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK", "New tab"),("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::new_tab(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn close_tab_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK_SEQ", "New tab,Close tab")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::close_tab(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn select_tab_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK", "New tab")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::select_tab(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn tab_strip_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK", "New tab")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::tab_strip(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn sidebar_visibility_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::sidebar_visibility(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn sidebar_tabs_list_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::sidebar_tabs_list(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn sidebar_saved_leaves_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_SIDEBAR_STACK", "bookmarks")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::sidebar_saved_leaves(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn url_bar_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::url_bar(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn url_suggestions_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com"),("WEBKITIUM_HARNESS_TYPE_PREFIX", "exam")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::url_suggestions(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn add_bookmark_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com"),("WEBKITIUM_HARNESS_CLICK", "Bookmark this page"),("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "2")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::add_bookmark(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn list_bookmarks_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com"),("WEBKITIUM_HARNESS_CLICK", "Bookmark this page"),("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "2")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::list_bookmarks(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn record_visit_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::record_visit(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn download_to_disk_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK", "Downloads")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::download_to_disk(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn downloads_list_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK", "Downloads")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::downloads_list(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn cancel_download_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK", "Downloads")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::cancel_download(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn search_engine_route_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::search_engine_route(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn url_normalization_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::url_normalization(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn find_on_page_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_NAV_URL", "data:text/plain,foo bar foo baz foo"),("WEBKITIUM_HARNESS_OPEN_FIND", "1"),("WEBKITIUM_HARNESS_FIND_QUERY", "foo")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::find_on_page(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn page_zoom_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_CLICK_SEQ", "Page settings menu,Zoom in")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::page_zoom(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn history_view_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_HISTORY", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::history_view(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn clear_history_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_HISTORY", "1"),("WEBKITIUM_HARNESS_CLICK", "Clear history"),("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "2")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::clear_history(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn extensions_list_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_EXTENSIONS", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::extensions_list(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn private_window_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_PRIVATE", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::private_window(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn site_permissions_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_SITE_PERMISSIONS", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::site_permissions(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn search_engine_select_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_SETTINGS", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::search_engine_select(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn settings_window_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_SETTINGS", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::settings_window(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn share_page_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_SHARE", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::share_page(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn multiple_windows_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_SECOND_WINDOW", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::multiple_windows(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn keyboard_shortcuts_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[("WEBKITIUM_HARNESS_OPEN_HISTORY", "1")])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let conn = App::connection().await?;
    smokes::keyboard_shortcuts(&conn).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn persist_open_tabs_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let mut app = App::spawn_with_env(&[
        ("WEBKITIUM_HARNESS_NAV_URL", "https://example.com"),
        ("WEBKITIUM_HARNESS_EXTRA_TABS", "1"),
        ("WEBKITIUM_HARNESS_EXTRA_TAB_URL", "https://example.org"),
        ("WEBKITIUM_HARNESS_QUIT_MS", "8"),
    ])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let profile = app.profile_path().to_path_buf();
    let conn = App::connection().await?;
    smokes::persist_open_tabs_prepare(&conn).await?;
    drop(app);
    async_std::task::sleep(Duration::from_secs(5)).await;
    let app2 = App::spawn_with_profile_dir(&profile)?;
    app2.wait_ready(Duration::from_secs(25))?;
    let conn2 = App::connection().await?;
    smokes::persist_open_tabs_verify(&conn2).await?;
    Ok(())
}

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn persist_bookmarks_smoke() -> anyhow::Result<()> {
    if !atspi_available() { return Ok(()); }
    let app = App::spawn_with_env(&[
        ("WEBKITIUM_HARNESS_NAV_URL", "https://example.com"),
        ("WEBKITIUM_HARNESS_CLICK", "Bookmark this page"),
    ])?;
    app.wait_ready(Duration::from_secs(15))?;
    async_std::task::sleep(Duration::from_millis(800)).await;
    let profile = app.profile_path().to_path_buf();
    let conn = App::connection().await?;
    smokes::persist_bookmarks_prepare(&conn).await?;
    drop(app);
    async_std::task::sleep(Duration::from_secs(3)).await;
    let app2 = App::spawn_with_profile_dir(&profile)?;
    app2.wait_ready(Duration::from_secs(15))?;
    let conn2 = App::connection().await?;
    smokes::persist_bookmarks_verify(&conn2).await?;
    Ok(())
}
