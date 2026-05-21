#!/usr/bin/env bash
# Regenerate harness_linux/tests/required_smokes.rs from features.yaml required rows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/harness_linux/tests/required_smokes.rs"

emit_env() {
  local id=$1
  local lines=()
  case "$id" in
    navigate_to_url)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")')
      ;;
    navigate_back_forward)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.org")')
      lines+=('("WEBKITIUM_HARNESS_NAV_URL_2", "https://example.com")')
      lines+=('("WEBKITIUM_HARNESS_NAV_URL_2_DELAY_SEC", "4")')
      lines+=('("WEBKITIUM_HARNESS_CLICK", "Back")')
      lines+=('("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "9")')
      ;;
    reload_stop)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")')
      lines+=('("WEBKITIUM_HARNESS_CLICK", "Reload")')
      ;;
    load_progress|record_visit|url_bar|url_normalization|search_engine_route)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")')
      ;;
    new_tab)
      lines+=('("WEBKITIUM_HARNESS_CLICK", "New tab")')
      lines+=('("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "1")')
      ;;
    close_tab)
      lines+=('("WEBKITIUM_HARNESS_CLICK_SEQ", "New tab,Close tab")')
      ;;
    select_tab|tab_strip)
      lines+=('("WEBKITIUM_HARNESS_CLICK", "New tab")')
      ;;
    add_bookmark|list_bookmarks|persist_bookmarks)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")')
      lines+=('("WEBKITIUM_HARNESS_CLICK", "Bookmark this page")')
      lines+=('("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "2")')
      ;;
    download_to_disk|downloads_list|cancel_download)
      lines+=('("WEBKITIUM_HARNESS_CLICK", "Downloads")')
      ;;
    url_suggestions)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")')
      lines+=('("WEBKITIUM_HARNESS_TYPE_PREFIX", "exam")')
      ;;
    search_engine_route)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "weather today")')
      ;;
    url_normalization)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "example.com")')
      ;;
    find_on_page)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "data:text/plain,foo bar foo baz foo")')
      lines+=('("WEBKITIUM_HARNESS_OPEN_FIND", "1")')
      lines+=('("WEBKITIUM_HARNESS_FIND_QUERY", "foo")')
      ;;
    page_zoom)
      lines+=('("WEBKITIUM_HARNESS_CLICK_SEQ", "Page settings menu,Zoom in")')
      ;;
    sidebar_saved_leaves)
      lines+=('("WEBKITIUM_HARNESS_SIDEBAR_STACK", "bookmarks")')
      ;;
    history_view|keyboard_shortcuts)
      lines+=('("WEBKITIUM_HARNESS_OPEN_HISTORY", "1")')
      ;;
    clear_history)
      lines+=('("WEBKITIUM_HARNESS_OPEN_HISTORY", "1")')
      lines+=('("WEBKITIUM_HARNESS_CLICK", "Clear history")')
      lines+=('("WEBKITIUM_HARNESS_CLICK_DELAY_SEC", "2")')
      ;;
    extensions_list)
      lines+=('("WEBKITIUM_HARNESS_OPEN_EXTENSIONS", "1")')
      ;;
    private_window)
      lines+=('("WEBKITIUM_HARNESS_PRIVATE", "1")')
      ;;
    site_permissions)
      lines+=('("WEBKITIUM_HARNESS_OPEN_SITE_PERMISSIONS", "1")')
      ;;
    search_engine_select|settings_window)
      lines+=('("WEBKITIUM_HARNESS_OPEN_SETTINGS", "1")')
      ;;
    share_page)
      lines+=('("WEBKITIUM_HARNESS_OPEN_SHARE", "1")')
      ;;
    multiple_windows)
      lines+=('("WEBKITIUM_HARNESS_SECOND_WINDOW", "1")')
      ;;
    persist_open_tabs)
      lines+=('("WEBKITIUM_HARNESS_NAV_URL", "https://example.com")')
      lines+=('("WEBKITIUM_HARNESS_EXTRA_TABS", "1")')
      lines+=('("WEBKITIUM_HARNESS_EXTRA_TAB_URL", "https://example.org")')
      ;;
  esac
  if ((${#lines[@]} == 0)); then
    echo '    let app = App::spawn()?;'
    return
  fi
  echo -n '    let app = App::spawn_with_env(&['
  local first=1
  for L in "${lines[@]}"; do
    if ((first)); then first=0; else echo -n ','; fi
    echo -n "$L"
  done
  echo '])?;'
}

REQUIRED=(
  navigate_to_url navigate_back_forward reload_stop load_progress new_tab close_tab
  select_tab tab_strip sidebar_visibility sidebar_tabs_list sidebar_saved_leaves
  url_bar url_suggestions add_bookmark list_bookmarks record_visit download_to_disk
  downloads_list cancel_download search_engine_route url_normalization find_on_page
  page_zoom history_view clear_history extensions_list private_window site_permissions
  search_engine_select settings_window share_page multiple_windows keyboard_shortcuts
)

{
  echo '//! Required platform:linux-gtk-wayland AT-SPI smokes (generated).'
  echo ''
  echo 'use std::time::Duration;'
  echo 'use webkitium_harness_linux::{atspi_available, smokes, App};'
  echo ''

  for id in "${REQUIRED[@]}"; do
    fn="${id//-/_}"
    echo "#[async_std::test]"
    echo '#[ignore = "requires display + AT-SPI + webkitium binary"]'
    echo "async fn ${fn}_smoke() -> anyhow::Result<()> {"
    echo '    if !atspi_available() { return Ok(()); }'
    emit_env "$id"
    echo '    app.wait_ready(Duration::from_secs(15))?;'
    echo '    async_std::task::sleep(Duration::from_millis(800)).await;'
    echo '    let conn = App::connection().await?;'
    echo "    smokes::${fn}(&conn).await?;"
    echo '    Ok(())'
    echo '}'
    echo ''
  done

  cat <<'PERSIST'
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
PERSIST
} >"$OUT"

rm -f "$ROOT/harness_linux/tests"/test_*.rs
echo "generated $OUT (${#REQUIRED[@]} smokes + 2 persistence tests)"
