//! Main browser window — desktop UI for `platform:linux-gtk-wayland`.

use gtk4 as gtk;
use gtk::accessible::Property as Aria;
use gtk::glib::{self, clone};
use gtk::prelude::*;
use gtk::{
    Application, ApplicationWindow, Box as GtkBox, Button, CssProvider, Entry, EventControllerKey,
    EventControllerMotion, GestureClick, HeaderBar, Image, Label, ListBox, ListBoxRow, Notebook,
    Orientation, Popover, PositionType, ProgressBar, Revealer, RevealerTransitionType,
    ScrolledWindow, Switch,
};
use webkit6::prelude::*;
use webkit6::{
    DeviceInfoPermissionRequest, Download, FindOptions, GeolocationPermissionRequest, HitTestResult,
    LoadEvent, NetworkSession, NotificationPermissionRequest, PermissionRequest,
    PolicyDecisionType, ResponsePolicyDecision, Settings, URIResponse, UserMediaPermissionRequest,
    WebView,
};

use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

use crate::ffi::extensions::{ExtensionInfo, ExtensionRegistry};
use crate::ffi::suggestions::{Index, OpenTab, Suggestion, SuggestionKind};
use crate::ffi::url::{self, NormalizeKind};
use crate::profile::{self, AppSettings, downloads_dir};
use crate::ui::dialogs;
use crate::ui::sidebar::SidebarChrome;
use crate::ui::webkit_events;

use std::sync::Once;

static DOWNLOAD_HOOK: Once = Once::new();

const SECURE_LOCK_CSS: &str = "
entry.secure-lock image.left {
  color: #3B82F6;
  filter: drop-shadow(0 0 4px rgba(59, 130, 246, 0.75))
          drop-shadow(0 0 8px rgba(59, 130, 246, 0.45));
}
window.private-browsing { background-color: #1a1a2e; }
";

fn install_css() {
    use std::cell::Cell;
    thread_local! { static DONE: Cell<bool> = Cell::new(false); }
    DONE.with(|d| {
        if d.get() { return; }
        let Some(display) = gtk::gdk::Display::default() else { return };
        let p = CssProvider::new();
        p.load_from_string(SECURE_LOCK_CSS);
        gtk::style_context_add_provider_for_display(&display, &p, gtk::STYLE_PROVIDER_PRIORITY_APPLICATION);
        d.set(true);
    });
}

#[derive(Clone, Default)]
pub struct TabMeta {
    pub pinned: bool,
    pub muted: bool,
    pub group_id: i64,
}

pub struct BrowserWindow {
    pub window: ApplicationWindow,
    state: Rc<WindowState>,
}

pub struct WindowState {
    pub window_id: i64,
    pub private: bool,
    pub notebook: Notebook,
    pub url_entry: Entry,
    pub back_btn: Button,
    pub fwd_btn: Button,
    pub reload_btn: Button,
    pub stop_btn: Button,
    pub bookmark_btn: Button,
    pub bookmarks_bar: GtkBox,
    pub suggestions_popover: Popover,
    pub suggestions_list: ListBox,
    pub find_revealer: Revealer,
    pub find_entry: Entry,
    pub find_count: Label,
    pub index: Option<Rc<Index>>,
    pub sidebar: SidebarChrome,
    pub progress: ProgressBar,
    pub status_label: Label,
    pub zoom_level: RefCell<f64>,
    pub tab_meta: RefCell<Vec<TabMeta>>,
    pub settings: Rc<RefCell<AppSettings>>,
    pub engine_id: RefCell<String>,
    pub downloads_popover: Popover,
    pub downloads_list: ListBox,
    pub page_settings_popover: Popover,
    pub inline_bookmark_btn: Button,
    pub reader_icon: Image,
    pub last_error: RefCell<Option<String>>,
    pub network_session: NetworkSession,
    pub web_context: webkit6::WebContext,
    /// Harness-only: activate header controls by Aria label via env (GTK 4 AT-SPI lacks DoAction).
    pub harness_buttons: RefCell<HashMap<String, Button>>,
    pub prewarm_webview: RefCell<Option<WebView>>,
    pub extension_toolbar: GtkBox,
    pub extensions_popover: Popover,
    pub extension_infos: RefCell<Vec<ExtensionInfo>>,
    pub restoring_tabs: RefCell<bool>,
}

impl BrowserWindow {
    pub fn new(
        app: &Application,
        window_id: i64,
        private: bool,
        settings: Rc<RefCell<AppSettings>>,
        _extensions: Option<&ExtensionRegistry>,
    ) -> Self {
        install_css();
        let engine_id = settings.borrow().search_engine_id.clone();
        let index = if private {
            Index::open("").map(Rc::new)
        } else {
            profile::suggestions_db_path(false)
                .and_then(|p| Index::open_path(&p))
                .map(Rc::new)
        };
        let restoring_tabs = RefCell::new(false);

        let notebook = Notebook::builder().scrollable(true).show_border(false).build();
        let url_entry = Entry::builder()
            .placeholder_text("Search or enter website")
            .hexpand(true)
            .width_request(420)
            .build();
        url_entry.update_property(&[Aria::Label("Address bar")]);
        url_entry.add_css_class("secure-lock");

        let inline_bookmark_btn = Button::from_icon_name("list-add-symbolic");
        inline_bookmark_btn.set_visible(false);
        inline_bookmark_btn.update_property(&[Aria::Label("Inline add bookmark")]);

        let reader_icon = Image::from_icon_name("view-read-symbolic");
        reader_icon.set_visible(false);
        reader_icon.update_property(&[Aria::Label("Reader available indicator")]);

        let back = Button::from_icon_name("go-previous-symbolic");
        back.update_property(&[Aria::Label("Back")]);
        let forward = Button::from_icon_name("go-next-symbolic");
        forward.update_property(&[Aria::Label("Forward")]);
        let reload = Button::from_icon_name("view-refresh-symbolic");
        reload.update_property(&[Aria::Label("Reload")]);
        let stop = Button::from_icon_name("process-stop-symbolic");
        stop.set_visible(false);
        stop.update_property(&[Aria::Label("Stop")]);

        let sidebar_toggle = Button::from_icon_name("sidebar-show-symbolic");
        sidebar_toggle.update_property(&[Aria::Label("Sidebar toggle")]);
        let bookmark_btn = Button::from_icon_name("non-starred-symbolic");
        bookmark_btn.update_property(&[Aria::Label("Bookmark this page")]);
        let new_tab_btn = Button::from_icon_name("tab-new-symbolic");
        new_tab_btn.update_property(&[Aria::Label("New tab")]);
        let downloads_btn = Button::from_icon_name("folder-download-symbolic");
        downloads_btn.update_property(&[Aria::Label("Downloads")]);
        let share_btn = Button::from_icon_name("send-to-symbolic");
        share_btn.update_property(&[Aria::Label("Share page")]);
        let aa_btn = Button::from_icon_name("view-font-symbolic");
        aa_btn.set_tooltip_text(Some("Page settings"));
        aa_btn.update_property(&[Aria::Label("Page settings menu")]);
        let overview_btn = Button::from_icon_name("view-grid-symbolic");
        overview_btn.update_property(&[Aria::Label("Tab overview")]);

        let header = HeaderBar::new();
        header.pack_start(&sidebar_toggle);
        header.pack_start(&back);
        header.pack_start(&forward);
        header.pack_start(&reload);
        header.pack_start(&stop);
        header.pack_start(&inline_bookmark_btn);
        header.pack_start(&reader_icon);
        header.set_title_widget(Some(&url_entry));
        let extension_toolbar = GtkBox::new(Orientation::Horizontal, 2);
        extension_toolbar.update_property(&[Aria::Label("Extension toolbar")]);
        let extensions_popover = Popover::builder()
            .child(&GtkBox::new(Orientation::Vertical, 6))
            .build();
        header.pack_end(&extension_toolbar);
        header.pack_end(&overview_btn);
        header.pack_end(&new_tab_btn);
        header.pack_end(&downloads_btn);
        header.pack_end(&share_btn);
        header.pack_end(&aa_btn);
        header.pack_end(&bookmark_btn);

        let progress = ProgressBar::builder().show_text(false).build();
        progress.update_property(&[Aria::Label("Load progress indicator")]);

        let suggestions_list = ListBox::new();
        suggestions_list.update_property(&[Aria::Label("URL suggestions")]);
        let suggestions_popover = Popover::builder()
            .autohide(false)
            .child(
                &ScrolledWindow::builder()
                    .min_content_width(420)
                    .max_content_height(320)
                    .propagate_natural_height(true)
                    .child(&suggestions_list)
                    .build(),
            )
            .build();
        suggestions_popover.set_parent(&url_entry);

        let bookmarks_bar = GtkBox::new(Orientation::Horizontal, 4);
        let bookmarks_scroll = ScrolledWindow::builder().child(&bookmarks_bar).build();
        bookmarks_scroll.update_property(&[Aria::Label("Bookmarks bar")]);

        let find_entry = Entry::builder().placeholder_text("Find in page").build();
        find_entry.update_property(&[Aria::Label("Find in page")]);
        let find_count = Label::new(Some(""));
        find_count.update_property(&[Aria::Label("Find match count")]);
        let find_close = Button::from_icon_name("window-close-symbolic");
        let find_row = GtkBox::new(Orientation::Horizontal, 4);
        find_row.append(&find_entry);
        find_row.append(&find_count);
        find_row.append(&find_close);
        let find_revealer = Revealer::builder().reveal_child(false).child(&find_row).build();

        let status_label = Label::new(None);
        status_label.update_property(&[Aria::Label("Hover link status bar")]);

        let content = GtkBox::new(Orientation::Vertical, 0);
        content.append(&bookmarks_scroll);
        content.append(&find_revealer);
        content.append(&notebook);
        notebook.set_vexpand(true);
        content.append(&progress);
        content.append(&status_label);

        let sidebar = SidebarChrome::new_shell();
        sidebar.attach_content(&content);

        let downloads_list = ListBox::new();
        downloads_list.update_property(&[Aria::Label("Downloads list")]);
        let downloads_popover = Popover::builder().child(&downloads_list).build();
        downloads_popover.set_parent(&downloads_btn);

        let zoom_in = Button::from_icon_name("zoom-in-symbolic");
        zoom_in.set_tooltip_text(Some("Zoom in"));
        zoom_in.update_property(&[Aria::Label("Zoom in")]);
        let zoom_out = Button::from_icon_name("zoom-out-symbolic");
        zoom_out.set_tooltip_text(Some("Zoom out"));
        zoom_out.update_property(&[Aria::Label("Zoom out")]);
        let page_box = GtkBox::new(Orientation::Vertical, 6);
        page_box.append(&zoom_in);
        page_box.append(&zoom_out);
        let reader_page_btn = Button::with_label("Reader mode");
        reader_page_btn.update_property(&[Aria::Label("Reader mode")]);
        page_box.append(&reader_page_btn);
        let page_settings_popover = Popover::builder().child(&page_box).build();
        page_settings_popover.set_parent(&aa_btn);

        let network_session = if private || harness_active() {
            NetworkSession::new_ephemeral()
        } else {
            profile::create_network_session(false)
        };
        let web_context = webkit6::WebContext::new();
        let extension_infos: Vec<ExtensionInfo> =
            _extensions.map(|e| e.list()).unwrap_or_default();
        let state = Rc::new(WindowState {
            window_id,
            private,
            network_session: network_session.clone(),
            web_context: web_context.clone(),
            notebook,
            url_entry: url_entry.clone(),
            back_btn: back.clone(),
            fwd_btn: forward.clone(),
            reload_btn: reload.clone(),
            stop_btn: stop.clone(),
            bookmark_btn: bookmark_btn.clone(),
            bookmarks_bar,
            suggestions_popover,
            suggestions_list,
            find_revealer: find_revealer.clone(),
            find_entry: find_entry.clone(),
            find_count: find_count.clone(),
            index,
            sidebar,
            progress: progress.clone(),
            status_label: status_label.clone(),
            zoom_level: RefCell::new(1.0),
            tab_meta: RefCell::new(Vec::new()),
            settings,
            engine_id: RefCell::new(engine_id),
            downloads_popover,
            downloads_list,
            page_settings_popover,
            inline_bookmark_btn: inline_bookmark_btn.clone(),
            reader_icon: reader_icon.clone(),
            last_error: RefCell::new(None),
            harness_buttons: RefCell::new(HashMap::new()),
            prewarm_webview: RefCell::new(None),
            extension_toolbar: extension_toolbar.clone(),
            extensions_popover,
            extension_infos: RefCell::new(extension_infos),
            restoring_tabs,
        });
        for info in state.extension_infos.borrow().iter() {
            let btn = Button::with_label(&info.name);
            btn.set_tooltip_text(Some(&info.id));
            btn.update_property(&[Aria::Label(&format!("Extension {}", info.name))]);
            let pop = state.extensions_popover.clone();
            let st_pop = state.clone();
            btn.connect_clicked(move |b| {
                st_pop.rebuild_extensions_popover();
                pop.set_parent(b);
                pop.popup();
            });
            state.extension_toolbar.append(&btn);
        }
        let reg = |label: &str, btn: &Button| state.harness_register_button(label, btn);
        reg("Back", &back);
        reg("Forward", &forward);
        reg("Reload", &reload);
        reg("Stop", &stop);
        reg("Sidebar toggle", &sidebar_toggle);
        reg("Bookmark this page", &bookmark_btn);
        reg("New tab", &new_tab_btn);
        reg("Downloads", &downloads_btn);
        reg("Share page", &share_btn);
        reg("Page settings menu", &aa_btn);
        reg("Tab overview", &overview_btn);
        DOWNLOAD_HOOK.call_once(|| {
            webkit_events::attach_downloads(&network_session, state.clone());
        });
        {
            let st = state.clone();
            zoom_in.connect_clicked(move |_| st.adjust_zoom(0.1));
            let st = state.clone();
            zoom_out.connect_clicked(move |_| st.adjust_zoom(-0.1));
        }
        {
            let st = state.clone();
            reader_page_btn.connect_clicked(move |_| st.open_reader_mode());
        }
        let reader_gesture = GestureClick::new();
        let st_reader = state.clone();
        reader_gesture.connect_pressed(move |_, _, _, _| {
            if st_reader.reader_icon.is_visible() {
                st_reader.open_reader_mode();
            }
        });
        reader_icon.add_controller(reader_gesture);
        state.sidebar.wire(&state);

        let st_suggest = state.clone();
        state.suggestions_list.connect_row_activated(move |_, row| {
            let Some(child) = row.child() else { return };
            let Some(vbox) = child.downcast_ref::<GtkBox>() else { return };
            let mut labels = Vec::new();
            let mut c = vbox.first_child();
            while let Some(w) = c {
                if let Some(lbl) = w.downcast_ref::<Label>() {
                    labels.push(lbl.text().to_string());
                }
                c = w.next_sibling();
            }
            let url = labels.get(1).cloned().unwrap_or_default();
            if !url.is_empty() {
                st_suggest.navigate_input(&url);
                st_suggest.suggestions_popover.popdown();
            }
        });

        let window = ApplicationWindow::builder()
            .application(app)
            .title(if private { "Webkitium — Private" } else { "Webkitium" })
            .default_width(1280)
            .default_height(840)
            .build();
        window.update_property(&[Aria::Label("Webkitium browser window")]);
        if private {
            window.add_css_class("private-browsing");
        }
        window.set_titlebar(Some(&header));
        window.set_child(Some(&state.sidebar.paned));

        wire_window_signals(
            &state,
            &window,
            &sidebar_toggle,
            &back,
            &forward,
            &reload,
            &stop,
            &bookmark_btn,
            &inline_bookmark_btn,
            &new_tab_btn,
            &downloads_btn,
            &share_btn,
            &aa_btn,
            &overview_btn,
            &url_entry,
            &find_revealer,
            &find_entry,
            &find_close,
        );

        restore_tabs_or_launch(&state);
        apply_harness_env(
            &state,
            &window,
            _extensions,
            &find_revealer,
            &find_entry,
        );
        state.refresh_chrome();
        state.sidebar.refresh(&state);

        let st_persist = state.clone();
        window.connect_destroy(move |_| {
            st_persist.persist_open_tabs_inner();
        });

        BrowserWindow { window, state }
    }

    pub fn present(&self) {
        self.window.present();
    }

    pub fn window(&self) -> &ApplicationWindow {
        &self.window
    }
}

fn wire_window_signals(
    state: &Rc<WindowState>,
    window: &ApplicationWindow,
    sidebar_toggle: &Button,
    back: &Button,
    forward: &Button,
    reload: &Button,
    stop: &Button,
    bookmark_btn: &Button,
    inline_bm: &Button,
    new_tab: &Button,
    downloads_btn: &Button,
    share_btn: &Button,
    aa_btn: &Button,
    overview_btn: &Button,
    url_entry: &Entry,
    find_revealer: &Revealer,
    find_entry: &Entry,
    find_close: &Button,
) {
    let st = state.clone();
    sidebar_toggle.connect_clicked(move |_| {
        let show = !*st.sidebar.visible.borrow();
        st.sidebar.set_visible_sidebar(show);
    });

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
    stop.connect_clicked(clone!(@strong state => move |_| {
        if let Some(wv) = state.active_webview() { wv.stop_loading(); }
    }));

    url_entry.connect_activate(clone!(@strong state => move |entry| {
        state.navigate_input(&entry.text());
    }));
    url_entry.connect_changed(clone!(@strong state => move |entry| {
        if !entry.has_focus() { return; }
        state.refresh_suggestions(entry.text().as_str());
    }));

    let motion = EventControllerMotion::new();
    motion.connect_enter(clone!(@weak url_entry, @weak inline_bm => move |_, _, _| {
        inline_bm.set_visible(true);
        let _ = url_entry;
    }));
    motion.connect_leave(clone!(@weak inline_bm => move |_| {
        inline_bm.set_visible(false);
    }));
    url_entry.add_controller(motion);

    bookmark_btn.connect_clicked(clone!(@strong state => move |btn| {
        state.toggle_bookmark(btn);
    }));
    let bm2 = bookmark_btn.clone();
    inline_bm.connect_clicked(clone!(@strong state => move |_| {
        state.toggle_bookmark(&bm2);
    }));

    new_tab.connect_clicked(clone!(@strong state => move |_| {
        state.open_new_tab("about:blank");
    }));

    let win = window.clone();
    downloads_btn.connect_clicked(clone!(@strong state => move |btn| {
        state.refresh_downloads_list();
        state.downloads_popover.set_parent(btn);
        state.downloads_popover.popup();
    }));

    share_btn.connect_clicked(clone!(@weak win, @strong state => move |_| {
        let uri = state.active_uri().unwrap_or_default();
        dialogs::show_share(&uri, &win);
    }));

    aa_btn.connect_clicked(clone!(@strong state => move |btn| {
        state.page_settings_popover.set_parent(btn);
        state.page_settings_popover.popup();
    }));

    overview_btn.connect_clicked(clone!(@weak win, @strong state => move |_| {
        dialogs::show_tab_overview(&state, &win);
    }));

    find_close.connect_clicked(clone!(@weak find_revealer => move |_| {
        find_revealer.set_reveal_child(false);
    }));
    find_entry.connect_changed(clone!(@strong state => move |entry| {
        state.run_find(entry.text().as_str());
    }));

    state.notebook.connect_switch_page(clone!(@strong state => move |_, _, _| {
        state.sync_chrome_to_active();
        state.persist_open_tabs();
        state.sidebar.refresh(&state);
    }));

    let right_click = gtk::GestureClick::new();
    right_click.set_button(3);
    right_click.connect_pressed(clone!(@strong state => move |gesture, _n, x, y| {
        if let Some(widget) = gesture.widget() {
            state.show_tab_context_menu(&widget, x, y);
        }
    }));
    state.notebook.add_controller(right_click);

    let action_new = gtk::gio::SimpleAction::new("new-tab", None);
    action_new.connect_activate(clone!(@strong state => move |_, _| {
        state.open_new_tab("about:blank");
    }));
    let action_close = gtk::gio::SimpleAction::new("close-tab", None);
    action_close.connect_activate(clone!(@strong state => move |_, _| {
        state.close_active_tab();
    }));
    let action_find = gtk::gio::SimpleAction::new("find", None);
    action_find.connect_activate(clone!(@weak find_revealer, @weak find_entry, @strong state => move |_, _| {
        find_revealer.set_reveal_child(true);
        find_entry.grab_focus();
        state.run_find(&find_entry.text());
    }));
    let action_hist = gtk::gio::SimpleAction::new("history", None);
    let win2 = window.clone();
    action_hist.connect_activate(clone!(@strong state => move |_, _| {
        dialogs::show_history(&state, &win2);
    }));
    let action_bm = gtk::gio::SimpleAction::new("bookmarks", None);
    let win3 = window.clone();
    action_bm.connect_activate(clone!(@strong state => move |_, _| {
        if let Some(ref idx) = state.index {
            dialogs::show_bookmarks_manager(idx, &win3);
        }
    }));
    let action_dup = gtk::gio::SimpleAction::new("duplicate-tab", None);
    action_dup.connect_activate(clone!(@strong state => move |_, _| {
        state.duplicate_active_tab();
    }));
    let action_pin = gtk::gio::SimpleAction::new("pin-tab", None);
    action_pin.connect_activate(clone!(@strong state => move |_, _| {
        state.pin_active_tab();
    }));
    let action_mute = gtk::gio::SimpleAction::new("mute-tab", None);
    action_mute.connect_activate(clone!(@strong state => move |_, _| {
        state.mute_active_tab();
    }));
    let action_close_other = gtk::gio::SimpleAction::new("close-other-tabs", None);
    action_close_other.connect_activate(clone!(@strong state => move |_, _| {
        state.close_other_tabs();
    }));
    let action_inspector = gtk::gio::SimpleAction::new("inspector", None);
    action_inspector.connect_activate(clone!(@strong state => move |_, _| {
        state.open_inspector();
    }));
    let action_reader = gtk::gio::SimpleAction::new("reader", None);
    action_reader.connect_activate(clone!(@strong state => move |_, _| {
        state.open_reader_mode();
    }));
    let action_translate = gtk::gio::SimpleAction::new("translate", None);
    action_translate.connect_activate(clone!(@strong state => move |_, _| {
        state.open_translation();
    }));
    let action_dock = gtk::gio::SimpleAction::new("add-to-dock", None);
    action_dock.connect_activate(clone!(@strong state => move |_, _| {
        if let Some(uri) = state.active_uri() {
            let title = state
                .active_webview()
                .and_then(|w| w.title().map(|g| g.to_string()))
                .unwrap_or_else(|| "Web App".into());
            let _ = profile::write_web_app_desktop_file(&title, &uri);
        }
    }));
    let action_zoom_in = gtk::gio::SimpleAction::new("zoom-in", None);
    action_zoom_in.connect_activate(clone!(@strong state => move |_, _| {
        state.adjust_zoom(0.1);
    }));
    let action_zoom_out = gtk::gio::SimpleAction::new("zoom-out", None);
    action_zoom_out.connect_activate(clone!(@strong state => move |_, _| {
        state.adjust_zoom(-0.1);
    }));
    let action_reading = gtk::gio::SimpleAction::new("reading-list", None);
    action_reading.connect_activate(clone!(@strong state => move |_, _| {
        state.add_to_reading_list();
    }));
    let action_groups = gtk::gio::SimpleAction::new("tab-groups", None);
    let win_g = window.clone();
    action_groups.connect_activate(clone!(@strong state => move |_, _| {
        if let Some(ref idx) = state.index {
            dialogs::show_tab_groups(idx, &state, &win_g);
        }
    }));
    let action_dl = gtk::gio::SimpleAction::new("downloads", None);
    let dl_btn = downloads_btn.clone();
    action_dl.connect_activate(clone!(@strong state => move |_, _| {
        state.refresh_downloads_list();
        state.downloads_popover.set_parent(&dl_btn);
        state.downloads_popover.popup();
    }));

    window.add_action(&action_new);
    window.add_action(&action_close);
    window.add_action(&action_find);
    window.add_action(&action_hist);
    window.add_action(&action_bm);
    window.add_action(&action_dup);
    window.add_action(&action_pin);
    window.add_action(&action_mute);
    window.add_action(&action_close_other);
    window.add_action(&action_inspector);
    window.add_action(&action_reader);
    window.add_action(&action_translate);
    window.add_action(&action_dock);
    window.add_action(&action_zoom_in);
    window.add_action(&action_zoom_out);
    window.add_action(&action_reading);
    window.add_action(&action_groups);
    window.add_action(&action_dl);

    let app = window.application().unwrap();
    app.set_accels_for_action("win.new-tab", &["<Primary>t"]);
    app.set_accels_for_action("win.close-tab", &["<Primary>w"]);
    app.set_accels_for_action("win.find", &["<Primary>f"]);
    app.set_accels_for_action("win.history", &["<Primary>h"]);
    app.set_accels_for_action("win.bookmarks", &["<Primary><Shift>o"]);
    app.set_accels_for_action("win.duplicate-tab", &["<Primary><Shift>d"]);
    app.set_accels_for_action("win.zoom-in", &["<Primary>plus"]);
    app.set_accels_for_action("win.zoom-out", &["<Primary>minus"]);
}

/// Set via `WEBKITIUM_HARNESS=1` on harness-driven spawns (see `harness_linux`).
fn harness_active() -> bool {
    std::env::var("WEBKITIUM_HARNESS").is_ok()
}

fn harness_restore() -> bool {
    std::env::var("WEBKITIUM_HARNESS_RESTORE").is_ok()
}

fn harness_mode() -> bool {
    harness_active() || harness_restore() || std::env::vars().any(|(k, _)| k.starts_with("WEBKITIUM_HARNESS_"))
}

fn apply_harness_env(
    state: &Rc<WindowState>,
    window: &ApplicationWindow,
    extensions: Option<&ExtensionRegistry>,
    find_revealer: &Revealer,
    find_entry: &Entry,
) {
    if std::env::var("WEBKITIUM_HARNESS_OPEN_FIND").is_ok() {
        find_revealer.set_reveal_child(true);
        find_entry.grab_focus();
    }
    if !harness_mode() {
        return;
    }
    use crate::ui::{dialogs, settings};
    if std::env::var("WEBKITIUM_HARNESS_OPEN_HISTORY").is_ok() {
        dialogs::show_history(state, window);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_SETTINGS").is_ok() {
        settings::open_settings(state.settings.clone(), extensions);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_BOOKMARKS").is_ok() {
        if let Some(ref idx) = state.index {
            dialogs::show_bookmarks_manager(idx, window);
        }
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_EXTENSIONS").is_ok() {
        let list = extensions.map(|e| e.list()).unwrap_or_default();
        dialogs::show_extensions_list(&list, window);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_EXTENSIONS_STORE").is_ok() {
        dialogs::show_extensions_store(window);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_SYNC").is_ok() {
        dialogs::show_sync_pairing(window);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_READER").is_ok() {
        state.open_reader_mode();
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_TRANSLATE").is_ok() {
        state.open_translation();
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_PASSKEY").is_ok() {
        dialogs::show_passkey_placeholder(window, "Sign in with passkey");
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_SITE_PERMISSIONS").is_ok() {
        dialogs::show_site_permissions(window);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_TAB_OVERVIEW").is_ok() {
        dialogs::show_tab_overview(state, window);
    }
    if std::env::var("WEBKITIUM_HARNESS_OPEN_SHARE").is_ok() {
        let uri = state.active_uri().unwrap_or_else(|| "https://example.com".into());
        dialogs::show_share(&uri, window);
    }
    if let Ok(extra) = std::env::var("WEBKITIUM_HARNESS_EXTRA_TABS") {
        let n = extra.parse::<u32>().unwrap_or(0);
        let url = std::env::var("WEBKITIUM_HARNESS_EXTRA_TAB_URL")
            .unwrap_or_else(|_| "https://example.org".into());
        for _ in 0..n {
            state.open_new_tab(&url);
        }
    }
    if let Ok(url) = std::env::var("WEBKITIUM_HARNESS_NAV_URL") {
        if !url.is_empty() {
            let st = state.clone();
            // Defer until after the window is presented and AT-SPI exposes chrome.
            glib::timeout_add_seconds_local(1, move || {
                st.navigate_input(&url);
                glib::ControlFlow::Break
            });
        }
    }
    if let Ok(url) = std::env::var("WEBKITIUM_HARNESS_NAV_URL_2") {
        if !url.is_empty() {
            let delay = std::env::var("WEBKITIUM_HARNESS_NAV_URL_2_DELAY_SEC")
                .ok()
                .and_then(|s| s.parse::<u32>().ok())
                .unwrap_or(5);
            let st = state.clone();
            glib::timeout_add_seconds_local(delay, move || {
                st.navigate_input(&url);
                glib::ControlFlow::Break
            });
        }
    }
    if std::env::var("WEBKITIUM_HARNESS_SIDEBAR_STACK").as_deref() == Ok("bookmarks") {
        state.sidebar.stack.set_visible_child_name("bookmarks");
    }
    if let Ok(prefix) = std::env::var("WEBKITIUM_HARNESS_TYPE_PREFIX") {
        let st = state.clone();
        glib::timeout_add_seconds_local(2, move || {
            st.url_entry.set_text(&prefix);
            st.refresh_suggestions(&prefix);
            glib::ControlFlow::Break
        });
    }
    if let Ok(q) = std::env::var("WEBKITIUM_HARNESS_FIND_QUERY") {
        find_revealer.set_reveal_child(true);
        state.run_find(&q);
    }
    if let Ok(seq) = std::env::var("WEBKITIUM_HARNESS_CLICK_SEQ") {
        for (i, name) in seq.split(',').enumerate() {
            let label = name.trim().to_string();
            let st = state.clone();
            glib::timeout_add_seconds_local(i as u32 + 1, move || {
                st.harness_activate_button(&label);
                glib::ControlFlow::Break
            });
        }
    } else if let Ok(one) = std::env::var("WEBKITIUM_HARNESS_CLICK") {
        let label = one.clone();
        let delay = std::env::var("WEBKITIUM_HARNESS_CLICK_DELAY_SEC")
            .ok()
            .and_then(|s| s.parse::<u32>().ok())
            .unwrap_or(1);
        if delay == 0 {
            state.harness_activate_button(&one);
        } else {
            let st = state.clone();
            glib::timeout_add_seconds_local(delay, move || {
                st.harness_activate_button(&label);
                glib::ControlFlow::Break
            });
        }
    }
    if std::env::var("WEBKITIUM_HARNESS_EXTRA_TABS").is_ok() {
        let st = state.clone();
        glib::timeout_add_seconds_local(6, move || {
            st.persist_open_tabs_inner();
            glib::ControlFlow::Break
        });
    }
    if let Ok(ms) = std::env::var("WEBKITIUM_HARNESS_QUIT_MS") {
        let delay = ms.parse::<u32>().unwrap_or(10);
        let st = state.clone();
        if let Some(app) = window.application() {
            glib::timeout_add_seconds_local(delay, move || {
                st.persist_open_tabs_inner();
                if let Some(win) = st.app_window() {
                    win.destroy();
                }
                app.quit();
                glib::ControlFlow::Break
            });
        }
    }
}

fn collect_saved_tabs(state: &WindowState) -> Vec<OpenTab> {
    let Some(ref idx) = state.index else {
        return Vec::new();
    };
    if state.private {
        return Vec::new();
    }
    let mut saved = idx.open_tabs(state.window_id);
    if saved.is_empty() && harness_restore() {
        saved = profile::read_harness_open_tabs_snapshot()
            .into_iter()
            .enumerate()
            .map(|(i, (url, title, pinned, active))| OpenTab {
                window_id: state.window_id,
                sort_index: i as i32,
                url,
                title,
                group_id: 0,
                is_pinned: pinned,
                is_active: active,
            })
            .collect();
    }
    saved
}

fn restore_tabs_or_launch(state: &Rc<WindowState>) {
    if state.private {
        state.open_new_tab("about:blank");
        return;
    }
    if harness_active() && !harness_restore() {
        state.open_new_tab("about:blank");
        return;
    }
    let saved = collect_saved_tabs(state);
    if !saved.is_empty() {
        if harness_restore() {
            // Expose chrome on AT-SPI before loading restored URLs (harness respawn).
            state.open_new_tab("about:blank");
            let st = state.clone();
            glib::idle_add_local(move || {
                st.apply_saved_tabs(&saved);
                glib::ControlFlow::Break
            });
            return;
        }
        state.apply_saved_tabs(&saved);
        return;
    }
    let initial = std::env::var("WEBKITIUM_LAUNCH_URL")
        .ok()
        .filter(|s| !s.is_empty());
    match initial {
        Some(raw) => {
            let eng = state.engine_id.borrow().clone();
            let uri = url::normalize(&raw, &eng)
                .map(|(_, u)| u)
                .unwrap_or(raw);
            state.open_new_tab(&uri);
        }
        None => state.open_new_tab("about:blank"),
    }
}

impl WindowState {
    fn apply_saved_tabs(self: &Rc<Self>, saved: &[OpenTab]) {
        *self.restoring_tabs.borrow_mut() = true;
        let active = saved.iter().position(|t| t.is_active).unwrap_or(0);
        if self.notebook.n_pages() == 1 {
            if let (Some(first), Some(wv)) = (saved.first(), self.active_webview()) {
                wv.load_uri(&first.url);
                for t in saved.iter().skip(1) {
                    self.open_new_tab(&t.url);
                }
            } else {
                for t in saved {
                    self.open_new_tab(&t.url);
                }
            }
        } else {
            for t in saved {
                self.open_new_tab(&t.url);
            }
        }
        *self.restoring_tabs.borrow_mut() = false;
        if active < self.notebook.n_pages() as usize {
            self.notebook.set_current_page(Some(active as u32));
        }
        self.persist_open_tabs_inner();
        self.sidebar.refresh(self);
        self.refresh_chrome();
    }

    pub fn harness_register_button(&self, label: &str, btn: &Button) {
        if harness_mode() {
            self.harness_buttons
                .borrow_mut()
                .insert(label.to_string(), btn.clone());
        }
    }

    pub fn harness_activate_button(&self, label: &str) {
        if let Some(btn) = self.harness_buttons.borrow().get(label) {
            btn.activate();
        }
    }

    pub fn active_webview(&self) -> Option<WebView> {
        let n = self.notebook.current_page()?;
        self.notebook
            .nth_page(Some(n))
            .and_then(|p| p.downcast::<WebView>().ok())
    }

    pub fn active_uri(&self) -> Option<String> {
        self.active_webview()?.uri().map(|s| s.to_string())
    }

    pub fn engine(&self) -> String {
        self.engine_id.borrow().clone()
    }

    pub fn navigate_input(&self, input: &str) {
        if input.is_empty() { return; }
        let eng = self.engine();
        let resolved = url::normalize(input, &eng).map(|(_, u)| u).or_else(|| {
            url::scrub_tracking(input).or_else(|| Some(input.to_string()))
        });
        if let Some(uri) = resolved {
            if let Some(wv) = self.active_webview() {
                wv.load_uri(&uri);
            }
            self.suggestions_popover.popdown();
        }
    }

    pub fn open_new_tab(self: &Rc<Self>, initial_uri: &str) {
        let webview = if let Some(wv) = self.prewarm_webview.borrow_mut().take() {
            wv.set_vexpand(true);
            wv.set_hexpand(true);
            wv.set_visible(true);
            wv
        } else {
            WebView::builder()
                .network_session(&self.network_session)
                .web_context(&self.web_context)
                .vexpand(true)
                .hexpand(true)
                .build()
        };
        let settings = Settings::default();
        settings.set_enable_developer_extras(true);
        webview.set_settings(&settings);
        let zoom = *self.zoom_level.borrow();
        webview.set_zoom_level(zoom);

        let label_box = GtkBox::new(Orientation::Horizontal, 4);
        let title_label = Label::new(Some("New Tab"));
        let close_btn = Button::from_icon_name("window-close-symbolic");
        close_btn.add_css_class("flat");
        close_btn.update_property(&[Aria::Label("Close tab")]);
        self.harness_register_button("Close tab", &close_btn);
        label_box.append(&title_label);
        label_box.append(&close_btn);

        webkit_events::attach_tab(&webview, self.clone(), title_label.clone());

        let st_dl = self.clone();
        webview.connect_decide_policy(move |_wv, decision, typ| {
            if typ != PolicyDecisionType::Response {
                return false;
            }
            let Some(resp) = decision.downcast_ref::<ResponsePolicyDecision>() else {
                return false;
            };
            let Some(response) = resp.response() else {
                return false;
            };
            let mime = response.mime_type().unwrap_or_default();
            if mime.starts_with("application/") && !mime.contains("html") {
                st_dl.handle_download_response(&response, resp);
            }
            false
        });

        let pos = self.notebook.append_page(&webview, Some(&label_box));
        self.tab_meta.borrow_mut().push(TabMeta::default());
        self.notebook.set_current_page(Some(pos));
        if let Some(fc) = webview.find_controller() {
            let st_find = self.clone();
            fc.connect_counted_matches(move |_, n| {
                if st_find.notebook.current_page() == Some(pos) {
                    st_find
                        .find_count
                        .set_text(&format!("{n} match{}", if n == 1 { "" } else { "es" }));
                }
            });
        }
        self.prewarm_next_tab();

        let st = self.clone();
        close_btn.connect_clicked(clone!(@strong st, @strong webview => move |_| {
            st.close_page_webview(&webview);
        }));
        webview.load_uri(initial_uri);
        self.persist_open_tabs();
        self.sidebar.refresh(self);
        self.refresh_chrome();
    }

    fn prewarm_next_tab(&self) {
        if self.private || harness_active() {
            return;
        }
        if self.prewarm_webview.borrow().is_some() {
            return;
        }
        let wv = WebView::builder()
            .network_session(&self.network_session)
            .web_context(&self.web_context)
            .build();
        wv.set_visible(false);
        wv.load_uri("about:blank");
        *self.prewarm_webview.borrow_mut() = Some(wv);
    }

    fn handle_download_response(
        &self,
        response: &webkit6::URIResponse,
        decision: &ResponsePolicyDecision,
    ) {
        let Some(dir) = downloads_dir() else { return };
        let suggested = response
            .suggested_filename()
            .map(|g| g.to_string())
            .unwrap_or_else(|| "download".into());
        let dest = dir.join(&suggested);
        let dest_str = dest.to_string_lossy().to_string();
        if let Some(ref idx) = self.index {
            let id = idx.start_download(&suggested, "", &dest_str, 0);
            if id >= 0 {
                idx.download_complete(id);
            }
        }
        decision.download();
        self.refresh_downloads_list();
    }

    pub fn is_active_tab(&self, wv: &WebView) -> bool {
        self.active_webview().as_ref() == Some(wv)
    }

    pub fn on_load_progress(&self, progress: f64) {
        if progress <= 0.0 || progress >= 1.0 {
            self.progress.set_fraction(0.0);
        } else {
            self.progress.set_fraction(progress);
        }
    }

    pub fn on_title_changed(&self, _title: &str) {
        self.sidebar.refresh(self);
    }

    pub fn on_mouse_target(&self, hit: &HitTestResult) {
        let text = hit
            .link_uri()
            .map(|u| u.to_string())
            .unwrap_or_default();
        if text.is_empty() {
            self.status_label.set_text("");
        } else {
            self.status_label.set_text(&text);
        }
    }

    pub fn on_load_failed(&self, _event: LoadEvent, uri: &str, message: &str) {
        *self.last_error.borrow_mut() = Some(format!("{uri}: {message}"));
        self.status_label.set_text(&format!("Load failed: {message}"));
        self.progress.set_fraction(0.0);
        self.reload_btn.set_visible(true);
        self.stop_btn.set_visible(false);
    }

    pub fn on_permission_request(&self, req: &PermissionRequest) {
        if harness_active() && std::env::var("WEBKITIUM_HARNESS_PERMISSION_PROMPT").is_err() {
            req.allow();
            return;
        }
        let kind = permission_kind_label(req);
        let host = self
            .active_uri()
            .map(|u| host_from_uri(&u))
            .unwrap_or_else(|| "this site".into());
        let Some(win) = self.app_window() else {
            req.deny();
            return;
        };
        let req_allow = req.clone();
        let req_deny = req.clone();
        let host_allow = host.clone();
        dialogs::show_permission_prompt(
            &win,
            &host,
            kind,
            move || {
                profile::set_site_permission(&host_allow, kind, "allow");
                req_allow.allow();
            },
            move || req_deny.deny(),
        );
    }

    pub fn open_reader_mode(&self) {
        let Some(win) = self.app_window() else { return };
        let title = self
            .active_webview()
            .and_then(|w| w.title().map(|g| g.to_string()))
            .unwrap_or_else(|| "Page".into());
        let uri = self.active_uri().unwrap_or_else(|| "about:blank".into());
        dialogs::show_reader_overlay(&win, &title, &uri);
    }

    pub fn open_translation(&self) {
        let Some(win) = self.app_window() else { return };
        let uri = self.active_uri().unwrap_or_else(|| "about:blank".into());
        dialogs::show_translation_popover(&win, &uri);
    }

    pub fn rebuild_extensions_popover(&self) {
        let vbox = GtkBox::new(Orientation::Vertical, 8);
        vbox.set_margin_top(8);
        vbox.set_margin_bottom(8);
        vbox.set_margin_start(8);
        vbox.set_margin_end(8);
        vbox.append(&Label::new(Some("Extensions runtime")));
        for info in self.extension_infos.borrow().iter() {
            let row = GtkBox::new(Orientation::Horizontal, 8);
            row.append(&Label::new(Some(&info.name)));
            let sw = Switch::new();
            sw.set_active(profile::extension_enabled(&info.id));
            let id = info.id.clone();
            sw.connect_active_notify(move |switch| {
                profile::set_extension_enabled(&id, switch.is_active());
            });
            row.append(&sw);
            vbox.append(&row);
        }
        let manage = Button::with_label("Manage extensions");
        let infos = self.extension_infos.borrow().clone();
        let win_weak = self.app_window().map(|w| w.downgrade());
        manage.connect_clicked(move |_| {
            if let Some(win) = win_weak.as_ref().and_then(|w| w.upgrade()) {
                dialogs::show_extensions_list(&infos, &win);
            }
        });
        vbox.append(&manage);
        self.extensions_popover.set_child(Some(&vbox));
    }

    pub fn app_window(&self) -> Option<ApplicationWindow> {
        self.notebook
            .root()
            .and_then(|w| w.downcast::<ApplicationWindow>().ok())
    }

    pub fn on_audio_state_changed(&self, playing: bool) {
        if playing {
            self.status_label.set_text("Tab playing audio");
        } else if self.status_label.text().as_str() == "Tab playing audio" {
            self.status_label.set_text("");
        }
    }

    pub fn on_download_started(self: &Rc<Self>, download: &Download) {
        let Some(dir) = downloads_dir() else { return };
        let dir_str = dir.to_string_lossy().to_string();
        let idx = self.index.clone();
        let st = self.clone();
        download.connect_decide_destination(move |dl, suggested| {
            let suggested = suggested.to_string();
            let dest = std::path::PathBuf::from(&dir_str).join(&suggested);
            let dest_str = dest.to_string_lossy().to_string();
            dl.set_destination(&dest_str);
            if let Some(ref idx) = idx {
                let id = idx.start_download(&suggested, "", &dest_str, 0);
                let idx2 = idx.clone();
                let st2 = st.clone();
                dl.connect_finished(move |_| {
                    if id >= 0 {
                        idx2.download_complete(id);
                    }
                    st2.refresh_downloads_list();
                });
            }
            true
        });
        self.refresh_downloads_list();
    }

    pub fn on_load_changed(&self, wv: &WebView, event: LoadEvent) {
        self.back_btn.set_sensitive(wv.can_go_back());
        self.fwd_btn.set_sensitive(wv.can_go_forward());
        match event {
            LoadEvent::Started => {
                self.reload_btn.set_visible(false);
                self.stop_btn.set_visible(true);
                *self.last_error.borrow_mut() = None;
            }
            LoadEvent::Committed | LoadEvent::Finished => {
                if matches!(event, LoadEvent::Finished) {
                    self.reload_btn.set_visible(true);
                    self.stop_btn.set_visible(false);
                }
                if let Some(uri) = wv.uri() {
                    let u = uri.as_str();
                    self.url_entry.set_text(u);
                    if harness_mode() {
                        self.url_entry.update_property(&[
                            Aria::Label("Address bar"),
                            Aria::Description(u),
                        ]);
                    }
                    self.update_bookmark_icon(u);
                    self.update_lock_icon_from_webview(wv, u);
                    self.reader_icon.set_visible(u.contains("wikipedia.org") || u.contains("/article"));
                }
            }
            _ => {}
        }
        if matches!(event, LoadEvent::Finished) {
            if let (Some(idx), Some(uri)) = (self.index.as_ref(), wv.uri()) {
                let title = wv.title().map(|g| g.to_string()).unwrap_or_default();
                idx.record_visit(&title, uri.as_str());
            }
        }
    }

    pub fn close_page_webview(self: &Rc<Self>, wv: &WebView) {
        if let Some(n) = self.notebook.page_num(wv) {
            self.notebook.remove_page(Some(n));
            if self.tab_meta.borrow_mut().len() > n as usize {
                self.tab_meta.borrow_mut().remove(n as usize);
            }
        }
        if self.notebook.n_pages() == 0 {
            self.open_new_tab("about:blank");
        }
        self.persist_open_tabs();
        self.sidebar.refresh(self);
    }

    pub fn close_active_tab(self: &Rc<Self>) {
        if let Some(wv) = self.active_webview() {
            self.close_page_webview(&wv);
        }
    }

    pub fn duplicate_active_tab(self: &Rc<Self>) {
        if let Some(uri) = self.active_uri() {
            self.open_new_tab(&uri);
        }
    }

    pub fn pin_active_tab(&self) {
        let n = self.notebook.current_page().unwrap_or(0) as usize;
        let mut meta = self.tab_meta.borrow_mut();
        if let Some(m) = meta.get_mut(n) {
            m.pinned = !m.pinned;
        }
        self.refresh_tab_labels();
    }

    fn refresh_tab_labels(&self) {
        let meta = self.tab_meta.borrow();
        for i in 0..self.notebook.n_pages() {
            let Some(page) = self.notebook.nth_page(Some(i)) else { continue };
            let Some(label_box) = self.notebook.tab_label(&page).and_then(|w| w.downcast::<GtkBox>().ok()) else {
                continue;
            };
            let Some(title_lbl) = label_box.first_child().and_then(|c| c.downcast::<Label>().ok()) else {
                continue;
            };
            let base = self
                .notebook
                .tab_label_text(&page)
                .map(|g| g.to_string())
                .unwrap_or_else(|| format!("Tab {}", i + 1));
            let pinned = meta.get(i as usize).map(|m| m.pinned).unwrap_or(false);
            let text = if pinned {
                format!("📌 {base}")
            } else {
                base
            };
            title_lbl.set_text(&text);
        }
    }

    pub fn mute_active_tab(&self) {
        if let Some(wv) = self.active_webview() {
            let next = !wv.is_muted();
            wv.set_is_muted(next);
            let n = self.notebook.current_page().unwrap_or(0) as usize;
            let mut meta = self.tab_meta.borrow_mut();
            if let Some(m) = meta.get_mut(n) {
                m.muted = next;
            }
        }
    }

    pub fn close_other_tabs(self: &Rc<Self>) {
        let current = self.notebook.current_page().unwrap_or(0);
        let mut to_close = Vec::new();
        for i in 0..self.notebook.n_pages() {
            if i != current {
                if let Some(wv) = self
                    .notebook
                    .nth_page(Some(i))
                    .and_then(|p| p.downcast::<WebView>().ok())
                {
                    to_close.push(wv);
                }
            }
        }
        for wv in to_close {
            self.close_page_webview(&wv);
        }
    }

    pub fn show_tab_context_menu(&self, widget: &impl IsA<gtk::Widget>, x: f64, y: f64) {
        let m = gtk::gio::Menu::new();
        m.append(Some("Duplicate Tab"), Some("win.duplicate-tab"));
        m.append(Some("Pin Tab"), Some("win.pin-tab"));
        m.append(Some("Mute Tab"), Some("win.mute-tab"));
        m.append(Some("Close Other Tabs"), Some("win.close-other-tabs"));
        m.append(Some("Add to Reading List"), Some("win.reading-list"));
        let menu = gtk::PopoverMenu::from_model(Some(&m));
        menu.set_parent(widget);
        let rect = gtk::gdk::Rectangle::new(x as i32, y as i32, 1, 1);
        menu.set_pointing_to(Some(&rect));
        menu.popup();
    }

    pub fn add_to_reading_list(&self) {
        if let (Some(idx), Some(uri)) = (self.index.as_ref(), self.active_uri()) {
            idx.set_reading_list(&uri, true);
            self.sidebar.refresh(self);
        }
    }

    pub fn open_inspector(&self) {
        if let Some(wv) = self.active_webview() {
            if let Some(inspector) = wv.inspector() {
                inspector.show();
            }
        }
    }

    pub fn persist_open_tabs(&self) {
        if self.private || harness_active() || *self.restoring_tabs.borrow() {
            return;
        }
        self.persist_open_tabs_inner();
    }

    fn persist_open_tabs_inner(&self) {
        let Some(ref idx) = self.index else { return };
        let mut tabs = Vec::new();
        let n = self.notebook.n_pages();
        let current = self.notebook.current_page().unwrap_or(0);
        for i in 0..n {
            let url = self
                .notebook
                .nth_page(Some(i))
                .and_then(|p| p.downcast::<WebView>().ok())
                .and_then(|wv| wv.uri().map(|s| s.to_string()))
                .unwrap_or_else(|| "about:blank".into());
            let title = self
                .notebook
                .nth_page(Some(i))
                .and_then(|page| self.notebook.tab_label_text(&page))
                .map(|g| g.to_string())
                .unwrap_or_else(|| format!("Tab {}", i + 1));
            let meta = self.tab_meta.borrow().get(i as usize).cloned().unwrap_or_default();
            tabs.push(OpenTab {
                window_id: self.window_id,
                sort_index: i as i32,
                url,
                title,
                group_id: meta.group_id,
                is_pinned: meta.pinned,
                is_active: i == current,
            });
        }
        idx.set_open_tabs(self.window_id, &tabs);
        if harness_active() || harness_restore() {
            let snap: Vec<_> = tabs
                .iter()
                .map(|t| (t.url.clone(), t.title.clone(), t.is_pinned, t.is_active))
                .collect();
            profile::write_harness_open_tabs_snapshot(&snap);
        }
    }

    pub fn sync_chrome_to_active(&self) {
        if let Some(wv) = self.active_webview() {
            self.back_btn.set_sensitive(wv.can_go_back());
            self.fwd_btn.set_sensitive(wv.can_go_forward());
            let uri = wv.uri().map(|s| s.to_string()).unwrap_or_default();
            self.url_entry.set_text(&uri);
            self.update_bookmark_icon(&uri);
            self.update_lock_icon(&uri);
        }
    }

    pub fn refresh_chrome(&self) {
        self.sync_chrome_to_active();
        self.refresh_bookmarks_bar();
    }

    fn toggle_bookmark(&self, btn: &Button) {
        let Some(wv) = self.active_webview() else { return };
        let Some(uri) = wv.uri() else { return };
        let url = uri.to_string();
        if url.is_empty() || url == "about:blank" { return; }
        let Some(idx) = self.index.as_ref() else { return };
        let on = idx.is_bookmarked(&url);
        idx.set_bookmarked(&url, !on);
        btn.set_icon_name(if on { "non-starred-symbolic" } else { "starred-symbolic" });
        self.refresh_bookmarks_bar();
    }

    fn update_bookmark_icon(&self, url: &str) {
        let starred = self.index.as_ref().map(|i| i.is_bookmarked(url)).unwrap_or(false);
        self.bookmark_btn.set_icon_name(if starred { "starred-symbolic" } else { "non-starred-symbolic" });
    }

    fn update_lock_icon_from_webview(&self, wv: &WebView, url: &str) {
        let secure = url.starts_with("https://")
            && wv.tls_info().map(|(_, flags)| flags.is_empty()).unwrap_or(true);
        if secure {
            self.url_entry
                .set_primary_icon_name(Some("system-lock-screen-symbolic"));
            self.url_entry
                .set_primary_icon_tooltip_text(Some("Secure connection"));
        } else {
            self.url_entry.set_primary_icon_name(None);
            self.url_entry.set_primary_icon_tooltip_text(None);
        }
    }

    fn update_lock_icon(&self, url: &str) {
        if let Some(wv) = self.active_webview() {
            self.update_lock_icon_from_webview(&wv, url);
        }
    }

    pub fn refresh_suggestions(&self, prefix: &str) {
        while let Some(c) = self.suggestions_list.first_child() {
            self.suggestions_list.remove(&c);
        }
        if prefix.trim().is_empty() {
            self.suggestions_popover.popdown();
            return;
        }
        let rows = self.index.as_ref().map(|i| i.query(prefix, 8)).unwrap_or_default();
        if rows.is_empty() {
            self.suggestions_popover.popdown();
            return;
        }
        for s in rows {
            self.suggestions_list.append(&suggestion_row(&s));
        }
        self.suggestions_popover.popup();
    }

    pub fn run_find(&self, q: &str) {
        let Some(wv) = self.active_webview() else { return };
        let Some(fc) = wv.find_controller() else { return };
        if q.is_empty() {
            fc.search_finish();
            self.find_count.set_text("");
            return;
        }
        fc.search(q, FindOptions::CASE_INSENSITIVE.bits(), 1024);
    }

    pub fn adjust_zoom(&self, delta: f64) {
        let mut z = self.zoom_level.borrow_mut();
        *z = (*z + delta).clamp(0.5, 3.0);
        if let Some(wv) = self.active_webview() {
            wv.set_zoom_level(*z);
        }
    }

    pub fn refresh_bookmarks_bar(&self) {
        while let Some(c) = self.bookmarks_bar.first_child() {
            self.bookmarks_bar.remove(&c);
        }
        let Some(idx) = self.index.as_ref() else { return };
        for bm in idx.bookmarks_flat(16) {
            let url = bm.subtitle.clone();
            let label = if bm.title.is_empty() { url.clone() } else { bm.title.clone() };
            let btn = Button::with_label(&label);
            btn.set_tooltip_text(Some(&url));
            let notebook = self.notebook.clone();
            btn.connect_clicked(move |_| {
                if let Some(n) = notebook.current_page() {
                    if let Some(p) = notebook.nth_page(Some(n)) {
                        if let Ok(wv) = p.downcast::<WebView>() {
                            wv.load_uri(&url);
                        }
                    }
                }
            });
            self.bookmarks_bar.append(&btn);
        }
    }

    pub fn refresh_downloads_list(&self) {
        while let Some(c) = self.downloads_list.first_child() {
            self.downloads_list.remove(&c);
        }
        let Some(idx) = self.index.as_ref() else { return };
        for d in idx.downloads(32) {
            let row = ListBoxRow::new();
            let h = GtkBox::new(Orientation::Horizontal, 6);
            let label = if d.completed {
                format!("{} — done", d.filename)
            } else {
                format!("{} — {}%", d.filename, (d.bytes_received * 100 / d.bytes_total.max(1)))
            };
            h.append(&Label::new(Some(&label)));
            if d.completed && !d.dest_path.is_empty() {
                let path = d.dest_path.clone();
                let reveal = Button::with_label("Show in folder");
                reveal.update_property(&[Aria::Label("Show download in folder")]);
                reveal.connect_clicked(move |_| dialogs::reveal_download(&path));
                h.append(&reveal);
            } else if !d.completed {
                let id = d.id;
                let idx2 = idx.clone();
                let cancel = Button::with_label("Cancel");
                cancel.update_property(&[Aria::Label("Cancel download")]);
                cancel.connect_clicked(move |_| idx2.download_cancel(id));
                h.append(&cancel);
            }
            row.set_child(Some(&h));
            self.downloads_list.append(&row);
        }
    }
}

fn suggestion_row(s: &Suggestion) -> ListBoxRow {
    let glyph = match s.kind {
        SuggestionKind::TopHit => "★",
        SuggestionKind::History => "⟲",
        SuggestionKind::Bookmark => "♥",
        SuggestionKind::Search => "🔍",
        SuggestionKind::Site => "•",
    };
    let v = GtkBox::new(Orientation::Vertical, 0);
    v.append(&Label::new(Some(&format!("{glyph} {}", s.title))));
    v.append(&Label::new(Some(&s.subtitle)));
    ListBoxRow::builder().child(&v).build()
}

fn host_from_uri(uri: &str) -> String {
    uri.split("//")
        .nth(1)
        .and_then(|rest| rest.split('/').next())
        .unwrap_or(uri)
        .to_string()
}

fn permission_kind_label(req: &PermissionRequest) -> &'static str {
    if req.is::<UserMediaPermissionRequest>() {
        "camera and microphone"
    } else if req.is::<GeolocationPermissionRequest>() {
        "location"
    } else if req.is::<NotificationPermissionRequest>() {
        "notifications"
    } else if req.is::<DeviceInfoPermissionRequest>() {
        "device info"
    } else {
        "permission"
    }
}
