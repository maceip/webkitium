//! Collapsible sidebar — tabs list, bookmarks, reading list, shared-with-you placeholder.

use gtk4 as gtk;
use gtk::accessible::Property as Aria;
use gtk::glib::clone;
use gtk::prelude::*;
use webkit6::prelude::*;
use gtk::{Box as GtkBox, Label, ListBox, ListBoxRow, Orientation, Stack, StackSwitcher};
use std::cell::RefCell;
use std::rc::Rc;

use crate::ui::browser_window::WindowState;

pub struct SidebarChrome {
    pub paned: gtk::Paned,
    pub sidebar_box: GtkBox,
    pub stack: Stack,
    pub tabs_list: ListBox,
    pub bookmarks_list: ListBox,
    pub reading_list: ListBox,
    pub shared_list: ListBox,
    pub tab_count_label: Label,
    pub visible: Rc<RefCell<bool>>,
}

impl SidebarChrome {
    pub fn new_shell() -> Self {
        let sidebar_box = GtkBox::new(Orientation::Vertical, 0);
        sidebar_box.set_width_request(260);
        sidebar_box.update_property(&[Aria::Label("Sidebar")]);

        let tab_count_label = Label::new(Some("0 Tabs"));
        tab_count_label.add_css_class("title-4");
        tab_count_label.set_margin_start(12);
        tab_count_label.set_margin_top(8);
        tab_count_label.update_property(&[Aria::Label("Sidebar tab count")]);

        let switcher = StackSwitcher::new();
        let stack = Stack::new();
        switcher.set_stack(Some(&stack));

        let tabs_page = GtkBox::new(Orientation::Vertical, 0);
        let tabs_list = ListBox::new();
        tabs_list.update_property(&[Aria::Label("Sidebar tabs list")]);
        tabs_page.append(&tabs_list);

        let bookmarks_page = GtkBox::new(Orientation::Vertical, 0);
        let bookmarks_list = ListBox::new();
        bookmarks_list.update_property(&[Aria::Label("Sidebar bookmarks")]);
        bookmarks_page.append(&bookmarks_list);

        let reading_page = GtkBox::new(Orientation::Vertical, 0);
        let reading_list = ListBox::new();
        reading_list.update_property(&[Aria::Label("Reading list")]);
        reading_page.append(&reading_list);

        let shared_page = GtkBox::new(Orientation::Vertical, 0);
        let shared_list = ListBox::new();
        shared_list.update_property(&[Aria::Label("Shared with You")]);
        shared_page.append(&shared_list);

        stack.add_named(&tabs_page, Some("tabs"));
        stack.add_named(&bookmarks_page, Some("bookmarks"));
        stack.add_named(&reading_page, Some("reading"));
        stack.add_named(&shared_page, Some("shared"));
        stack.set_visible_child_name("tabs");

        sidebar_box.append(&tab_count_label);
        sidebar_box.append(&switcher);
        sidebar_box.append(&stack);
        stack.set_vexpand(true);

        let paned = gtk::Paned::new(gtk::Orientation::Horizontal);
        paned.set_start_child(Some(&sidebar_box));
        paned.set_resize_start_child(false);
        paned.set_shrink_start_child(false);
        paned.set_position(260);

        let visible = Rc::new(RefCell::new(true));

        SidebarChrome {
            paned,
            sidebar_box,
            stack,
            tabs_list,
            bookmarks_list,
            reading_list,
            shared_list,
            tab_count_label,
            visible,
        }
    }

    pub fn refresh(&self, state: &WindowState) {
        while let Some(c) = self.tabs_list.first_child() {
            self.tabs_list.remove(&c);
        }
        let n = state.notebook.n_pages();
        for i in 0..n {
            let title = state
                .notebook
                .nth_page(Some(i))
                .and_then(|page| state.notebook.tab_label_text(&page))
                .map(|g| g.to_string())
                .unwrap_or_else(|| format!("Tab {}", i + 1));
            let row = ListBoxRow::new();
            let lbl = Label::new(Some(&title));
            lbl.update_property(&[Aria::Label(&format!("Select tab: {title}"))]);
            row.set_child(Some(&lbl));
            self.tabs_list.append(&row);
        }
        self.tab_count_label
            .set_text(&format!("{n} Tab{}", if n == 1 { "" } else { "s" }));
        self.tab_count_label.update_property(&[Aria::Label(&format!(
            "Sidebar tab count {n}"
        ))]);

        if let Some(ref idx) = state.index {
            while let Some(c) = self.bookmarks_list.first_child() {
                self.bookmarks_list.remove(&c);
            }
            for bm in idx.bookmarks_flat(64) {
                let row = ListBoxRow::new();
                let lbl = Label::new(Some(&bm.title));
                lbl.set_tooltip_text(Some(&bm.subtitle));
                row.set_child(Some(&lbl));
                self.bookmarks_list.append(&row);
            }
            while let Some(c) = self.reading_list.first_child() {
                self.reading_list.remove(&c);
            }
            for item in idx.reading_list(64) {
                let row = ListBoxRow::new();
                let lbl = Label::new(Some(&item.title));
                lbl.set_tooltip_text(Some(&item.subtitle));
                row.set_child(Some(&lbl));
                self.reading_list.append(&row);
            }
        }
        while let Some(c) = self.shared_list.first_child() {
            self.shared_list.remove(&c);
        }
        let samples = [
            ("Article from iPhone", "https://example.com/article"),
            ("Safari Shared Tab", "https://example.org"),
        ];
        for (title, url) in samples {
            let row = ListBoxRow::new();
            let lbl = Label::new(Some(title));
            lbl.set_tooltip_text(Some(url));
            row.set_child(Some(&lbl));
            self.shared_list.append(&row);
        }
    }

    pub fn set_visible_sidebar(&self, show: bool) {
        *self.visible.borrow_mut() = show;
        self.sidebar_box.set_visible(show);
        if show {
            self.paned.set_position(260);
        } else {
            self.paned.set_position(0);
        }
    }

    pub fn attach_content(&self, content: &impl IsA<gtk::Widget>) {
        self.paned.set_end_child(Some(content));
        self.paned.set_resize_end_child(true);
        self.paned.set_shrink_end_child(true);
    }

    pub fn wire(&self, state: &Rc<WindowState>) {
        let st = state.clone();
        self.tabs_list.connect_row_activated(move |_, row| {
            st.notebook.set_current_page(Some(row.index() as u32));
        });
        let st2 = state.clone();
        self.bookmarks_list.connect_row_activated(move |_, row| {
            if let Some(label) = row.child().and_downcast::<Label>() {
                let url = label.tooltip_text().unwrap_or(label.text()).to_string();
                if let Some(wv) = st2.active_webview() {
                    wv.load_uri(&url);
                }
            }
        });
        let st3 = state.clone();
        self.reading_list.connect_row_activated(move |_, row| {
            if let Some(label) = row.child().and_downcast::<Label>() {
                let url = label.tooltip_text().unwrap_or(label.text()).to_string();
                if let Some(wv) = st3.active_webview() {
                    wv.load_uri(&url);
                }
            }
        });
        let st4 = state.clone();
        self.shared_list.connect_row_activated(move |_, row| {
            if let Some(label) = row.child().and_downcast::<Label>() {
                let url = label.tooltip_text().unwrap_or(label.text()).to_string();
                if let Some(wv) = st4.active_webview() {
                    wv.load_uri(&url);
                }
            }
        });
    }
}
