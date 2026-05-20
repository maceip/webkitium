//! AT-SPI helpers — find widgets by stable `Aria::Label` (maps to accessible name).

use anyhow::{bail, Context, Result};
use atspi::connection::AccessibilityConnection;
use atspi::proxy::accessible::{AccessibleProxy, ObjectRefExt};
use atspi::proxy::action::ActionProxy;
use atspi::proxy::editable_text::EditableTextProxy;
use atspi::ObjectRef;
use std::time::{Duration, Instant};

const REGISTRY_DEST: &str = "org.a11y.atspi.Registry";
const ROOT_PATH: &str = "/org/a11y/atspi/accessible/root";

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

/// Click a push-button (or similar) by accessible name (default action).
pub async fn click_named(conn: &AccessibilityConnection, name: &str) -> Result<()> {
    let obj = wait_for_named(conn, name, Duration::from_secs(12)).await?;
    let node = proxy_for(conn, &obj).await?;
    let action = ActionProxy::from(node.inner().clone());
    action.do_action(0).await.context("do_action")?;
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
    edit.set_text_contents(text)
        .await
        .context("set_text_contents")?;
    Ok(())
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

/// Whether a named control reports the `Enabled` state (GTK sensitive button).
pub async fn button_enabled(conn: &AccessibilityConnection, name: &str) -> Result<bool> {
    let obj = wait_for_named(conn, name, Duration::from_secs(8)).await?;
    let node = proxy_for(conn, &obj).await?;
    let states = node.get_state().await.unwrap_or_default();
    Ok(states.is_empty() || states.contains(atspi::State::Enabled))
}
