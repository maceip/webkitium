// Safe wrapper for `browser/suggestions/SuggestionsBridgeC.h`.
//
// Lifecycle:
//   - `Index::open(path)` owns the underlying `WkSuggestionsIndex*`.
//   - `Drop` calls `wk_suggestions_close`. No double-free, no leak.
//   - `query`, `bookmarks_flat`, etc. return `Vec<Suggestion>` by copying
//     out into Rust-owned types. The `Results` RAII guard is the
//     load-bearing rule: every C ABI call that fills a `WkSuggestionResults`
//     is paired with `wk_suggestions_release_results` via `Drop`.

use std::ffi::{CStr, CString};

#[allow(non_upper_case_globals, non_camel_case_types, non_snake_case, dead_code)]
mod raw {
    include!(concat!(env!("OUT_DIR"), "/suggestions_bridge.rs"));
}

/// Mirrors `WkSuggestionKind` from the C ABI.
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
        // C ABI guarantees these 5 values.
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

/// Opaque handle to a suggestions DB. Drop closes it.
pub struct Index {
    inner: *mut raw::WkSuggestionsIndex,
}

unsafe impl Send for Index {}
unsafe impl Sync for Index {}

/// RAII guard around `WkSuggestionResults`. Drop calls
/// `wk_suggestions_release_results`. Never expose `inner` outside this
/// module — readers go through `as_slice`.
struct Results {
    inner: raw::WkSuggestionResults,
}

impl Results {
    fn empty() -> Self {
        // Zero-initialised; the C side overwrites on success.
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
            // SAFETY: rows + count are a valid C-side array for the
            // lifetime of `self`; `Drop` releases the holder.
            unsafe { std::slice::from_raw_parts(self.inner.rows, self.inner.count) }
        }
    }
}

impl Drop for Results {
    fn drop(&mut self) {
        if !self.inner._opaque.is_null() {
            // SAFETY: matches the fill_results call that produced it.
            unsafe { raw::wk_suggestions_release_results(&mut self.inner) };
        }
    }
}

fn copy_c_str(p: *const std::os::raw::c_char) -> String {
    if p.is_null() {
        return String::new();
    }
    // SAFETY: caller asserts NUL-terminated; we just copy.
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
    /// Open (or create) a suggestions DB at `path`. Pass an empty path
    /// for an in-memory DB (used by private windows on every other
    /// platform).
    pub fn open(path: &str) -> Option<Self> {
        let c_path = CString::new(path).ok()?;
        // SAFETY: the C side either returns a valid handle or NULL.
        let inner = unsafe { raw::wk_suggestions_open(c_path.as_ptr()) };
        if inner.is_null() {
            return None;
        }
        Some(Index { inner })
    }

    /// Record a page visit — feeds the ranking index used by URL bar
    /// autocomplete on every platform.
    pub fn record_visit(&self, title: &str, url: &str) {
        let Ok(c_title) = CString::new(title) else {
            return;
        };
        let Ok(c_url) = CString::new(url) else { return };
        // SAFETY: pointers valid for the duration of the call.
        unsafe {
            raw::wk_suggestions_record_visit(self.inner, c_title.as_ptr(), c_url.as_ptr());
        }
    }

    pub fn set_bookmarked(&self, url: &str, bookmarked: bool) {
        let Ok(c_url) = CString::new(url) else { return };
        // The C ABI takes an int for the bool flag.
        unsafe {
            raw::wk_suggestions_set_bookmarked(
                self.inner,
                c_url.as_ptr(),
                if bookmarked { 1 } else { 0 },
            );
        }
    }

    /// URL-bar autocomplete query. Returns up to `limit` ranked
    /// suggestions for `prefix`. Empty `prefix` returns the top recent
    /// visits.
    pub fn query(&self, prefix: &str, limit: usize) -> Vec<Suggestion> {
        let Ok(c_prefix) = CString::new(prefix) else {
            return Vec::new();
        };
        let mut results = Results::empty();
        // SAFETY: results.inner is valid; C side fills it.
        let ok = unsafe {
            raw::wk_suggestions_query(
                self.inner,
                c_prefix.as_ptr(),
                limit,
                &mut results.inner,
            )
        };
        if ok != 1 {
            return Vec::new();
        }
        results.as_slice().iter().map(row_to_suggestion).collect()
    }

    /// Returns the user's bookmarks, flattened across folders, up to
    /// `limit` rows.
    pub fn bookmarks_flat(&self, limit: usize) -> Vec<Suggestion> {
        let mut results = Results::empty();
        let ok = unsafe { raw::wk_suggestions_bookmarks_flat(self.inner, limit, &mut results.inner) };
        if ok != 1 {
            return Vec::new();
        }
        results.as_slice().iter().map(row_to_suggestion).collect()
    }

    /// True iff `url` is currently bookmarked. Implemented on top of
    /// `bookmarks_flat` (no dedicated single-row probe in the C ABI yet).
    pub fn is_bookmarked(&self, url: &str) -> bool {
        // Cap at 2000 — large enough to cover any reasonable user's
        // bookmark count without being unbounded.
        self.bookmarks_flat(2000)
            .iter()
            .any(|s| s.subtitle == url)
    }
}

impl Drop for Index {
    fn drop(&mut self) {
        // SAFETY: matches the `wk_suggestions_open` that produced `inner`.
        unsafe {
            raw::wk_suggestions_close(self.inner);
        }
    }
}
