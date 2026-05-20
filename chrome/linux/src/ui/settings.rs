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
    let discover = Label::new(Some("Extensions store — discover pane placeholder."));
    ext_box.append(&discover);
    stack.add_named(&ext_box, Some("extensions"));

    let sync_pane = GtkBox::new(Orientation::Vertical, 8);
    sync_pane.set_margin_top(16);
    sync_pane.set_margin_start(16);
    sync_pane.append(&Label::new(Some("Sync pairing — QR + backup code (placeholder).")));
    stack.add_named(&sync_pane, Some("sync"));

    let profiles = GtkBox::new(Orientation::Vertical, 8);
    profiles.set_margin_top(16);
    profiles.set_margin_start(16);
    profiles.append(&Label::new(Some("Browser profiles: Personal / Work")));
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
