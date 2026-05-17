// `AppWindow` is the only window in this starter kit: a HeaderBar with
// back/forward/reload buttons and a URL entry as the title widget, and a
// WebKitGTK `WebView` filling the body.
//
// Submitting the URL entry routes through the C++ core via
// `crate::ffi::url::normalize` (proof-of-life FFI call) and hands the
// resolved URL to `webview.load_uri`.
//
// Non-goals (deliberately left out — these belong on the platform's
// features.yaml work, not in the starter kit):
// - tab strip / multiple tabs                  // features.yaml: tabs_multiple
// - sidebar                                    // features.yaml: sidebar_visibility
// - bookmarks / history / reading list panes   // features.yaml: bookmarks_persist
// - settings window                            // features.yaml: settings_open
// - downloads UI                               // features.yaml: download_to_disk
// - extensions                                 // features.yaml: extensions_runtime

use gtk4::prelude::*;
use gtk4::{Application, ApplicationWindow, Button, Entry, HeaderBar};
use webkit6::prelude::*;
use webkit6::{LoadEvent, WebView};

use crate::ffi::url::{self, NormalizeKind};

pub struct AppWindow;

impl AppWindow {
    pub fn new(app: &Application) -> ApplicationWindow {
        let webview = WebView::new();
        webview.set_vexpand(true);
        webview.set_hexpand(true);

        let url_entry = Entry::builder()
            .placeholder_text("Search or enter website")
            .hexpand(true)
            .width_request(420)
            .build();

        let back = Button::from_icon_name("go-previous-symbolic");
        back.set_tooltip_text(Some("Back"));
        back.set_sensitive(false);
        {
            let wv = webview.clone();
            back.connect_clicked(move |_| {
                if wv.can_go_back() { wv.go_back(); }
            });
        }

        let forward = Button::from_icon_name("go-next-symbolic");
        forward.set_tooltip_text(Some("Forward"));
        forward.set_sensitive(false);
        {
            let wv = webview.clone();
            forward.connect_clicked(move |_| {
                if wv.can_go_forward() { wv.go_forward(); }
            });
        }

        let reload = Button::from_icon_name("view-refresh-symbolic");
        reload.set_tooltip_text(Some("Reload"));
        {
            let wv = webview.clone();
            reload.connect_clicked(move |_| wv.reload());
        }

        // Submit: pass through C++ URL normalization. Engine id is
        // hard-coded for the starter kit; a real settings layer would
        // read whatever the platform's preferences UI persisted.
        {
            let wv = webview.clone();
            url_entry.connect_activate(move |entry| {
                let input = entry.text();
                if input.is_empty() { return; }
                match url::normalize(input.as_str(), "duckduckgo") {
                    Some((NormalizeKind::Url | NormalizeKind::Search, resolved)) => {
                        wv.load_uri(&resolved);
                    }
                    None => { /* empty/invalid — ignore */ }
                }
            });
        }

        let header = HeaderBar::new();
        header.pack_start(&back);
        header.pack_start(&forward);
        header.pack_start(&reload);
        header.set_title_widget(Some(&url_entry));

        // Mirror webview state back into chrome: button enable state +
        // URL entry text as the page navigates.
        {
            let back = back.clone();
            let forward = forward.clone();
            let entry = url_entry.clone();
            webview.connect_load_changed(move |wv, event| {
                back.set_sensitive(wv.can_go_back());
                forward.set_sensitive(wv.can_go_forward());
                if matches!(event, LoadEvent::Committed | LoadEvent::Finished) {
                    if let Some(uri) = wv.uri() {
                        entry.set_text(uri.as_str());
                    }
                }
            });
        }

        let window = ApplicationWindow::builder()
            .application(app)
            .title("Webkitium")
            .default_width(1200)
            .default_height(800)
            .build();
        window.set_titlebar(Some(&header));
        window.set_child(Some(&webview));

        // Seed with the default new-tab destination.
        webview.load_uri("about:blank");

        window
    }
}
