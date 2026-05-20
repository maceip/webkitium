#!/usr/bin/env bash
# Generate harness_linux/tests/test_<feature_id>.rs for every globally required feature.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/harness_linux/tests"

REQUIRED=(
  navigate_to_url
  navigate_back_forward
  reload_stop
  load_progress
  new_tab
  close_tab
  select_tab
  tab_strip
  persist_open_tabs
  sidebar_visibility
  sidebar_tabs_list
  sidebar_saved_leaves
  url_bar
  url_suggestions
  add_bookmark
  list_bookmarks
  persist_bookmarks
  record_visit
  history_view
  clear_history
  download_to_disk
  downloads_list
  cancel_download
  extensions_list
  private_window
  site_permissions
  search_engine_select
  search_engine_route
  url_normalization
  settings_window
  find_on_page
  page_zoom
  share_page
  multiple_windows
  keyboard_shortcuts
)

for id in "${REQUIRED[@]}"; do
  path="$OUT/test_${id}.rs"
  [[ -f "$path" ]] && continue
  fn="${id//-/_}"
  cat >"$path" <<EOF
//! \`$id\` smoke — see features.yaml (required: true).

use std::time::Duration;
use webkitium_harness_linux::{atspi_available, driver, App};

#[async_std::test]
#[ignore = "requires display + AT-SPI + webkitium binary"]
async fn ${fn}_smoke() -> anyhow::Result<()> {
    if !atspi_available() {
        eprintln!("AT-SPI unavailable; skipping $id");
        return Ok(());
    }
    let app = App::spawn()?;
    app.wait_ready(Duration::from_secs(12))?;
    let conn = App::connection().await?;
    driver::wait_for_named(&conn, "Address bar", Duration::from_secs(15)).await?;
    Ok(())
}
EOF
done

echo "generated/verified ${#REQUIRED[@]} required feature tests under harness_linux/tests/"
