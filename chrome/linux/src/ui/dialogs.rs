//! Modal dialogs — history, bookmarks manager, tab overview, share, welcome, downloads popover helpers.

use gtk4 as gtk;
use gtk::accessible::Property as Aria;
use gtk::glib::clone;
use gtk::prelude::*;
use webkit6::prelude::*;
use gtk::{
    Box as GtkBox, Button, Dialog, DropDown, Label, ListBox, ListBoxRow, Orientation, ScrolledWindow,
    Window,
};

use std::cell::RefCell;
use std::rc::Rc;

use crate::ffi::extensions::ExtensionInfo;
use crate::ffi::suggestions::Index;
use crate::profile;
use crate::ui::browser_window::WindowState;

pub fn show_welcome(parent: &gtk::ApplicationWindow) {
    let d = Dialog::builder()
        .title("Welcome to Webkitium")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Welcome panel")]);
    let content = GtkBox::new(Orientation::Vertical, 8);
    content.set_margin_top(16);
    content.set_margin_bottom(16);
    content.set_margin_start(16);
    content.set_margin_end(16);
    content.append(&Label::new(Some(
        "Pinned WebKitGTK shell for Linux (Wayland).\nUse the sidebar for tabs and saved pages.",
    )));
    d.set_child(Some(&content));
    d.add_button("Get Started", gtk::ResponseType::Accept);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_history(state: &Rc<WindowState>, parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("History")
        .modal(true)
        .default_width(520)
        .default_height(420)
        .transient_for(parent)
        .build();
    let v = GtkBox::new(Orientation::Vertical, 4);
    let scroll = ScrolledWindow::builder().vexpand(true).build();
    let list = ListBox::new();
    list.update_property(&[Aria::Label("History view")]);

    if let Some(ref idx) = state.index {
        for s in idx.recent_history("", 200) {
            let row = ListBoxRow::new();
            let lbl = Label::new(Some(&format!("{} — {}", s.title, s.subtitle)));
            lbl.set_halign(gtk::Align::Start);
            lbl.set_ellipsize(gtk::pango::EllipsizeMode::End);
            row.set_child(Some(&lbl));
            let url = s.subtitle.clone();
            let st = state.clone();
            row.connect_activate(move |_| {
                if let Some(wv) = st.active_webview() {
                    wv.load_uri(&url);
                }
            });
            list.append(&row);
        }
    }

    scroll.set_child(Some(&list));
    v.append(&scroll);

    let clear = Button::with_label("Clear History");
    clear.update_property(&[Aria::Label("Clear history")]);
    let idx_weak = state.index.clone();
    clear.connect_clicked(move |_| {
        if let Some(ref idx) = idx_weak {
            idx.clear();
        }
    });
    v.append(&clear);

    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_bookmarks_manager(index: &std::rc::Rc<Index>, parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Bookmarks")
        .modal(true)
        .default_width(640)
        .default_height(480)
        .transient_for(parent)
        .build();
    let h = GtkBox::new(Orientation::Horizontal, 8);
    h.set_margin_top(8);
    h.set_margin_start(8);
    h.set_margin_end(8);

    let folders = ListBox::new();
    folders.update_property(&[Aria::Label("Bookmark folders")]);
    let entries = ListBox::new();
    entries.update_property(&[Aria::Label("Bookmark entries")]);
    let entries = std::rc::Rc::new(entries);

    let folder_rows = std::rc::Rc::new(std::cell::RefCell::new(index.bookmark_folders()));
    for f in folder_rows.borrow().iter() {
        let row = ListBoxRow::new();
        row.set_child(Some(&Label::new(Some(&f.name))));
        folders.append(&row);
    }

    let new_folder = Button::with_label("New Folder");
    let idx_new = std::rc::Rc::clone(index);
    new_folder.connect_clicked(move |_| {
        let _ = idx_new.add_bookmark_folder(0, "New Folder");
    });

    let idx_sel = std::rc::Rc::clone(index);
    let folder_rows2 = folder_rows.clone();
    let entries_for_sel = entries.clone();
    folders.connect_row_selected(move |_, row| {
        let Some(row) = row else { return };
        let i = row.index() as usize;
        let Some(folder_id) = folder_rows2.borrow().get(i).map(|f| f.id) else {
            return;
        };
        while let Some(c) = entries_for_sel.first_child() {
            entries_for_sel.remove(&c);
        }
        for e in idx_sel.bookmarks_in_folder(folder_id) {
            let r = ListBoxRow::new();
            r.set_child(Some(&Label::new(Some(&e.title))));
            entries_for_sel.append(&r);
        }
    });

    let left = GtkBox::new(Orientation::Vertical, 4);
    left.append(&new_folder);
    left.append(&folders);
    let right = ScrolledWindow::builder().child(entries.as_ref()).vexpand(true).build();
    h.append(&left);
    h.append(&right);
    d.set_child(Some(&h));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_tab_groups(
    index: &std::rc::Rc<crate::ffi::suggestions::Index>,
    state: &Rc<WindowState>,
    parent: &impl IsA<Window>,
) {
    let d = Dialog::builder()
        .title("Tab Groups")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Tab groups")]);
    let v = GtkBox::new(Orientation::Vertical, 8);
    v.set_margin_top(12);
    v.set_margin_start(12);
    let list = ListBox::new();
    for g in index.tab_groups() {
        let row = ListBoxRow::new();
        row.set_child(Some(&Label::new(Some(&format!("{} (#{})", g.name, g.id)))));
        let st = state.clone();
        let gid = g.id;
        row.connect_activate(move |_| {
            let n = st.notebook.current_page().unwrap_or(0) as usize;
            let mut meta = st.tab_meta.borrow_mut();
            if let Some(m) = meta.get_mut(n) {
                m.group_id = gid;
            }
        });
        list.append(&row);
    }
    let add = Button::with_label("New group");
    add.connect_clicked({
        let index = std::rc::Rc::clone(index);
        let list = list.clone();
        move |_| {
            let id = index.add_tab_group("New Group", 0x4285f4ff);
            if id >= 0 {
                let row = ListBoxRow::new();
                row.set_child(Some(&Label::new(Some(&format!("New Group (#{id})")))));
                list.append(&row);
            }
        }
    });
    v.append(&add);
    v.append(&list);
    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_tab_overview(state: &Rc<WindowState>, parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Tab Overview")
        .modal(true)
        .transient_for(parent)
        .build();
    let grid = ListBox::new();
    grid.update_property(&[Aria::Label("Tab overview")]);
    let n = state.notebook.n_pages();
    for i in 0..n {
        let title = state
            .notebook
            .nth_page(Some(i))
            .and_then(|page| state.notebook.tab_label_text(&page))
            .map(|g| g.to_string())
            .unwrap_or_else(|| format!("Tab {}", i + 1));
        let row = ListBoxRow::new();
        row.set_child(Some(&Label::new(Some(&title))));
        let st = state.clone();
        let idx = i;
        row.connect_activate(move |_| {
            st.notebook.set_current_page(Some(idx as u32));
        });
        grid.append(&row);
    }
    d.set_child(Some(&grid));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_share(uri: &str, parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Share Page")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Share page dialog")]);
    let v = GtkBox::new(Orientation::Vertical, 8);
    v.set_margin_top(12);
    v.set_margin_start(12);
    v.set_margin_end(12);
    let entry = gtk::Entry::builder().text(uri).editable(false).build();
    v.append(&entry);
    let copy = Button::with_label("Copy Link");
    let u = uri.to_string();
    copy.connect_clicked(move |_| {
        if let Some(display) = gtk::gdk::Display::default() {
            let clip = display.clipboard();
            clip.set_text(&u);
        }
    });
    v.append(&copy);
    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_extensions_store(parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Extensions Store")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Extensions store")]);
    let v = GtkBox::new(Orientation::Vertical, 8);
    v.set_margin_top(16);
    v.set_margin_start(16);
    v.append(&Label::new(Some("Discover extensions for Webkitium (preview catalog).")));
    let sample = ListBox::new();
    for name in ["uBlock Lite", "Dark Reader", "JSON Viewer"] {
        let row = ListBoxRow::new();
        row.set_child(Some(&Label::new(Some(name))));
        sample.append(&row);
    }
    v.append(&sample);
    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_sync_pairing(parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Set Up Sync")
        .modal(true)
        .transient_for(parent)
        .default_width(520)
        .default_height(420)
        .build();
    d.update_property(&[Aria::Label("Sync pairing")]);
    let v = GtkBox::new(Orientation::Vertical, 12);
    v.set_margin_top(16);
    v.set_margin_start(16);
    v.append(&Label::new(Some("Scan this code on your phone or enter the backup code:")));
    let code = Label::new(Some("482 931 007"));
    code.add_css_class("title-1");
    v.append(&code);
    let qr = Label::new(Some("[ QR code placeholder ]"));
    qr.set_margin_top(12);
    v.append(&qr);
    v.append(&Label::new(Some("Paired devices: This Mac")));
    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_permission_prompt(
    parent: &impl IsA<Window>,
    host: &str,
    kind: &str,
    on_allow: impl FnOnce() + 'static,
    on_deny: impl FnOnce() + 'static,
) {
    let d = Dialog::builder()
        .title("Site Permission")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Site permission prompt")]);
    let msg = format!("{host} wants to use: {kind}");
    d.set_child(Some(&Label::new(Some(&msg))));
    d.add_button("Deny", gtk::ResponseType::Cancel);
    d.add_button("Allow", gtk::ResponseType::Accept);
    let on_allow = RefCell::new(Some(on_allow));
    let on_deny = RefCell::new(Some(on_deny));
    d.connect_response(move |dialog, resp| {
        if resp == gtk::ResponseType::Accept {
            if let Some(f) = on_allow.take() {
                f();
            }
        } else if let Some(f) = on_deny.take() {
            f();
        }
        dialog.close();
    });
    d.present();
}

pub fn show_extensions_list(extensions: &[ExtensionInfo], parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Extensions")
        .modal(true)
        .transient_for(parent)
        .build();
    let list = ListBox::new();
    list.update_property(&[Aria::Label("Installed extensions list")]);
    if extensions.is_empty() {
        list.append(&Label::new(Some("No extensions installed.")));
    } else {
        for e in extensions {
            let row = ListBoxRow::new();
            row.set_child(Some(&Label::new(Some(&format!("{} ({})", e.name, e.id)))));
            list.append(&row);
        }
    }
    d.set_child(Some(&list));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_site_permissions(parent: &impl IsA<Window>) {
    let d = Dialog::builder()
        .title("Site Permissions")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Site permissions")]);
    let entry = gtk::Entry::builder().placeholder_text("example.com").build();
    let allow_cam = Button::with_label("Allow camera");
    let host = entry.clone();
    allow_cam.connect_clicked(move |_| {
        profile::set_site_permission(&host.text(), "camera", "allow");
    });
    let v = GtkBox::new(Orientation::Vertical, 8);
    v.set_margin_top(12);
    v.set_margin_start(12);
    v.append(&entry);
    v.append(&allow_cam);
    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_passkey_placeholder(parent: &impl IsA<Window>, title: &str) {
    let d = Dialog::builder().title(title).modal(true).transient_for(parent).build();
    d.set_child(Some(&Label::new(Some(
        "Passkey UI uses platform WebAuthn portal when wired to browser/webauthn FFI.",
    ))));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_reader_overlay(parent: &impl IsA<Window>, title: &str, uri: &str) {
    let d = Dialog::builder()
        .title("Reader Mode")
        .modal(true)
        .transient_for(parent)
        .default_width(640)
        .default_height(480)
        .build();
    d.update_property(&[Aria::Label("Reader mode")]);
    let scroll = ScrolledWindow::builder().vexpand(true).build();
    let body = Label::new(Some(&format!(
        "{title}\n\n{uri}\n\nReader view shows simplified article text when the engine exposes reader content."
    )));
    body.set_wrap(true);
    body.set_xalign(0.0);
    body.set_margin_start(12);
    body.set_margin_end(12);
    body.set_margin_top(12);
    scroll.set_child(Some(&body));
    d.set_child(Some(&scroll));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn show_translation_popover(parent: &impl IsA<Window>, page_uri: &str) {
    let d = Dialog::builder()
        .title("Translate Page")
        .modal(true)
        .transient_for(parent)
        .build();
    d.update_property(&[Aria::Label("Translation")]);
    let v = GtkBox::new(Orientation::Vertical, 8);
    v.set_margin_top(12);
    v.set_margin_start(12);
    v.append(&Label::new(Some(&format!("Page: {page_uri}"))));
    v.append(&Label::new(Some("Translate from")));
    v.append(&DropDown::from_strings(&["English", "Spanish", "French"]));
    v.append(&Label::new(Some("Translate to")));
    v.append(&DropDown::from_strings(&["English", "Spanish", "French"]));
    let go = Button::with_label("Translate");
    v.append(&go);
    d.set_child(Some(&v));
    d.add_button("Close", gtk::ResponseType::Close);
    d.connect_response(|d, _| d.close());
    d.present();
}

pub fn reveal_download(path: &str) {
    let _ = std::process::Command::new("xdg-open")
        .arg(std::path::Path::new(path).parent().unwrap_or(std::path::Path::new(".")))
        .spawn();
}
