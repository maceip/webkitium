//! GTK `Application` — menus, multi-window, private browsing entry points.

use gtk4 as gtk;
use gtk::gio;
use gtk::glib::{self, clone};
use gtk::prelude::*;

use std::cell::RefCell;
use std::rc::Rc;

use crate::ffi::extensions::ExtensionRegistry;
use crate::profile::AppSettings;
use crate::ui::browser_window::BrowserWindow;
use crate::ui::dialogs;

const APP_ID: &str = "org.webkitium.linux";

pub struct WebkitiumApp {
    app: gtk::Application,
    settings: Rc<RefCell<AppSettings>>,
    extensions: Option<ExtensionRegistry>,
    next_window_id: RefCell<i64>,
}

impl WebkitiumApp {
    pub fn new() -> Self {
        let settings = Rc::new(RefCell::new(AppSettings::load()));
        let extensions = ExtensionRegistry::new();
        let app = gtk::Application::builder().application_id(APP_ID).build();
        Self {
            app,
            settings,
            extensions,
            next_window_id: RefCell::new(1),
        }
    }

    fn clone_shallow(&self) -> Self {
        WebkitiumApp {
            app: self.app.clone(),
            settings: self.settings.clone(),
            extensions: ExtensionRegistry::new(),
            next_window_id: RefCell::new(*self.next_window_id.borrow()),
        }
    }

    pub fn run_with_args(&self, argv: &[String]) -> glib::ExitCode {
        let this = Rc::new(self.clone_shallow());
        self.app.connect_activate({
            let this = Rc::clone(&this);
            move |app| {
                if app.windows().is_empty() {
                    let private = std::env::var("WEBKITIUM_HARNESS_PRIVATE").is_ok();
                    this.spawn_window(app, private);
                    if std::env::var("WEBKITIUM_HARNESS_SECOND_WINDOW").is_ok() {
                        this.spawn_window(app, false);
                    }
                }
            }
        });
        self.wire_app_menu(&this);
        self.wire_global_accels();
        let glib_argv: Vec<String> = argv
            .iter()
            .filter(|a| !a.starts_with("--profile-dir"))
            .cloned()
            .collect();
        let glib_argv_refs: Vec<&str> = glib_argv.iter().map(String::as_str).collect();
        self.app.run_with_args(&glib_argv_refs)
    }

    fn alloc_window_id(&self) -> i64 {
        let mut n = self.next_window_id.borrow_mut();
        let id = *n;
        *n += 1;
        id
    }

    fn spawn_window(&self, app: &gtk::Application, private: bool) {
        let window_id = self.alloc_window_id();
        let win = BrowserWindow::new(
            app,
            window_id,
            private,
            self.settings.clone(),
            self.extensions.as_ref(),
        );
        win.present();
        let harness = std::env::vars().any(|(k, _)| k.starts_with("WEBKITIUM_HARNESS"));
        let s = self.settings.borrow();
        if s.show_welcome && !harness {
            crate::ui::dialogs::show_welcome(&win.window());
            drop(s);
            self.settings.borrow_mut().show_welcome = false;
            self.settings.borrow().save();
            crate::profile::mark_welcome_done();
        }
    }

    fn wire_app_menu(&self, this: &Rc<Self>) {
        let menu = gio::Menu::new();
        menu.append(Some("New Window"), Some("app.new-window"));
        menu.append(Some("New Private Window"), Some("app.new-private-window"));
        menu.append(Some("Settings"), Some("app.settings"));
        menu.append(Some("Quit"), Some("app.quit"));

        let app_menu = gio::Menu::new();
        app_menu.append_submenu(Some("File"), &menu);

        let view = gio::Menu::new();
        view.append(Some("Downloads"), Some("app.downloads"));
        view.append(Some("History"), Some("app.history"));
        view.append(Some("Bookmarks"), Some("app.bookmarks"));
        view.append(Some("Extensions"), Some("app.extensions"));
        view.append(Some("Reader Mode"), Some("win.reader"));
        view.append(Some("Translate Page"), Some("win.translate"));
        view.append(Some("Add to Reading List"), Some("win.reading-list"));
        view.append(Some("Web Inspector"), Some("win.inspector"));
        view.append(Some("Add to Dock"), Some("win.add-to-dock"));
        view.append(Some("Tab Groups"), Some("win.tab-groups"));
        app_menu.append_submenu(Some("View"), &view);

        let help = gio::Menu::new();
        help.append(Some("Welcome"), Some("app.welcome"));
        app_menu.append_submenu(Some("Help"), &help);

        let menubar = app_menu.clone();
        self.app.connect_startup(move |app| {
            app.set_menubar(Some(&menubar));
        });

        let application = self.app.clone();
        let action_new = gio::SimpleAction::new("new-window", None);
        action_new.connect_activate(clone!(@strong this, @strong application => move |_, _| {
            this.spawn_window(&application, false);
        }));
        let action_private = gio::SimpleAction::new("new-private-window", None);
        action_private.connect_activate(clone!(@strong this, @strong application => move |_, _| {
            this.spawn_window(&application, true);
        }));
        let action_settings = gio::SimpleAction::new("settings", None);
        action_settings.connect_activate(clone!(@strong this => move |_, _| {
            crate::ui::settings::open_settings(this.settings.clone(), this.extensions.as_ref());
        }));
        let action_quit = gio::SimpleAction::new("quit", None);
        action_quit.connect_activate(clone!(@strong application => move |_, _| {
            application.quit();
        }));
        let action_welcome = gio::SimpleAction::new("welcome", None);
        action_welcome.connect_activate(clone!(@strong application => move |_, _| {
            if let Some(w) = application
                .active_window()
                .and_downcast::<gtk::ApplicationWindow>()
            {
                crate::ui::dialogs::show_welcome(&w);
            }
        }));
        let action_history = gio::SimpleAction::new("history", None);
        action_history.connect_activate(clone!(@strong application => move |_, _| {
            if let Some(w) = application.active_window() {
                w.activate_action("win.history", None);
            }
        }));
        let action_bm = gio::SimpleAction::new("bookmarks", None);
        action_bm.connect_activate(clone!(@strong application => move |_, _| {
            if let Some(w) = application.active_window() {
                w.activate_action("win.bookmarks", None);
            }
        }));
        let action_ext = gio::SimpleAction::new("extensions", None);
        action_ext.connect_activate(clone!(@strong this, @strong application => move |_, _| {
            if let Some(w) = application.active_window() {
                let list = this.extensions.as_ref().map(|e| e.list()).unwrap_or_default();
                dialogs::show_extensions_list(&list, &w);
            }
        }));
        let action_dl = gio::SimpleAction::new("downloads", None);
        action_dl.connect_activate(clone!(@strong application => move |_, _| {
            if let Some(w) = application.active_window() {
                let _ = w.activate_action("win.downloads", None);
            }
        }));

        self.app.add_action(&action_new);
        self.app.add_action(&action_private);
        self.app.add_action(&action_settings);
        self.app.add_action(&action_quit);
        self.app.add_action(&action_welcome);
        self.app.add_action(&action_history);
        self.app.add_action(&action_bm);
        self.app.add_action(&action_ext);
        self.app.add_action(&action_dl);
    }

    fn wire_global_accels(&self) {
        self.app.set_accels_for_action("app.new-window", &["<Primary><Shift>n"]);
        self.app.set_accels_for_action("app.new-private-window", &["<Primary><Shift>p"]);
        self.app.set_accels_for_action("app.settings", &["<Primary>comma"]);
        self.app.set_accels_for_action("app.quit", &["<Primary>q"]);
    }
}
