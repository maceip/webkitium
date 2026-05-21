//! Phase 0 — WebKitGTK → GTK chrome event pipe (Linux equivalent of WebKitHost callbacks).

use gtk4 as gtk;
use gtk::glib::clone;
use gtk::prelude::*;
use gtk::Label;
use webkit6::prelude::*;
use webkit6::{Download, HitTestResult, LoadEvent, NetworkSession, WebView};

use std::rc::Rc;

use crate::ui::browser_window::WindowState;

/// Attach all load-bearing WebKit signals for one tab WebView.
pub fn attach_tab(
    webview: &WebView,
    state: Rc<WindowState>,
    title_label: Label,
) {
    // Load lifecycle + committed URL
    let st_load = state.clone();
    webview.connect_load_changed(move |wv, event| {
        if !st_load.is_active_tab(wv) {
            return;
        }
        st_load.on_load_changed(wv, event);
    });

    // Fine-grained progress (replaces coarse Started/Finished only)
    let st_prog = state.clone();
    webview.connect_estimated_load_progress_notify(move |wv| {
        if !st_prog.is_active_tab(wv) {
            return;
        }
        let p = wv.estimated_load_progress();
        st_prog.on_load_progress(p);
    });

    // Title (no polling)
    let st_title = state.clone();
    let title2 = title_label.clone();
    webview.connect_title_notify(move |wv| {
        let t = wv
            .title()
            .map(|g| g.to_string())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "New Tab".into());
        title2.set_text(&t);
        if st_title.is_active_tab(wv) {
            st_title.on_title_changed(&t);
        }
    });

    // Hover link → status bar
    let st_hover = state.clone();
    webview.connect_mouse_target_changed(move |wv, hit, _mods| {
        if !st_hover.is_active_tab(wv) {
            return;
        }
        st_hover.on_mouse_target(hit);
    });

    // Load failures → visible error state
    let st_fail = state.clone();
    webview.connect_load_failed(move |wv, event, failing_uri, error| {
        if !st_fail.is_active_tab(wv) {
            return false;
        }
        st_fail.on_load_failed(event, failing_uri, &error.to_string());
        false
    });

    // Site permission prompts
    let st_perm = state.clone();
    webview.connect_permission_request(move |wv, req| {
        if !st_perm.is_active_tab(wv) {
            return false;
        }
        st_perm.on_permission_request(req);
        true
    });

    // HTTP auth / passkey — defer to future WebAuthn portal; deny for now.
    webview.connect_authenticate(|_, _| false);

    // Audio playing → tab meta hint (mute UI uses set_is_muted separately)
    let st_audio = state.clone();
    webview.connect_is_playing_audio_notify(move |wv| {
        if !st_audio.is_active_tab(wv) {
            return;
        }
        st_audio.on_audio_state_changed(wv.is_playing_audio());
    });
}

/// Global download-started hook (one per window `NetworkSession`).
pub fn attach_downloads(session: &NetworkSession, state: Rc<WindowState>) {
    session.connect_download_started(move |_session, download| {
        state.on_download_started(download);
    });
}
