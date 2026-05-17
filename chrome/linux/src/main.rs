// Webkitium GTK Linux shell entry point.
//
// Boots a `gtk::Application` that owns one `AppWindow` (see `window.rs`).
// The browser core (`ng_browser_core`) is linked statically; see
// `build.rs` for how cmake + bindgen are wired.

mod ffi;
mod window;

use gtk4::prelude::*;
use gtk4::{glib, Application};

const APP_ID: &str = "org.webkitium.linux";

fn main() -> glib::ExitCode {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(|app| {
        let win = window::AppWindow::new(app);
        win.present();
    });
    app.run()
}
