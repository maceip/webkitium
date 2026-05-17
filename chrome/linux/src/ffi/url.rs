// Safe wrapper for `browser/url/UrlBridgeC.h`.
//
// The load-bearing function in this crate is `normalize` — it's also
// the canonical example of the FFI memory-ownership pattern every other
// wrapper should follow:
//
//   1. Convert Rust &str into CString (NUL-terminated). Reject NULs.
//   2. Call the C function with the raw pointer.
//   3. If the C side returns an owned heap pointer, copy it into a
//      Rust-owned `String`, then call the matching `*_free` to release
//      the C side's allocation.
//
// Anywhere this pattern looks tedious, that's a feature: every FFI
// allocation is paired with its free in the same function body, so
// audit is local.

use std::ffi::{CStr, CString};
use std::ptr;

#[allow(non_upper_case_globals, non_camel_case_types, non_snake_case, dead_code)]
mod raw {
    include!(concat!(env!("OUT_DIR"), "/url_bridge.rs"));
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NormalizeKind {
    /// Input was (or became after `https://` prepending) a URL.
    Url,
    /// Input was a search query; the returned string is the engine's
    /// search results URL.
    Search,
}

/// Normalize a URL-bar input. Returns `None` for empty/invalid input;
/// otherwise returns `(kind, resolved_url)` where `resolved_url` is
/// always something `WebView::load_uri` can accept.
///
/// `engine_id` is one of `"duckduckgo"`, `"brave"`, `"kagi"`,
/// `"google"`. Unknown values fall back to `"duckduckgo"` on the C
/// side.
pub fn normalize(input: &str, engine_id: &str) -> Option<(NormalizeKind, String)> {
    let c_input = CString::new(input).ok()?;
    let c_engine = CString::new(engine_id).ok()?;
    let mut out: *mut std::os::raw::c_char = ptr::null_mut();

    // SAFETY: `wk_url_normalize` reads the two C strings (no retention
    // past the call) and writes a heap-allocated pointer to `out` only
    // when it returns >= 0. We free `out` below.
    let kind_code = unsafe {
        raw::wk_url_normalize(c_input.as_ptr(), c_engine.as_ptr(), &mut out)
    };

    if kind_code < 0 || out.is_null() {
        return None;
    }
    let resolved = unsafe { CStr::from_ptr(out) }
        .to_string_lossy()
        .into_owned();
    unsafe { raw::wk_url_free(out) };

    let kind = match kind_code {
        0 => NormalizeKind::Url,
        1 => NormalizeKind::Search,
        _ => return None, // contract: only -1/0/1 are defined
    };
    Some((kind, resolved))
}

/// Strip tracking query parameters (`utm_*`, `fbclid`, `gclid`, …).
/// Returns `None` only on allocation failure / NUL in input.
pub fn scrub_tracking(url: &str) -> Option<String> {
    let c_url = CString::new(url).ok()?;
    // SAFETY: returns a fresh malloc'd buffer or NULL on error.
    let raw_ptr = unsafe { raw::wk_url_scrub_tracking(c_url.as_ptr()) };
    if raw_ptr.is_null() { return None; }
    let s = unsafe { CStr::from_ptr(raw_ptr) }.to_string_lossy().into_owned();
    unsafe { raw::wk_url_free(raw_ptr) };
    Some(s)
}

/// Build the engine's search-results URL for `query`. `None` for
/// unknown engines.
pub fn search_url(engine_id: &str, query: &str) -> Option<String> {
    let c_engine = CString::new(engine_id).ok()?;
    let c_query = CString::new(query).ok()?;
    let raw_ptr = unsafe {
        raw::wk_search_engine_search_url(c_engine.as_ptr(), c_query.as_ptr())
    };
    if raw_ptr.is_null() { return None; }
    let s = unsafe { CStr::from_ptr(raw_ptr) }.to_string_lossy().into_owned();
    unsafe { raw::wk_url_free(raw_ptr) };
    Some(s)
}

/// Build the engine's suggestion-API URL for `query`. `None` for
/// engines without a suggest endpoint (Kagi).
pub fn suggest_url(engine_id: &str, query: &str) -> Option<String> {
    let c_engine = CString::new(engine_id).ok()?;
    let c_query = CString::new(query).ok()?;
    let raw_ptr = unsafe {
        raw::wk_search_engine_suggest_url(c_engine.as_ptr(), c_query.as_ptr())
    };
    if raw_ptr.is_null() { return None; }
    let s = unsafe { CStr::from_ptr(raw_ptr) }.to_string_lossy().into_owned();
    unsafe { raw::wk_url_free(raw_ptr) };
    Some(s)
}
