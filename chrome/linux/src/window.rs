// AppWindow — the only window of the Webkitium GTK shell.
//
// Five features wired in this revision (each tagged with its
// features.yaml id):
//   * `back_forward_navigation` — HeaderBar buttons bound to the active
//     tab's WebView.
//   * `multiple_tabs`           — gtk::Notebook + per-tab WebView, new-tab
//                                 button, close-X on labels, Ctrl+T / Ctrl+W.
//   * `url_autocomplete`        — gtk::Popover anchored to the URL Entry,
//                                 driven by wk_suggestions_query.
//   * `bookmarks_persist`       — star toggle + bookmarks bar driven by
//                                 wk_suggestions_set_bookmarked and
//                                 wk_suggestions_bookmarks_flat.
//   * `find_on_page`            — gtk::Revealer over webkit::FindController.
//
// Decision: gtk::Notebook for tabs (Chromium's Linux shell uses the same
// pattern) — keeps the chrome native, lets the platform OS handle drag
// reorder, focus management, accessibility tree out of the box.
//
// All chrome widgets carry accessible labels so the harness in
// `harness_linux/` can find them via AT-SPI.

use gtk4 as gtk;
use gtk::accessible::Property as Aria;
use gtk::gdk;
use gtk::glib::{self, clone};
use gtk::prelude::*;
use gtk::{
    AccessibleRole, Application, ApplicationWindow, Box as GtkBox, Button, CssProvider, Entry,
    EventControllerKey, HeaderBar, Label, ListBox, ListBoxRow, Notebook, Orientation, Popover,
    PositionType, Revealer, RevealerTransitionType, ScrolledWindow,
};
use webkit6::prelude::*;
use webkit6::{FindOptions, LoadEvent, WebView};

use std::path::PathBuf;
use std::rc::Rc;

use crate::ffi::suggestions::{Index, Suggestion, SuggestionKind};
use crate::ffi::url::{self, NormalizeKind};

/// Engine id passed into the C++ URL normalizer. Real settings UI would
/// persist this; the starter kit hard-codes the privacy default.
const SEARCH_ENGINE_ID: &str = "duckduckgo";

/// CSS rule that gives the URL entry's primary icon a blue tint plus a
/// soft outward glow — only kicks in when the entry carries the
/// `.secure-lock` class AND has a primary icon set (we toggle the icon
/// presence based on `https://`).
const SECURE_LOCK_CSS: &str = "
entry.secure-lock image.left {
  color: #3B82F6;
  filter: drop-shadow(0 0 4px rgba(59, 130, 246, 0.75))
          drop-shadow(0 0 8px rgba(59, 130, 246, 0.45));
}
";

/// Install the secure-lock CSS once per display. Safe to call multiple
/// times — GTK4 de-dupes provider lookups but we still avoid the work.
fn install_secure_lock_css() {
    use std::cell::Cell;
    thread_local! {
        static INSTALLED: Cell<bool> = Cell::new(false);
    }
    INSTALLED.with(|i| {
        if i.get() { return; }
        let Some(display) = gdk::Display::default() else { return; };
        let provider = CssProvider::new();
        provider.load_from_string(SECURE_LOCK_CSS);
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
        i.set(true);
    });
}

/// Resolve the suggestions DB path. Honours `WEBKITIUM_PROFILE_DIR` for
/// harness test isolation; falls back to XDG.
fn profile_db_path() -> Option<PathBuf> {
    if let Ok(dir) = std::env::var("WEBKITIUM_PROFILE_DIR") {
        let p = PathBuf::from(dir);
        std::fs::create_dir_all(&p).ok()?;
        return Some(p.join("suggestions.db"));
    }
    let base = std::env::var("XDG_DATA_HOME")
        .ok()
        .map(PathBuf::from)
        .or_else(|| std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(".local/share")))?;
    let dir = base.join("Webkitium");
    std::fs::create_dir_all(&dir).ok()?;
    Some(dir.join("suggestions.db"))
}

pub struct AppWindow;

impl AppWindow {
    pub fn new(app: &Application) -> ApplicationWindow {
        // ---- 1. Open the suggestions DB. ----
        let index: Option<Rc<Index>> = profile_db_path()
            .and_then(|p| Index::open(p.to_string_lossy().as_ref()))
            .map(Rc::new);

        // Install secure-lock CSS once per display before any widgets show.
        install_secure_lock_css();

        // ---- 2. Build chrome widgets. ----
        let notebook = Notebook::builder()
            .scrollable(true)
            .show_border(false)
            .build();

        let url_entry = Entry::builder()
            .placeholder_text("Search or enter website")
            .hexpand(true)
            .width_request(420)
            .build();
        url_entry.update_property(&[Aria::Label("Address bar")]);
        // CSS class is always present; the primary icon is what we toggle.
        url_entry.add_css_class("secure-lock");

        let back = Button::from_icon_name("go-previous-symbolic");
        back.set_tooltip_text(Some("Back"));
        back.set_sensitive(false);
        back.update_property(&[Aria::Label("Back")]);

        let forward = Button::from_icon_name("go-next-symbolic");
        forward.set_tooltip_text(Some("Forward"));
        forward.set_sensitive(false);
        forward.update_property(&[Aria::Label("Forward")]);

        let reload = Button::from_icon_name("view-refresh-symbolic");
        reload.set_tooltip_text(Some("Reload"));
        reload.update_property(&[Aria::Label("Reload")]);

        let bookmark_btn = Button::from_icon_name("non-starred-symbolic");
        bookmark_btn.set_tooltip_text(Some("Bookmark this page"));
        bookmark_btn.update_property(&[Aria::Label("Bookmark this page")]);

        let new_tab_btn = Button::from_icon_name("tab-new-symbolic");
        new_tab_btn.set_tooltip_text(Some("New tab"));
        new_tab_btn.update_property(&[Aria::Label("New tab")]);

        let header = HeaderBar::new();
        header.pack_start(&back);
        header.pack_start(&forward);
        header.pack_start(&reload);
        header.set_title_widget(Some(&url_entry));
        header.pack_end(&new_tab_btn);
        header.pack_end(&bookmark_btn);

        // ---- 3. Autocomplete popover. ----
        let suggestions_list = ListBox::builder()
            .selection_mode(gtk::SelectionMode::Single)
            .build();
        let scroll = ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Never)
            .vscrollbar_policy(gtk::PolicyType::Automatic)
            .min_content_width(420)
            .max_content_height(320)
            .propagate_natural_height(true)
            .child(&suggestions_list)
            .build();
        let suggestions_popover = Popover::builder()
            .autohide(false)
            .has_arrow(false)
            .position(PositionType::Bottom)
            .child(&scroll)
            .build();
        suggestions_popover.set_parent(&url_entry);

        // ---- 4. Bookmarks bar. ----
        let bookmarks_inner = GtkBox::new(Orientation::Horizontal, 4);
        bookmarks_inner.set_margin_start(8);
        bookmarks_inner.set_margin_end(8);
        bookmarks_inner.set_margin_top(2);
        bookmarks_inner.set_margin_bottom(2);
        let bookmarks_scroll = ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Automatic)
            .vscrollbar_policy(gtk::PolicyType::Never)
            .child(&bookmarks_inner)
            .build();
        bookmarks_scroll.update_property(&[Aria::Label("Bookmarks bar")]);

        // ---- 5. Find revealer. ----
        let find_entry = Entry::builder()
            .placeholder_text("Find in page")
            .width_request(280)
            .build();
        find_entry.update_property(&[Aria::Label("Find in page")]);
        let find_prev = Button::from_icon_name("go-up-symbolic");
        find_prev.update_property(&[Aria::Label("Find previous")]);
        let find_next = Button::from_icon_name("go-down-symbolic");
        find_next.update_property(&[Aria::Label("Find next")]);
        let find_close = Button::from_icon_name("window-close-symbolic");
        find_close.update_property(&[Aria::Label("Close find bar")]);
        let find_count = Label::new(Some(""));
        find_count.set_margin_start(8);
        find_count.set_margin_end(8);
        find_count.update_property(&[Aria::Label("Find match count")]);
        let find_row = GtkBox::new(Orientation::Horizontal, 4);
        find_row.set_margin_start(8);
        find_row.set_margin_end(8);
        find_row.set_margin_top(4);
        find_row.set_margin_bottom(4);
        find_row.append(&find_entry);
        find_row.append(&find_prev);
        find_row.append(&find_next);
        find_row.append(&find_count);
        find_row.append(&find_close);
        let find_revealer = Revealer::builder()
            .transition_type(RevealerTransitionType::SlideDown)
            .transition_duration(150)
            .reveal_child(false)
            .child(&find_row)
            .build();

        // ---- 6. Body layout. ----
        let body = GtkBox::new(Orientation::Vertical, 0);
        body.append(&bookmarks_scroll);
        body.append(&find_revealer);
        body.append(&notebook);
        notebook.set_vexpand(true);

        // ---- 7. State plumbing. ----
        //
        // The `Notebook` page widget is the WebView itself — that's the
        // canonical gtk-rs pattern and gives us access to the active
        // tab's WebView via `nth_page(current_page())`.

        let state = WindowState {
            notebook: notebook.clone(),
            url_entry: url_entry.clone(),
            back_btn: back.clone(),
            fwd_btn: forward.clone(),
            bookmark_btn: bookmark_btn.clone(),
            bookmarks_bar: bookmarks_inner.clone(),
            suggestions_popover: suggestions_popover.clone(),
            suggestions_list: suggestions_list.clone(),
            find_revealer: find_revealer.clone(),
            find_entry: find_entry.clone(),
            find_count: find_count.clone(),
            index: index.clone(),
        };
        let state = Rc::new(state);

        // ---- 8. Wire signals. ----
        //
        // (a) Back / forward / reload — operate on the active tab.
        back.connect_clicked(clone!(@strong state => move |_| {
            if let Some(wv) = state.active_webview() {
                if wv.can_go_back() { wv.go_back(); }
            }
        }));
        forward.connect_clicked(clone!(@strong state => move |_| {
            if let Some(wv) = state.active_webview() {
                if wv.can_go_forward() { wv.go_forward(); }
            }
        }));
        reload.connect_clicked(clone!(@strong state => move |_| {
            if let Some(wv) = state.active_webview() { wv.reload(); }
        }));

        // (b) URL entry submit — normalise + load into active tab.
        url_entry.connect_activate(clone!(@strong state => move |entry| {
            let input = entry.text();
            if input.is_empty() { return; }
            if let Some((NormalizeKind::Url | NormalizeKind::Search, resolved))
                = url::normalize(input.as_str(), SEARCH_ENGINE_ID)
            {
                if let Some(wv) = state.active_webview() {
                    wv.load_uri(&resolved);
                }
                state.suggestions_popover.popdown();
            }
        }));

        // (c) URL entry typing — autocomplete popover.
        url_entry.connect_changed(clone!(@strong state => move |entry| {
            // Only react when the entry actually has focus — `set_text`
            // from the load-changed signal also fires `changed`, and we
            // don't want to pop the suggestions over a navigation
            // event.
            if !entry.has_focus() {
                return;
            }
            let q = entry.text();
            state.refresh_suggestions(q.as_str());
        }));

        // Arrow keys on the URL entry navigate the popover list; Esc
        // dismisses.
        let key_ctl = EventControllerKey::new();
        key_ctl.connect_key_pressed(clone!(@strong state => move |_, key, _code, _mods| {
            use gtk::gdk::Key;
            match key {
                Key::Down => { state.suggestion_move(1); glib::Propagation::Stop }
                Key::Up   => { state.suggestion_move(-1); glib::Propagation::Stop }
                Key::Escape => {
                    state.suggestions_popover.popdown();
                    glib::Propagation::Stop
                }
                _ => glib::Propagation::Proceed,
            }
        }));
        url_entry.add_controller(key_ctl);

        // Selecting a popover row navigates and dismisses.
        suggestions_list.connect_row_activated(clone!(@strong state => move |_, row| {
            // The row carries a string accessible value containing the URL.
            // For simplicity we read the second label child.
            if let Some(b) = row.child().and_downcast::<gtk::Box>() {
                if let Some(sub) = b.last_child().and_downcast::<Label>() {
                    let target = sub.text();
                    if !target.is_empty() {
                        if let Some(wv) = state.active_webview() {
                            wv.load_uri(target.as_str());
                            state.url_entry.set_text(target.as_str());
                        }
                    }
                }
            }
            state.suggestions_popover.popdown();
        }));

        // (d) Bookmark star toggle.
        bookmark_btn.connect_clicked(clone!(@strong state => move |btn| {
            let Some(wv) = state.active_webview() else { return; };
            let Some(uri) = wv.uri() else { return; };
            let url_str = uri.to_string();
            if url_str.is_empty() || url_str == "about:blank" { return; }
            let Some(idx) = state.index.as_ref() else { return; };

            let currently = idx.is_bookmarked(&url_str);
            idx.set_bookmarked(&url_str, !currently);
            // Reflect new state in the icon immediately.
            btn.set_icon_name(if currently { "non-starred-symbolic" } else { "starred-symbolic" });
            state.refresh_bookmarks_bar();
        }));

        // (e) New-tab button + Ctrl+T accelerator.
        new_tab_btn.connect_clicked(clone!(@strong state => move |_| {
            state.open_new_tab("about:blank");
        }));

        // (f) Find revealer wiring.
        find_close.connect_clicked(clone!(@weak find_revealer => move |_| {
            find_revealer.set_reveal_child(false);
        }));
        find_entry.connect_changed(clone!(@strong state => move |entry| {
            let q = entry.text();
            let Some(wv) = state.active_webview() else { return; };
            let Some(fc) = wv.find_controller() else { return; };
            if q.is_empty() {
                fc.search_finish();
                state.find_count.set_text("");
                return;
            }
            // 1024 is the max-match cap matching the WebKit default.
            fc.count_matches(q.as_str(), FindOptions::CASE_INSENSITIVE.bits(), 1024);
            fc.search(q.as_str(), FindOptions::CASE_INSENSITIVE.bits(), 1024);
        }));
        find_next.connect_clicked(clone!(@strong state => move |_| {
            if let Some(wv) = state.active_webview() {
                if let Some(fc) = wv.find_controller() { fc.search_next(); }
            }
        }));
        find_prev.connect_clicked(clone!(@strong state => move |_| {
            if let Some(wv) = state.active_webview() {
                if let Some(fc) = wv.find_controller() { fc.search_previous(); }
            }
        }));
        // Esc inside the find entry closes the bar.
        let find_key = EventControllerKey::new();
        find_key.connect_key_pressed(clone!(@weak find_revealer => @default-return glib::Propagation::Proceed, move |_, key, _, _| {
            if key == gtk::gdk::Key::Escape {
                find_revealer.set_reveal_child(false);
                return glib::Propagation::Stop;
            }
            glib::Propagation::Proceed
        }));
        find_entry.add_controller(find_key);

        // (g) Notebook page-switch — update URL entry, button state,
        // bookmark icon, find bar target.
        notebook.connect_switch_page(clone!(@strong state => move |_, _page, _index| {
            state.sync_chrome_to_active();
            // Defer the close on find: changing pages should leave the
            // bar visible if the user opened it, but reset the match
            // count.
            state.find_count.set_text("");
        }));

        // ---- 9. Build the window + first tab. ----
        let window = ApplicationWindow::builder()
            .application(app)
            .title("Webkitium")
            .default_width(1200)
            .default_height(800)
            .build();
        window.set_titlebar(Some(&header));
        window.set_child(Some(&body));

        // Application-level keyboard accelerators. GTK4 binds these via
        // gio Actions on the application.
        let action_new_tab = gtk::gio::SimpleAction::new("new-tab", None);
        action_new_tab.connect_activate(clone!(@strong state => move |_, _| {
            state.open_new_tab("about:blank");
        }));
        let action_close_tab = gtk::gio::SimpleAction::new("close-tab", None);
        action_close_tab.connect_activate(clone!(@strong state => move |_, _| {
            state.close_active_tab();
        }));
        let action_find = gtk::gio::SimpleAction::new("find", None);
        action_find.connect_activate(clone!(@strong state, @weak find_revealer, @weak find_entry => move |_, _| {
            find_revealer.set_reveal_child(true);
            find_entry.grab_focus();
            // Re-issue the search if there's already a query.
            let q = find_entry.text();
            if !q.is_empty() {
                if let Some(wv) = state.active_webview() {
                    if let Some(fc) = wv.find_controller() {
                        fc.count_matches(q.as_str(), FindOptions::CASE_INSENSITIVE.bits(), 1024);
                        fc.search(q.as_str(), FindOptions::CASE_INSENSITIVE.bits(), 1024);
                    }
                }
            }
        }));
        window.add_action(&action_new_tab);
        window.add_action(&action_close_tab);
        window.add_action(&action_find);
        app.set_accels_for_action("win.new-tab",   &["<Primary>t"]);
        app.set_accels_for_action("win.close-tab", &["<Primary>w"]);
        app.set_accels_for_action("win.find",      &["<Primary>f"]);

        // Open one initial tab + populate the bookmarks bar.
        state.open_new_tab("about:blank");
        state.refresh_bookmarks_bar();

        window
    }
}

/// Per-window shared state. Held inside `Rc` so signal handlers can
/// `clone!(@strong …)` it without fighting the borrow checker.
struct WindowState {
    notebook: Notebook,
    url_entry: Entry,
    back_btn: Button,
    fwd_btn: Button,
    bookmark_btn: Button,
    bookmarks_bar: GtkBox,
    suggestions_popover: Popover,
    suggestions_list: ListBox,
    find_revealer: Revealer,
    find_entry: Entry,
    find_count: Label,
    index: Option<Rc<Index>>,
}

impl WindowState {
    fn active_webview(&self) -> Option<WebView> {
        let n = self.notebook.current_page()?;
        self.notebook
            .nth_page(Some(n))
            .and_then(|p| p.downcast::<WebView>().ok())
    }

    /// Build a new tab containing a fresh WebView, append it to the
    /// Notebook, focus it.
    fn open_new_tab(self: &Rc<Self>, initial_uri: &str) {
        let webview = WebView::new();
        webview.set_vexpand(true);
        webview.set_hexpand(true);

        // Per-tab load-changed: when the active tab navigates, refresh
        // chrome. Inactive-tab loads are silent (they don't drive the
        // URL bar).
        let weak_state = Rc::downgrade(self);
        webview.connect_load_changed(move |wv, event| {
            let Some(state) = weak_state.upgrade() else { return; };
            // Only the active tab pushes chrome state.
            if Some(wv) != state.active_webview().as_ref() {
                return;
            }
            state.back_btn.set_sensitive(wv.can_go_back());
            state.fwd_btn.set_sensitive(wv.can_go_forward());
            if matches!(event, LoadEvent::Committed | LoadEvent::Finished) {
                if let Some(uri) = wv.uri() {
                    state.url_entry.set_text(uri.as_str());
                    state.update_bookmark_icon(uri.as_str());
                    state.update_lock_icon(uri.as_str());
                }
            }
            if matches!(event, LoadEvent::Finished) {
                if let (Some(idx), Some(uri)) = (state.index.as_ref(), wv.uri()) {
                    let title = wv.title().map(|g| g.to_string()).unwrap_or_default();
                    idx.record_visit(&title, uri.as_str());
                }
            }
        });

        // Find-controller match-count signal.
        if let Some(fc) = webview.find_controller() {
            let weak_state2 = Rc::downgrade(self);
            fc.connect_counted_matches(move |_, n| {
                let Some(state) = weak_state2.upgrade() else { return; };
                if n == 0 {
                    state.find_count.set_text("No matches");
                } else {
                    state.find_count.set_text(&format!("{} matches", n));
                }
            });
        }

        let label_box = GtkBox::new(Orientation::Horizontal, 4);
        let title_label = Label::new(Some("New Tab"));
        title_label.set_ellipsize(gtk::pango::EllipsizeMode::End);
        title_label.set_max_width_chars(18);
        let close_btn = Button::from_icon_name("window-close-symbolic");
        close_btn.add_css_class("flat");
        close_btn.update_property(&[Aria::Label("Close tab: New Tab")]);
        label_box.append(&title_label);
        label_box.append(&close_btn);

        let pos = self.notebook.append_page(&webview, Some(&label_box));
        self.notebook.set_tab_reorderable(&webview, true);
        self.notebook.set_current_page(Some(pos));

        // Update tab label as the page title arrives.
        let label_clone = title_label.clone();
        let close_clone = close_btn.clone();
        webview.connect_title_notify(move |wv| {
            let title = wv.title()
                .map(|g| g.to_string())
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| "New Tab".to_string());
            label_clone.set_text(&title);
            close_clone.update_property(&[Aria::Label(&format!("Close tab: {title}"))]);
        });

        // Close button on tab label closes that specific page.
        let notebook_w = self.notebook.clone();
        let wv_target = webview.clone();
        close_btn.connect_clicked(move |_| {
            if let Some(page_num) = notebook_w.page_num(&wv_target) {
                // GTK4 removes the page; if last one closed, leave the
                // window alive but seed a fresh blank tab so the user
                // can still type.
                notebook_w.remove_page(Some(page_num));
            }
        });

        webview.load_uri(initial_uri);
    }

    fn close_active_tab(self: &Rc<Self>) {
        let Some(n) = self.notebook.current_page() else { return; };
        self.notebook.remove_page(Some(n));
        if self.notebook.n_pages() == 0 {
            self.open_new_tab("about:blank");
        }
    }

    /// Pull current state from the active tab into the chrome widgets.
    fn sync_chrome_to_active(&self) {
        if let Some(wv) = self.active_webview() {
            self.back_btn.set_sensitive(wv.can_go_back());
            self.fwd_btn.set_sensitive(wv.can_go_forward());
            let uri = wv.uri().map(|s| s.to_string()).unwrap_or_default();
            self.url_entry.set_text(&uri);
            self.update_bookmark_icon(&uri);
            self.update_lock_icon(&uri);
        }
    }

    fn update_bookmark_icon(&self, url: &str) {
        let starred = self
            .index
            .as_ref()
            .map(|i| i.is_bookmarked(url))
            .unwrap_or(false);
        self.bookmark_btn
            .set_icon_name(if starred { "starred-symbolic" } else { "non-starred-symbolic" });
    }

    /// Show the glowing-blue padlock when the active URI is HTTPS;
    /// clear the icon otherwise. CSS in `SECURE_LOCK_CSS` provides the
    /// blue tint + outward glow on the primary icon.
    fn update_lock_icon(&self, url: &str) {
        if url.starts_with("https://") {
            self.url_entry
                .set_primary_icon_name(Some("system-lock-screen-symbolic"));
            self.url_entry
                .set_primary_icon_tooltip_text(Some("Secure connection"));
        } else {
            self.url_entry.set_primary_icon_name(None);
            self.url_entry.set_primary_icon_tooltip_text(None);
        }
    }

    fn refresh_suggestions(&self, prefix: &str) {
        // Clear existing rows.
        while let Some(child) = self.suggestions_list.first_child() {
            self.suggestions_list.remove(&child);
        }

        if prefix.trim().is_empty() {
            self.suggestions_popover.popdown();
            return;
        }
        let rows = self
            .index
            .as_ref()
            .map(|i| i.query(prefix, 8))
            .unwrap_or_default();

        if rows.is_empty() {
            self.suggestions_popover.popdown();
            return;
        }
        for s in rows {
            self.suggestions_list.append(&suggestion_row(&s));
        }
        self.suggestions_popover.popup();
    }

    fn suggestion_move(&self, delta: i32) {
        let count = {
            let mut n = 0;
            let mut child = self.suggestions_list.first_child();
            while let Some(c) = child {
                n += 1;
                child = c.next_sibling();
            }
            n
        };
        if count == 0 {
            return;
        }
        let cur = self
            .suggestions_list
            .selected_row()
            .and_then(|r| Some(r.index()))
            .unwrap_or(-1);
        let next = ((cur + delta).rem_euclid(count));
        if let Some(r) = self.suggestions_list.row_at_index(next) {
            self.suggestions_list.select_row(Some(&r));
        }
    }

    fn refresh_bookmarks_bar(&self) {
        // Drop existing bookmark chips.
        while let Some(child) = self.bookmarks_bar.first_child() {
            self.bookmarks_bar.remove(&child);
        }
        let bookmarks = self
            .index
            .as_ref()
            .map(|i| i.bookmarks_flat(16))
            .unwrap_or_default();
        if bookmarks.is_empty() {
            // Hide the bar entirely when empty by leaving height 0.
            return;
        }
        for bm in bookmarks {
            let url = bm.subtitle.clone();
            let label_text = if bm.title.is_empty() { url.clone() } else { bm.title.clone() };
            let btn = Button::with_label(&label_text);
            btn.add_css_class("flat");
            btn.set_tooltip_text(Some(&url));
            btn.update_property(&[Aria::Label(&format!("Open bookmark: {label_text}"))]);
            let notebook = self.notebook.clone();
            btn.connect_clicked(move |_| {
                // Load into the active tab.
                if let Some(n) = notebook.current_page() {
                    if let Some(page) = notebook.nth_page(Some(n)) {
                        if let Ok(wv) = page.downcast::<WebView>() {
                            wv.load_uri(&url);
                        }
                    }
                }
            });
            self.bookmarks_bar.append(&btn);
        }
    }
}

/// Build a single Popover row from a Suggestion: title on top, URL below.
fn suggestion_row(s: &Suggestion) -> ListBoxRow {
    let kind_glyph = match s.kind {
        SuggestionKind::TopHit => "★",
        SuggestionKind::History => "⟲",
        SuggestionKind::Bookmark => "♥",
        SuggestionKind::Search => "🔍",
        SuggestionKind::Site => "•",
    };
    let title = Label::builder()
        .label(&format!("{} {}", kind_glyph, s.title))
        .halign(gtk::Align::Start)
        .ellipsize(gtk::pango::EllipsizeMode::End)
        .build();
    let url = Label::builder()
        .label(&s.subtitle)
        .halign(gtk::Align::Start)
        .ellipsize(gtk::pango::EllipsizeMode::End)
        .build();
    url.add_css_class("dim-label");
    let vbox = GtkBox::new(Orientation::Vertical, 0);
    vbox.set_margin_start(8);
    vbox.set_margin_end(8);
    vbox.set_margin_top(2);
    vbox.set_margin_bottom(2);
    vbox.append(&title);
    vbox.append(&url);

    let row = ListBoxRow::builder().child(&vbox).build();
    // Accessible label so the harness can match suggestion rows by
    // partial-text without poking at the box children.
    row.update_property(&[Aria::Label(&format!("{} – {}", s.title, s.subtitle))]);
    row.set_accessible_role(AccessibleRole::ListItem);
    row
}
