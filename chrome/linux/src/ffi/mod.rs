// Safe Rust wrappers around the two C ABI surfaces exposed by
// `ng_browser_core`. Raw bindgen output is `include!`d at the bottom of
// the relevant submodule; nothing in this crate touches the raw types
// outside the submodule that owns them.

pub mod extensions;
pub mod suggestions;
pub mod url;
