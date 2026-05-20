//! Extension registry FFI (`browser/extensions/ExtensionBridgeC.h`).

use std::ffi::{CStr, CString};

#[allow(non_upper_case_globals, non_camel_case_types, non_snake_case, dead_code)]
mod raw {
    include!(concat!(env!("OUT_DIR"), "/extensions_bridge.rs"));
}

pub struct ExtensionRegistry {
    inner: *mut raw::WkExtensionRegistry,
}

unsafe impl Send for ExtensionRegistry {}
unsafe impl Sync for ExtensionRegistry {}

#[derive(Debug, Clone)]
pub struct ExtensionInfo {
    pub id: String,
    pub name: String,
}

impl ExtensionRegistry {
    pub fn new() -> Option<Self> {
        let inner = unsafe { raw::wk_extensions_create() };
        if inner.is_null() {
            return None;
        }
        Some(Self { inner })
    }

    pub fn list(&self) -> Vec<ExtensionInfo> {
        let n = unsafe { raw::wk_extensions_count(self.inner) };
        let mut out = Vec::new();
        for i in 0..n {
            let id = copy_owned_string(unsafe { raw::wk_extensions_id_at(self.inner, i) });
            let name = copy_owned_string(unsafe { raw::wk_extensions_name_at(self.inner, i) });
            if let (Some(id), Some(name)) = (id, name) {
                out.push(ExtensionInfo { id, name });
            }
        }
        out
    }
}

impl Drop for ExtensionRegistry {
    fn drop(&mut self) {
        unsafe { raw::wk_extensions_destroy(self.inner) };
    }
}

fn copy_owned_string(p: *mut std::os::raw::c_char) -> Option<String> {
    if p.is_null() {
        return None;
    }
    let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
    unsafe { raw::wk_extensions_string_free(p) };
    Some(s)
}
