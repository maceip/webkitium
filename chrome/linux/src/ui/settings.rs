//! Standalone settings window with search / passwords / extensions panes.

use gtk4 as gtk;
use gtk::accessible::Property as Aria;
use gtk::glib::clone;
use gtk::prelude::*;
use gtk::{Box as GtkBox, DropDown, Label, ListBox, ListBoxRow, Orientation, Stack, Window};

use std::cell::RefCell;
use std::rc::Rc;

use crate::ffi::extensions::{ExtensionInfo, ExtensionRegistry};
use crate::profile::AppSettings;

const ENGINES: &[&str] = &["duckduckgo", "brave", "kagi", "google"];

pub fn open_settings(settings: Rc<RefCell<AppSettings>>, extensions: Option<&ExtensionRegistry>) {
    let win = Window::builder()
        .title("Webkitium Settings")
        .default_width(720)
        .default_height(480)
        .build();
    win.update_property(&[Aria::Label("Settings window")]);

    let h = GtkBox::new(Orientation::Horizontal, 0);
    let nav = ListBox::builder()
        .width_request(180)
        .selection_mode(gtk::SelectionMode::Single)
        .build();
    for name in ["General", "Search", "Passwords", "Extensions", "Sync", "Profiles"] {
        let row = ListBoxRow::new();
        row.set_child(Some(&Label::new(Some(name))));
        nav.append(&row);
    }

    let stack = Stack::new();
    let general = GtkBox::new(Orientation::Vertical, 8);
    general.set_margin_top(16);
    general.set_margin_start(16);
    general.append(&Label::new(Some("General settings")));
    stack.add_named(&general, Some("general"));

    let search = GtkBox::new(Orientation::Vertical, 8);
    search.set_margin_top(16);
    search.set_margin_start(16);
    search.append(&Label::new(Some("Default search engine")));
    let dropdown = DropDown::from_strings(ENGINES);
    search.append(&dropdown);
    stack.add_named(&search, Some("search"));

    let passwords = GtkBox::new(Orientation::Vertical, 8);
    passwords.set_margin_top(16);
    passwords.set_margin_start(16);
    passwords.append(&Label::new(Some("Passwords and passkeys — autofill toggles.")));
    let passkey_btn = gtk::Button::with_label("Manage passkeys");
    passkey_btn.update_property(&[Aria::Label("Passkey manager")]);
    let win_ref = win.clone();
    passkey_btn.connect_clicked(move |_| {
        crate::ui::dialogs::show_passkey_placeholder(&win_ref, "Passkey Manager");
    });
    passwords.append(&passkey_btn);
    stack.add_named(&passwords, Some("passwords"));

    let ext_box = GtkBox::new(Orientation::Vertical, 8);
    ext_box.set_margin_top(16);
    ext_box.set_margin_start(16);
    let ext_list = ListBox::new();
    let infos: Vec<ExtensionInfo> = extensions.map(|e| e.list()).unwrap_or_default();
    if infos.is_empty() {
        ext_list.append(&Label::new(Some("No extensions installed.")));
    } else {
        for e in &infos {
            let row = ListBoxRow::new();
            row.set_child(Some(&Label::new(Some(&e.name))));
            ext_list.append(&row);
        }
    }
    ext_box.append(&Label::new(Some("Installed extensions")));
    ext_box.append(&ext_list);
    let store_btn = gtk::Button::with_label("Open Extensions Store");
    store_btn.update_property(&[Aria::Label("Extensions store")]);
    let win_store = win.clone();
    store_btn.connect_clicked(move |_| {
        crate::ui::dialogs::show_extensions_store(&win_store);
    });
    ext_box.append(&store_btn);
    stack.add_named(&ext_box, Some("extensions"));

    let sync_pane = GtkBox::new(Orientation::Vertical, 8);
    sync_pane.set_margin_top(16);
    sync_pane.set_margin_start(16);
    sync_pane.append(&Label::new(Some("Sync bookmarks, tabs, and passwords across devices.")));
    let sync_btn = gtk::Button::with_label("Set up sync");
    sync_btn.update_property(&[Aria::Label("Sync pairing")]);
    let win_sync = win.clone();
    sync_btn.connect_clicked(move |_| {
        crate::ui::dialogs::show_sync_pairing(&win_sync);
    });
    sync_pane.append(&sync_btn);
    stack.add_named(&sync_pane, Some("sync"));

    let profiles = GtkBox::new(Orientation::Vertical, 8);
    profiles.set_margin_top(16);
    profiles.set_margin_start(16);
    profiles.append(&Label::new(Some("Active browser profile")));
    let profile_dd = DropDown::from_strings(&["Personal", "Work"]);
    let st_prof = settings.clone();
    profile_dd.connect_selected_notify(move |dd| {
        let names = ["Personal", "Work"];
        let i = dd.selected() as usize;
        if let Some(name) = names.get(i) {
            st_prof.borrow_mut().active_profile = (*name).to_string();
            st_prof.borrow().save();
        }
    });
    profiles.append(&profile_dd);
    stack.add_named(&profiles, Some("profiles"));

    nav.connect_row_selected(clone!(@weak stack => move |_, row| {
        let Some(row) = row else { return };
        let name = match row.index() {
            0 => "general",
            1 => "search",
            2 => "passwords",
            3 => "extensions",
            4 => "sync",
            _ => "profiles",
        };
        stack.set_visible_child_name(name);
    }));
    if let Some(r) = nav.row_at_index(0) {
        nav.select_row(Some(&r));
    }

    h.append(&nav);
    h.append(&stack);
    stack.set_hexpand(true);
    win.set_child(Some(&h));

    let st = settings.clone();
    dropdown.connect_selected_notify(move |dd| {
        let i = dd.selected() as usize;
        if let Some(id) = ENGINES.get(i) {
            st.borrow_mut().search_engine_id = (*id).to_string();
            st.borrow().save();
        }
    });

    win.present();
}
