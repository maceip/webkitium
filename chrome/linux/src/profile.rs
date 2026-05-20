//! Profile paths and lightweight JSON prefs (settings, site permissions, welcome).

use std::fs;
use std::path::{Path, PathBuf};

use webkit6::NetworkSession;

/// Root profile directory (XDG or `WEBKITIUM_PROFILE_DIR`).
pub fn profile_root() -> Option<PathBuf> {
    if let Ok(dir) = std::env::var("WEBKITIUM_PROFILE_DIR") {
        let p = PathBuf::from(dir);
        fs::create_dir_all(&p).ok()?;
        return Some(p);
    }
    let base = std::env::var("XDG_DATA_HOME")
        .ok()
        .map(PathBuf::from)
        .or_else(|| std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(".local/share")))?;
    let dir = base.join("Webkitium");
    fs::create_dir_all(&dir).ok()?;
    Some(dir)
}

/// Persistent WebKit cookies/cache under the profile root; ephemeral for private windows.
pub fn create_network_session(private: bool) -> NetworkSession {
    if private {
        return NetworkSession::new_ephemeral();
    }
    let Some(root) = profile_root() else {
        return NetworkSession::new(None, None);
    };
    let data = root.join("webkit-data");
    let cache = root.join("webkit-cache");
    let _ = fs::create_dir_all(&data);
    let _ = fs::create_dir_all(&cache);
    NetworkSession::new(
        data.to_str(),
        cache.to_str(),
    )
}

/// Apply `WEBKITIUM_PROFILE_DIR` or `--profile-dir` before GTK/WebKit init.
pub fn set_profile_dir_from_args(args: impl IntoIterator<Item = impl AsRef<str>>) {
    for arg in args {
        let a = arg.as_ref();
        if let Some(dir) = a.strip_prefix("--profile-dir=") {
            std::env::set_var("WEBKITIUM_PROFILE_DIR", dir);
            return;
        }
        if a == "--profile-dir" {
            // Handled in main with index; see parse_profile_dir_arg.
        }
    }
}

pub fn parse_profile_dir_arg(args: &[String]) -> Option<PathBuf> {
    let mut i = 0;
    while i < args.len() {
        if let Some(dir) = args[i].strip_prefix("--profile-dir=") {
            return Some(PathBuf::from(dir));
        }
        if args[i] == "--profile-dir" && i + 1 < args.len() {
            return Some(PathBuf::from(&args[i + 1]));
        }
        i += 1;
    }
    None
}

pub fn ensure_profile_dir(path: &Path) {
    let _ = fs::create_dir_all(path);
}

pub fn suggestions_db_path(private: bool) -> Option<PathBuf> {
    if private {
        // Empty path → in-memory DB in SuggestionIndex.cpp.
        return Some(PathBuf::new());
    }
    profile_root().map(|d| d.join("suggestions.db"))
}

pub fn downloads_dir() -> Option<PathBuf> {
    if let Ok(d) = std::env::var("WEBKITIUM_DOWNLOADS_DIR") {
        let p = PathBuf::from(d);
        fs::create_dir_all(&p).ok()?;
        return Some(p);
    }
    let home = std::env::var("HOME").ok().map(PathBuf::from)?;
    let d = home.join("Downloads");
    fs::create_dir_all(&d).ok()?;
    Some(d)
}

pub fn settings_path() -> Option<PathBuf> {
    profile_root().map(|d| d.join("settings.json"))
}

pub fn site_permissions_path() -> Option<PathBuf> {
    profile_root().map(|d| d.join("site_permissions.json"))
}

pub fn welcome_done_path() -> Option<PathBuf> {
    profile_root().map(|d| d.join(".welcome_done"))
}

#[derive(Debug, Clone, Default)]
pub struct AppSettings {
    pub search_engine_id: String,
    pub show_welcome: bool,
    pub active_profile: String,
}

impl AppSettings {
    pub fn load() -> Self {
        let Some(path) = settings_path() else {
            return Self::default_loaded();
        };
        let Ok(data) = fs::read_to_string(&path) else {
            return Self::default_loaded();
        };
        parse_settings_json(&data).unwrap_or_else(Self::default_loaded)
    }

    pub fn save(&self) {
        let Some(path) = settings_path() else { return };
        let body = format_settings_json(self);
        let _ = fs::write(path, body);
    }

    fn default_loaded() -> Self {
        Self {
            search_engine_id: "duckduckgo".into(),
            show_welcome: !welcome_done_path().map(|p| p.exists()).unwrap_or(false),
            active_profile: "Personal".into(),
        }
    }
}

fn parse_settings_json(data: &str) -> Option<AppSettings> {
    let mut engine = None;
    let mut profile = None;
    for line in data.lines() {
        let line = line.trim();
        if let Some(v) = line.strip_prefix("\"search_engine\":") {
            engine = Some(trim_json_str(v));
        }
        if let Some(v) = line.strip_prefix("\"profile\":") {
            profile = Some(trim_json_str(v));
        }
    }
    Some(AppSettings {
        search_engine_id: engine.unwrap_or_else(|| "duckduckgo".into()),
        show_welcome: false,
        active_profile: profile.unwrap_or_else(|| "Personal".into()),
    })
}

fn format_settings_json(s: &AppSettings) -> String {
    format!(
        "{{\n  \"search_engine\": \"{}\",\n  \"profile\": \"{}\"\n}}\n",
        escape_json(&s.search_engine_id),
        escape_json(&s.active_profile)
    )
}

fn trim_json_str(s: &str) -> String {
    s.trim()
        .trim_matches(|c| c == '"' || c == ',' || c == ' ')
        .to_string()
}

fn escape_json(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"")
}

pub fn mark_welcome_done() {
    if let Some(p) = welcome_done_path() {
        let _ = fs::write(p, "1");
    }
}

pub fn load_site_permission(host: &str, key: &str) -> Option<String> {
    let path = site_permissions_path()?;
    let data = fs::read_to_string(path).ok()?;
    let needle = format!("\"{host}\"");
    data.lines()
        .find(|l| l.contains(&needle) && l.contains(key))
        .map(|_| "allow".into())
}

pub fn set_site_permission(host: &str, key: &str, value: &str) {
    let Some(path) = site_permissions_path() else { return };
    let mut lines: Vec<String> = fs::read_to_string(&path)
        .unwrap_or_else(|_| "{\n".into())
        .lines()
        .map(str::to_string)
        .collect();
    if !lines.iter().any(|l| l.contains('}')) {
        lines.push("}".into());
    }
    let entry = format!("  \"{host}.{key}\": \"{value}\",");
    if let Some(pos) = lines.iter().position(|l| l.trim() == "}") {
        lines.insert(pos, entry);
    } else {
        lines.push(entry);
        lines.push("}".into());
    }
    let _ = fs::write(path, lines.join("\n"));
}

pub fn write_web_app_desktop_file(title: &str, url: &str) -> Option<PathBuf> {
    let root = profile_root()?;
    let apps = root.join("web-apps");
    fs::create_dir_all(&apps).ok()?;
    let safe: String = title
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '_' })
        .collect();
    let path = apps.join(format!("{safe}.desktop"));
    let body = format!(
        "[Desktop Entry]\nType=Application\nName={title}\nExec=webkitium %u\nIcon=web-browser-symbolic\nStartupWMClass=Webkitium\nMimeType=x-scheme-handler/http;x-scheme-handler/https;\n",
    );
    let _ = fs::write(&path, body.replace("%u", url));
    Some(path)
}
