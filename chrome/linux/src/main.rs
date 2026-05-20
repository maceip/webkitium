mod app;
mod ffi;
mod profile;
mod ui;

use gtk4::glib;
use std::env;

fn filter_gtk_argv(args: &[String]) -> Vec<String> {
    let mut out = Vec::new();
    if args.is_empty() {
        return out;
    }
    out.push(args[0].clone());
    let mut i = 1;
    while i < args.len() {
        if args[i] == "--profile-dir" {
            i += 2;
            continue;
        }
        if args[i].starts_with("--profile-dir=") {
            i += 1;
            continue;
        }
        out.push(args[i].clone());
        i += 1;
    }
    out
}

fn main() -> glib::ExitCode {
    let args: Vec<String> = env::args().collect();
    if let Some(dir) = profile::parse_profile_dir_arg(&args) {
        profile::ensure_profile_dir(&dir);
        env::set_var("WEBKITIUM_PROFILE_DIR", &dir);
    }
    let gtk_argv = filter_gtk_argv(&args);
    app::WebkitiumApp::new().run_with_args(&gtk_argv)
}
