//! AT-SPI helpers — find widgets by stable `Aria::Label` (maps to accessible name).

use anyhow::{bail, Context, Result};
use atspi::connection::AccessibilityConnection;
use atspi::proxy::accessible::{AccessibleProxy, ObjectRefExt};
use atspi::proxy::action::ActionProxy;
use atspi::proxy::component::ComponentProxy;
use atspi::proxy::device_event_controller::DeviceEventControllerProxy;
use atspi::proxy::editable_text::EditableTextProxy;
use atspi::proxy::text::TextProxy;
use atspi::ObjectRef;
use atspi_common::CoordType;
use std::time::{Duration, Instant};

const REGISTRY_DEST: &str = "org.a11y.atspi.Registry";
const A11Y_BUS_DEST: &str = "org.a11y.Bus";
const ROOT_PATH: &str = "/org/a11y/atspi/accessible/root";
const DEVICE_EVENT_PATH: &str = "/org/a11y/atspi/DeviceEventController";

fn valid_object_ref(obj: &ObjectRef) -> bool {
    let n = obj.name.as_str();
    !n.is_empty() && (n.starts_with(':') || n.contains('.'))
}

async fn desktop(conn: &AccessibilityConnection) -> Result<AccessibleProxy<'_>> {
    AccessibleProxy::builder(conn.connection())
        .destination(REGISTRY_DEST)?
        .path(ROOT_PATH)?
        .build()
        .await
        .context("desktop AccessibleProxy")
}

async fn proxy_for<'a>(
    conn: &'a AccessibilityConnection,
    obj: &'a ObjectRef,
) -> Result<AccessibleProxy<'a>> {
    obj.as_accessible_proxy(conn.connection())
        .await
        .context("AccessibleProxy")
}

/// Wait until an accessible subtree exposes `name` (GTK `aria-label`).
pub async fn wait_for_named(
    conn: &AccessibilityConnection,
    name: &str,
    timeout: Duration,
) -> Result<ObjectRef> {
    let start = Instant::now();
    loop {
        if let Ok(Some(node)) = find_named(conn, name).await {
            return Ok(node);
        }
        if start.elapsed() >= timeout {
            bail!("timed out waiting for accessible named '{name}'");
        }
        async_std::task::sleep(Duration::from_millis(150)).await;
    }
}

/// Depth-first search from desktop root for the first node whose name matches.
pub async fn find_named(conn: &AccessibilityConnection, name: &str) -> Result<Option<ObjectRef>> {
    let root = desktop(conn).await?;
    let mut stack = Vec::new();
    for child in root.get_children().await.unwrap_or_default() {
        if valid_object_ref(&child) {
            stack.push(child);
        }
    }
    while let Some(obj) = stack.pop() {
        if !valid_object_ref(&obj) {
            continue;
        }
        let proxy = match proxy_for(conn, &obj).await {
            Ok(p) => p,
            Err(_) => continue,
        };
        if proxy.name().await.unwrap_or_default() == name {
            return Ok(Some(obj));
        }
        for child in proxy.get_children().await.unwrap_or_default() {
            if valid_object_ref(&child) {
                stack.push(child);
            }
        }
    }
    Ok(None)
}

async fn try_do_action(conn: &AccessibilityConnection, obj: &ObjectRef) -> bool {
    let Ok(node) = proxy_for(conn, obj).await else {
        return false;
    };
    let action = ActionProxy::from(node.inner().clone());
    action.do_action(0).await.is_ok()
}

async fn click_at_component(conn: &AccessibilityConnection, obj: &ObjectRef) -> Result<()> {
    let node = proxy_for(conn, obj).await?;
    let comp = ComponentProxy::from(node.inner().clone());
    let _ = comp.grab_focus().await;
    let (x, y, w, h) = comp
        .get_extents(CoordType::Screen)
        .await
        .context("get_extents")?;
    let cx = x + w / 2;
    let cy = y + h / 2;
    let ctrl = DeviceEventControllerProxy::builder(conn.connection())
        .destination(A11Y_BUS_DEST)?
        .path(DEVICE_EVENT_PATH)?
        .build()
        .await
        .context("DeviceEventControllerProxy")?;
    for evt in ["b1p", "b1r", "b1c"] {
        ctrl.generate_mouse_event(cx, cy, evt).await.ok();
    }
    Ok(())
}

/// Click a push-button (or similar) by accessible name (default action).
pub async fn click_named(conn: &AccessibilityConnection, name: &str) -> Result<()> {
    let obj = wait_for_named(conn, name, Duration::from_secs(12)).await?;
    if try_do_action(conn, &obj).await {
        return Ok(());
    }
    let node = proxy_for(conn, &obj).await?;
    for child in node.get_children().await.unwrap_or_default() {
        if valid_object_ref(&child) && try_do_action(conn, &child).await {
            return Ok(());
        }
    }
    click_at_component(conn, &obj).await?;
    async_std::task::sleep(Duration::from_millis(200)).await;
    Ok(())
}

/// Set text on an editable node with `name` (GTK Entry).
pub async fn set_text_named(
    conn: &AccessibilityConnection,
    name: &str,
    text: &str,
) -> Result<()> {
    let obj = wait_for_named(conn, name, Duration::from_secs(12)).await?;
    let node = proxy_for(conn, &obj).await?;
    let edit = EditableTextProxy::from(node.inner().clone());
    if edit.set_text_contents(text).await.is_ok() {
        return Ok(());
    }
    // GTK 4 entries often expose insert/delete without SetTextContents.
    let _ = edit.delete_text(0, 4096).await;
    edit.insert_text(0, text, text.len() as i32)
        .await
        .context("insert_text")?;
    Ok(())
}

/// Current URL shown in the address field (harness sets `Aria::Description` on load).
pub async fn address_bar_url(conn: &AccessibilityConnection) -> Result<String> {
    let obj = wait_for_named(conn, "Address bar", Duration::from_secs(8)).await?;
    let node = proxy_for(conn, &obj).await?;
    if let Ok(desc) = node.description().await {
        if !desc.is_empty() {
            return Ok(desc);
        }
    }
    visible_text_named(conn, "Address bar").await
}

/// Read accessible name text from a node.
pub async fn text_of_named(conn: &AccessibilityConnection, name: &str) -> Result<String> {
    let obj = wait_for_named(conn, name, Duration::from_secs(12)).await?;
    let node = proxy_for(conn, &obj).await?;
    Ok(node.name().await.unwrap_or_default())
}

/// Type URL in the address bar and activate (Return / default action).
pub async fn submit_address_bar(conn: &AccessibilityConnection, url: &str) -> Result<()> {
    set_text_named(conn, "Address bar", url).await?;
    let obj = wait_for_named(conn, "Address bar", Duration::from_secs(4)).await?;
    let node = proxy_for(conn, &obj).await?;
    let action = ActionProxy::from(node.inner().clone());
    let _ = action.do_action(0).await;
    async_std::task::sleep(Duration::from_millis(800)).await;
    Ok(())
}

/// Visible text for a named accessible (uses Text interface when available).
pub async fn visible_text_named(conn: &AccessibilityConnection, name: &str) -> Result<String> {
    let obj = wait_for_named(conn, name, Duration::from_secs(12)).await?;
    let node = proxy_for(conn, &obj).await?;
    let text = TextProxy::from(node.inner().clone());
    let n = text.character_count().await.unwrap_or(0);
    if n > 0 {
        return text.get_text(0, n).await.context("get_text");
    }
    Ok(node.name().await.unwrap_or_default())
}

async fn count_named_prefix(conn: &AccessibilityConnection, prefix: &str) -> Result<u32> {
    let root = desktop(conn).await?;
    let mut stack = Vec::new();
    let mut n = 0u32;
    for child in root.get_children().await.unwrap_or_default() {
        if valid_object_ref(&child) {
            stack.push(child);
        }
    }
    while let Some(obj) = stack.pop() {
        if !valid_object_ref(&obj) {
            continue;
        }
        let proxy = match proxy_for(conn, &obj).await {
            Ok(p) => p,
            Err(_) => continue,
        };
        let name = proxy.name().await.unwrap_or_default();
        if name.starts_with(prefix) {
            n += 1;
        }
        for child in proxy.get_children().await.unwrap_or_default() {
            if valid_object_ref(&child) {
                stack.push(child);
            }
        }
    }
    Ok(n)
}

/// Count open tabs via sidebar row labels (`Select tab: …`).
pub async fn count_sidebar_tabs(conn: &AccessibilityConnection) -> Result<u32> {
    let n = count_named_prefix(conn, "Select tab:").await?;
    if n > 0 {
        return Ok(n);
    }
    // Fallback: direct ListBox children (older AT-SPI shapes).
    if let Ok(obj) = find_named(conn, "Sidebar tabs list").await.and_then(|o| o.ok_or_else(|| anyhow::anyhow!("missing"))) {
        let node = proxy_for(conn, &obj).await?;
        let direct = node
            .get_children()
            .await
            .unwrap_or_default()
            .into_iter()
            .filter(|c| valid_object_ref(c))
            .count();
        return Ok(direct as u32);
    }
    Ok(0)
}

pub async fn tab_count_from_aria_label(conn: &AccessibilityConnection) -> Result<u32> {
    let root = desktop(conn).await?;
    let mut stack: Vec<ObjectRef> = root
        .get_children()
        .await
        .unwrap_or_default()
        .into_iter()
        .filter(|c| valid_object_ref(c))
        .collect();
    while let Some(obj) = stack.pop() {
        if !valid_object_ref(&obj) {
            continue;
        }
        let Ok(proxy) = proxy_for(conn, &obj).await else {
            continue;
        };
        let name = proxy.name().await.unwrap_or_default();
        if name.starts_with("Sidebar tab count") {
            let digits: String = name.chars().filter(|c| c.is_ascii_digit()).collect();
            if let Ok(n) = digits.parse::<u32>() {
                return Ok(n);
            }
        }
        for child in proxy.get_children().await.unwrap_or_default() {
            if valid_object_ref(&child) {
                stack.push(child);
            }
        }
    }
    Ok(0)
}

/// Wait until the sidebar shows at least `min` tabs.
pub async fn wait_for_tab_count_at_least(
    conn: &AccessibilityConnection,
    min: u32,
    timeout: Duration,
) -> Result<()> {
    let start = Instant::now();
    loop {
        let n = count_sidebar_tabs(conn).await.unwrap_or(0);
        let label_n = tab_count_from_aria_label(conn).await.unwrap_or(0);
        if n.max(label_n) >= min {
            return Ok(());
        }
        if start.elapsed() >= timeout {
            bail!("timed out waiting for >= {min} tabs in sidebar");
        }
        async_std::task::sleep(Duration::from_millis(200)).await;
    }
}

/// Whether a named control reports the `Enabled` state (GTK sensitive button).
pub async fn button_enabled(conn: &AccessibilityConnection, name: &str) -> Result<bool> {
    let obj = wait_for_named(conn, name, Duration::from_secs(8)).await?;
    let node = proxy_for(conn, &obj).await?;
    let states = node.get_state().await.unwrap_or_default();
    Ok(states.is_empty() || states.contains(atspi::State::Enabled))
}
