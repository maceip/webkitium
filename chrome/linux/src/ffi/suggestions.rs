// Safe wrapper for `browser/suggestions/SuggestionsBridgeC.h`.

use std::ffi::{CStr, CString};

#[allow(non_upper_case_globals, non_camel_case_types, non_snake_case, dead_code)]
mod raw {
    include!(concat!(env!("OUT_DIR"), "/suggestions_bridge.rs"));
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SuggestionKind {
    TopHit,
    History,
    Bookmark,
    Search,
    Site,
}

impl SuggestionKind {
    fn from_raw(k: raw::WkSuggestionKind) -> Self {
        match k {
            raw::WkSuggestionKind_WK_SUGGESTION_KIND_TOP_HIT => Self::TopHit,
            raw::WkSuggestionKind_WK_SUGGESTION_KIND_HISTORY => Self::History,
            raw::WkSuggestionKind_WK_SUGGESTION_KIND_BOOKMARK => Self::Bookmark,
            raw::WkSuggestionKind_WK_SUGGESTION_KIND_SEARCH => Self::Search,
            _ => Self::Site,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Suggestion {
    pub kind: SuggestionKind,
    pub title: String,
    pub subtitle: String,
    pub score: f64,
}

#[derive(Debug, Clone)]
pub struct BookmarkFolder {
    pub id: i64,
    pub parent_id: i64,
    pub name: String,
}

#[derive(Debug, Clone)]
pub struct BookmarkEntry {
    pub id: i64,
    pub folder_id: i64,
    pub url: String,
    pub title: String,
}

#[derive(Debug, Clone)]
pub struct TabGroup {
    pub id: i64,
    pub name: String,
    pub color_argb: u32,
}

#[derive(Debug, Clone)]
pub struct OpenTab {
    pub window_id: i64,
    pub sort_index: i32,
    pub url: String,
    pub title: String,
    pub group_id: i64,
    pub is_pinned: bool,
    pub is_active: bool,
}

#[derive(Debug, Clone)]
pub struct DownloadRow {
    pub id: i64,
    pub filename: String,
    pub source_url: String,
    pub dest_path: String,
    pub bytes_total: i64,
    pub bytes_received: i64,
    pub completed: bool,
}

pub struct Index {
    inner: *mut raw::WkSuggestionsIndex,
}

unsafe impl Send for Index {}
unsafe impl Sync for Index {}

struct Results {
    inner: raw::WkSuggestionResults,
}

impl Results {
    fn empty() -> Self {
        Results {
            inner: raw::WkSuggestionResults {
                rows: std::ptr::null(),
                count: 0,
                _opaque: std::ptr::null_mut(),
            },
        }
    }
    fn as_slice(&self) -> &[raw::WkSuggestionRow] {
        if self.inner.rows.is_null() || self.inner.count == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(self.inner.rows, self.inner.count) }
        }
    }
}

impl Drop for Results {
    fn drop(&mut self) {
        if !self.inner._opaque.is_null() {
            unsafe { raw::wk_suggestions_release_results(&mut self.inner) };
        }
    }
}

fn copy_c_str(p: *const std::os::raw::c_char) -> String {
    if p.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned()
}

fn row_to_suggestion(r: &raw::WkSuggestionRow) -> Suggestion {
    Suggestion {
        kind: SuggestionKind::from_raw(r.kind),
        title: copy_c_str(r.title),
        subtitle: copy_c_str(r.subtitle),
        score: r.score,
    }
}

impl Index {
    pub fn open(path: &str) -> Option<Self> {
        let c_path = CString::new(path).ok()?;
        let inner = unsafe { raw::wk_suggestions_open(c_path.as_ptr()) };
        if inner.is_null() {
            return None;
        }
        Some(Index { inner })
    }

    pub fn open_path(path: &std::path::Path) -> Option<Self> {
        let s = path.to_string_lossy();
        Self::open(s.as_ref())
    }

    pub fn clear(&self) {
        unsafe { raw::wk_suggestions_clear(self.inner) };
    }

    pub fn record_visit(&self, title: &str, url: &str) {
        let Ok(c_title) = CString::new(title) else { return };
        let Ok(c_url) = CString::new(url) else { return };
        unsafe {
            raw::wk_suggestions_record_visit(self.inner, c_title.as_ptr(), c_url.as_ptr());
        }
    }

    pub fn set_bookmarked(&self, url: &str, bookmarked: bool) {
        let Ok(c_url) = CString::new(url) else { return };
        unsafe {
            raw::wk_suggestions_set_bookmarked(
                self.inner,
                c_url.as_ptr(),
                if bookmarked { 1 } else { 0 },
            );
        }
    }

    pub fn set_reading_list(&self, url: &str, in_list: bool) {
        let Ok(c_url) = CString::new(url) else { return };
        unsafe {
            raw::wk_suggestions_set_in_reading_list(
                self.inner,
                c_url.as_ptr(),
                if in_list { 1 } else { 0 },
            );
        }
    }

    pub fn query(&self, prefix: &str, limit: usize) -> Vec<Suggestion> {
        let Ok(c_prefix) = CString::new(prefix) else {
            return Vec::new();
        };
        let mut results = Results::empty();
        let ok = unsafe {
            raw::wk_suggestions_query(self.inner, c_prefix.as_ptr(), limit, &mut results.inner)
        };
        if ok != 1 {
            return Vec::new();
        }
        results.as_slice().iter().map(row_to_suggestion).collect()
    }

    pub fn recent_history(&self, query: &str, limit: usize) -> Vec<Suggestion> {
        let Ok(c_q) = CString::new(query) else {
            return Vec::new();
        };
        let mut results = Results::empty();
        let ok = unsafe {
            raw::wk_suggestions_recent_history(
                self.inner,
                c_q.as_ptr(),
                limit,
                &mut results.inner,
            )
        };
        if ok != 1 {
            return Vec::new();
        }
        results.as_slice().iter().map(row_to_suggestion).collect()
    }

    pub fn reading_list(&self, limit: usize) -> Vec<Suggestion> {
        let mut results = Results::empty();
        let ok =
            unsafe { raw::wk_suggestions_reading_list(self.inner, limit, &mut results.inner) };
        if ok != 1 {
            return Vec::new();
        }
        results.as_slice().iter().map(row_to_suggestion).collect()
    }

    pub fn bookmarks_flat(&self, limit: usize) -> Vec<Suggestion> {
        let mut results = Results::empty();
        let ok =
            unsafe { raw::wk_suggestions_bookmarks_flat(self.inner, limit, &mut results.inner) };
        if ok != 1 {
            return Vec::new();
        }
        results.as_slice().iter().map(row_to_suggestion).collect()
    }

    pub fn is_bookmarked(&self, url: &str) -> bool {
        self.bookmarks_flat(2000)
            .iter()
            .any(|s| s.subtitle == url)
    }

    pub fn bookmark_folders(&self) -> Vec<BookmarkFolder> {
        let mut list = raw::WkBookmarkFolderList {
            folders: std::ptr::null(),
            count: 0,
            _opaque: std::ptr::null_mut(),
        };
        let ok = unsafe { raw::wk_bookmarks_folders(self.inner, &mut list) };
        if ok != 1 || list.folders.is_null() {
            return Vec::new();
        }
        let slice = unsafe { std::slice::from_raw_parts(list.folders, list.count) };
        let out: Vec<_> = slice
            .iter()
            .map(|f| BookmarkFolder {
                id: f.id,
                parent_id: f.parent_id,
                name: copy_c_str(f.name),
            })
            .collect();
        unsafe { raw::wk_bookmarks_release_folders(&mut list) };
        out
    }

    pub fn bookmarks_in_folder(&self, folder_id: i64) -> Vec<BookmarkEntry> {
        let mut list = raw::WkBookmarkEntryList {
            entries: std::ptr::null(),
            count: 0,
            _opaque: std::ptr::null_mut(),
        };
        let ok = unsafe { raw::wk_bookmarks_in(self.inner, folder_id, &mut list) };
        if ok != 1 || list.entries.is_null() {
            return Vec::new();
        }
        let slice = unsafe { std::slice::from_raw_parts(list.entries, list.count) };
        let out: Vec<_> = slice
            .iter()
            .map(|e| BookmarkEntry {
                id: e.id,
                folder_id: e.folder_id,
                url: copy_c_str(e.url),
                title: copy_c_str(e.title),
            })
            .collect();
        unsafe { raw::wk_bookmarks_release_entries(&mut list) };
        out
    }

    pub fn add_bookmark_folder(&self, parent_id: i64, name: &str) -> i64 {
        let Ok(c_name) = CString::new(name) else { return -1 };
        unsafe {
            raw::wk_bookmarks_add_folder(self.inner, parent_id, c_name.as_ptr(), std::ptr::null())
        }
    }

    pub fn add_bookmark_entry(&self, folder_id: i64, url: &str, title: &str) -> i64 {
        let Ok(c_url) = CString::new(url) else { return -1 };
        let Ok(c_title) = CString::new(title) else { return -1 };
        unsafe {
            raw::wk_bookmarks_add_entry(
                self.inner,
                folder_id,
                c_url.as_ptr(),
                c_title.as_ptr(),
            )
        }
    }

    pub fn remove_bookmark_entry(&self, entry_id: i64) {
        unsafe { raw::wk_bookmarks_remove_entry(self.inner, entry_id) };
    }

    pub fn tab_groups(&self) -> Vec<TabGroup> {
        let mut list = raw::WkTabGroupList {
            groups: std::ptr::null(),
            count: 0,
            _opaque: std::ptr::null_mut(),
        };
        let ok = unsafe { raw::wk_tab_groups_list(self.inner, &mut list) };
        if ok != 1 || list.groups.is_null() {
            return Vec::new();
        }
        let slice = unsafe { std::slice::from_raw_parts(list.groups, list.count) };
        let out: Vec<_> = slice
            .iter()
            .map(|g| TabGroup {
                id: g.id,
                name: copy_c_str(g.name),
                color_argb: g.color_argb,
            })
            .collect();
        unsafe { raw::wk_tab_groups_release(&mut list) };
        out
    }

    pub fn add_tab_group(&self, name: &str, color_argb: u32) -> i64 {
        let Ok(c_name) = CString::new(name) else { return -1 };
        unsafe { raw::wk_tab_groups_add(self.inner, c_name.as_ptr(), color_argb) }
    }

    pub fn open_tabs(&self, window_id: i64) -> Vec<OpenTab> {
        let mut list = raw::WkOpenTabList {
            tabs: std::ptr::null(),
            count: 0,
            _opaque: std::ptr::null_mut(),
        };
        let ok = unsafe { raw::wk_open_tabs_list(self.inner, window_id, &mut list) };
        if ok != 1 || list.tabs.is_null() {
            return Vec::new();
        }
        let slice = unsafe { std::slice::from_raw_parts(list.tabs, list.count) };
        let out: Vec<_> = slice
            .iter()
            .map(|t| OpenTab {
                window_id: t.window_id,
                sort_index: t.sort_index,
                url: copy_c_str(t.url),
                title: copy_c_str(t.title),
                group_id: t.group_id,
                is_pinned: t.is_pinned != 0,
                is_active: t.is_active != 0,
            })
            .collect();
        unsafe { raw::wk_open_tabs_release(&mut list) };
        out
    }

    pub fn set_open_tabs(&self, window_id: i64, tabs: &[OpenTab]) {
        if tabs.is_empty() {
            unsafe { raw::wk_open_tabs_set(self.inner, window_id, std::ptr::null(), 0) };
            return;
        }
        let mut c_tabs: Vec<raw::WkOpenTab> = Vec::with_capacity(tabs.len());
        let mut holders: Vec<(CString, CString)> = Vec::with_capacity(tabs.len());
        for t in tabs {
            let c_url = CString::new(t.url.as_str()).unwrap_or_default();
            let c_title = CString::new(t.title.as_str()).unwrap_or_default();
            c_tabs.push(raw::WkOpenTab {
                window_id: t.window_id,
                sort_index: t.sort_index,
                url: c_url.as_ptr(),
                title: c_title.as_ptr(),
                group_id: t.group_id,
                is_pinned: if t.is_pinned { 1 } else { 0 },
                is_active: if t.is_active { 1 } else { 0 },
            });
            holders.push((c_url, c_title));
        }
        let _ = holders;
        unsafe {
            raw::wk_open_tabs_set(self.inner, window_id, c_tabs.as_ptr(), c_tabs.len());
        }
    }

    pub fn downloads(&self, limit: usize) -> Vec<DownloadRow> {
        let mut list = raw::WkDownloadList {
            downloads: std::ptr::null(),
            count: 0,
            _opaque: std::ptr::null_mut(),
        };
        let ok = unsafe { raw::wk_downloads_list(self.inner, limit, &mut list) };
        if ok != 1 || list.downloads.is_null() {
            return Vec::new();
        }
        let slice = unsafe { std::slice::from_raw_parts(list.downloads, list.count) };
        let out: Vec<_> = slice
            .iter()
            .map(|d| DownloadRow {
                id: d.id,
                filename: copy_c_str(d.filename),
                source_url: copy_c_str(d.source_url),
                dest_path: copy_c_str(d.dest_path),
                bytes_total: d.bytes_total,
                bytes_received: d.bytes_received,
                completed: d.completed_ms != 0,
            })
            .collect();
        unsafe { raw::wk_downloads_release(&mut list) };
        out
    }

    pub fn start_download(
        &self,
        filename: &str,
        source_url: &str,
        dest_path: &str,
        bytes_total: i64,
    ) -> i64 {
        let Ok(c_fn) = CString::new(filename) else { return -1 };
        let Ok(c_src) = CString::new(source_url) else { return -1 };
        let Ok(c_dst) = CString::new(dest_path) else { return -1 };
        unsafe {
            raw::wk_downloads_start(
                self.inner,
                c_fn.as_ptr(),
                c_src.as_ptr(),
                c_dst.as_ptr(),
                bytes_total,
            )
        }
    }

    pub fn download_progress(&self, id: i64, bytes_received: i64) {
        unsafe { raw::wk_downloads_progress(self.inner, id, bytes_received) };
    }

    pub fn download_complete(&self, id: i64) {
        unsafe { raw::wk_downloads_complete(self.inner, id) };
    }

    pub fn download_cancel(&self, id: i64) {
        unsafe { raw::wk_downloads_cancel(self.inner, id) };
    }
}

impl Drop for Index {
    fn drop(&mut self) {
        unsafe { raw::wk_suggestions_close(self.inner) };
    }
}
