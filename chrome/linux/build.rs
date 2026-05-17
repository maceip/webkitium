// Build the C++ browser core via the existing CMakeLists.txt at
// `../../browser/`, then bindgen the two C ABI headers we consume from
// Rust. The static library `ng_browser_core` is the link target; the
// generated Rust bindings land in $OUT_DIR and are `include!`d from
// `src/ffi/*.rs`.

use std::env;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let browser_src = manifest_dir.join("../../browser").canonicalize()
        .expect("browser/ must exist relative to chrome/linux/");

    // ---- 1. Build the C++ static library via cmake. ----
    //
    // The existing browser/CMakeLists.txt declares `ng_browser_core` as a
    // STATIC library. The `cmake` crate runs configure + build and
    // returns the install prefix.
    let dst = cmake::Config::new(&browser_src)
        .build_target("ng_browser_core")
        .build();

    // cmake crate puts build artefacts under `<OUT_DIR>/build`. The
    // static lib path is `<build>/libng_browser_core.a` for single-config
    // generators (Make/Ninja) — we tell rustc to search there.
    println!("cargo:rustc-link-search=native={}/build", dst.display());
    println!("cargo:rustc-link-lib=static=ng_browser_core");

    // Protobuf + sync helper static libs declared in the same CMake project.
    println!("cargo:rustc-link-lib=static=ng_chromium_sync_proto");
    println!("cargo:rustc-link-lib=protobuf");

    // SQLite — `browser/suggestions/SuggestionIndex.cpp` calls sqlite3
    // directly. The browser CMakeLists doesn't declare a system sqlite
    // dependency, so the shell pulls it in. On Debian/Ubuntu/Fedora the
    // package is `libsqlite3-dev` / `sqlite-devel`.
    println!("cargo:rustc-link-lib=sqlite3");

    // pthread — std::mutex in browser/. Modern glibc usually folds this
    // into libc, but linking it explicitly avoids surprise on minimal
    // distros / musl.
    println!("cargo:rustc-link-lib=pthread");

    // C++ runtime — needed because the static lib is C++. `cfg!` in a
    // build script evaluates against the HOST, not the target — use the
    // env var so a future cross-compile picks the right runtime.
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    match target_os.as_str() {
        "linux" | "freebsd" | "android" => println!("cargo:rustc-link-lib=stdc++"),
        "macos" | "ios" => println!("cargo:rustc-link-lib=c++"),
        _ => {} // windows handled separately; not a supported target for this crate
    }

    // ---- 2. bindgen the two C ABI headers. ----
    let url_header = browser_src.join("url/UrlBridgeC.h");
    let suggestions_header = browser_src.join("suggestions/SuggestionsBridgeC.h");

    println!("cargo:rerun-if-changed={}", url_header.display());
    println!("cargo:rerun-if-changed={}", suggestions_header.display());

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());

    bindgen::Builder::default()
        .header(url_header.to_string_lossy())
        .clang_arg("-x")
        .clang_arg("c")
        .allowlist_function("wk_url_.*")
        .allowlist_function("wk_search_engine_.*")
        .generate()
        .expect("bindgen failed for UrlBridgeC.h")
        .write_to_file(out_dir.join("url_bridge.rs"))
        .expect("write url_bridge.rs");

    bindgen::Builder::default()
        .header(suggestions_header.to_string_lossy())
        .clang_arg("-x")
        .clang_arg("c")
        .allowlist_function("wk_suggestions_.*")
        .allowlist_function("wk_bookmarks_.*")
        .allowlist_function("wk_tab_groups_.*")
        .allowlist_function("wk_open_tabs_.*")
        .allowlist_function("wk_downloads_.*")
        .allowlist_type("Wk.*")
        .generate()
        .expect("bindgen failed for SuggestionsBridgeC.h")
        .write_to_file(out_dir.join("suggestions_bridge.rs"))
        .expect("write suggestions_bridge.rs");
}
