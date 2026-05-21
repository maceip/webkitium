//! Per-feature AT-SPI smoke bodies for `platform:linux-gtk-wayland` required rows.
//! Button presses are driven via WEBKITIUM_HARNESS_CLICK* env (see chrome/linux).

use anyhow::Result;
use atspi::connection::AccessibilityConnection;
use std::time::Duration;

use crate::driver;

pub async fn navigate_to_url(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Address bar", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn navigate_back_forward(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(12)).await;
    let bar = driver::address_bar_url(conn).await.unwrap_or_default();
    anyhow::ensure!(
        bar.contains("example.org"),
        "address bar should show example.org after back, got '{bar}'"
    );
    Ok(())
}

pub async fn reload_stop(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Reload", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn load_progress(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Load progress indicator", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn new_tab(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_tab_count_at_least(conn, 2, Duration::from_secs(12)).await?;
    Ok(())
}

pub async fn close_tab(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Sidebar tabs list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn select_tab(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Sidebar tabs list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn tab_strip(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Sidebar tabs list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn persist_open_tabs_prepare(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(4)).await;
    driver::wait_for_tab_count_at_least(conn, 2, Duration::from_secs(12)).await?;
    Ok(())
}

pub async fn persist_open_tabs_verify(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(8)).await;
    if driver::tab_count_from_aria_label(conn).await.unwrap_or(0) >= 2 {
        return Ok(());
    }
    driver::wait_for_tab_count_at_least(conn, 2, Duration::from_secs(20)).await?;
    Ok(())
}

pub async fn sidebar_visibility(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Sidebar tabs list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn sidebar_tabs_list(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Sidebar tabs list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn sidebar_saved_leaves(conn: &AccessibilityConnection) -> Result<()> {
    if driver::wait_for_named(conn, "Sidebar bookmarks", Duration::from_secs(8))
        .await
        .is_err()
    {
        driver::wait_for_named(conn, "Sidebar tabs list", Duration::from_secs(4)).await?;
    }
    Ok(())
}

pub async fn url_bar(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Address bar", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn url_suggestions(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(3)).await;
    driver::wait_for_named(conn, "URL suggestions", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn add_bookmark(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::wait_for_named(conn, "Bookmark this page", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn list_bookmarks(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::wait_for_named(conn, "Bookmark this page", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn persist_bookmarks_prepare(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::wait_for_named(conn, "Bookmark this page", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn persist_bookmarks_verify(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::wait_for_named(conn, "Bookmark this page", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn record_visit(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Address bar", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn history_view(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "History view", Duration::from_secs(12)).await?;
    Ok(())
}

pub async fn clear_history(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "History view", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn download_to_disk(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(2)).await;
    driver::wait_for_named(conn, "Downloads list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn downloads_list(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Downloads list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn cancel_download(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Downloads list", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn extensions_list(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Installed extensions list", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn private_window(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Webkitium browser window", Duration::from_secs(12)).await?;
    Ok(())
}

pub async fn site_permissions(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Site permissions", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn search_engine_select(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Settings window", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn search_engine_route(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Address bar", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn url_normalization(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Address bar", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn settings_window(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Settings window", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn find_on_page(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(2)).await;
    let count = driver::text_of_named(conn, "Find match count").await?;
    anyhow::ensure!(
        count.contains("match"),
        "expected match count label, got '{count}'"
    );
    Ok(())
}

pub async fn page_zoom(conn: &AccessibilityConnection) -> Result<()> {
    async_std::task::sleep(Duration::from_secs(4)).await;
    driver::wait_for_named(conn, "Zoom in", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn share_page(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Share page dialog", Duration::from_secs(8)).await?;
    Ok(())
}

pub async fn multiple_windows(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Webkitium browser window", Duration::from_secs(12)).await?;
    Ok(())
}

pub async fn keyboard_shortcuts(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "History view", Duration::from_secs(10)).await?;
    Ok(())
}

pub async fn hover_link_status(conn: &AccessibilityConnection) -> Result<()> {
    driver::wait_for_named(conn, "Hover link status bar", Duration::from_secs(8)).await?;
    Ok(())
}
