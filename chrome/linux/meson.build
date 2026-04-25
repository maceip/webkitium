project('webkitium', ['c', 'cpp'],
  version: '0.1.0',
  meson_version: '>= 0.62',
  default_options: ['warning_level=2', 'cpp_std=c++17'],
)

gnome = import('gnome')

gtk_dep = dependency('gtk4', version: '>= 4.12')
adw_dep = dependency('libadwaita-1', version: '>= 1.4')

# Optional: wire in WebKitGTK for the web view
webkit_dep = dependency('webkitgtk-6.0', required: false)

conf = configuration_data()
conf.set_quoted('APP_ID', 'dev.webkitium.Browser')
conf.set_quoted('APP_VERSION', meson.project_version())
conf.set10('HAVE_WEBKIT', webkit_dep.found())

configure_file(
  output: 'config.h',
  configuration: conf,
)

# ---- C ABI bridges from browser/ ---------------------------------------
# Wired-but-inactive: extensions / sync / webauthn / color controllers
# compiled into a static library the GTK shell links against.  Same
# sources every other shell pulls in (see chrome/windows/native/,
# browser/{color,extensions,sync,webauthn}/Package.swift,
# chrome/android/app/src/main/cpp/CMakeLists.txt).

browser_root = meson.project_source_root() / '..' / '..' / 'browser'

webkitium_bridges = static_library('webkitium_bridges',
  sources: files(
    # color/
    browser_root / 'color' / 'ColorBridgeC.cc',
    browser_root / 'color' / 'ColorRamp.cpp',
    browser_root / 'color' / 'OklchColor.cpp',
    browser_root / 'color' / 'SemanticPalette.cpp',
    # extensions/
    browser_root / 'extensions' / 'ExtensionBridgeC.cc',
    browser_root / 'extensions' / 'ExtensionManifest.cpp',
    browser_root / 'extensions' / 'ExtensionRegistry.cpp',
    # sync/  (stub today)
    browser_root / 'sync' / 'SyncBridgeC.cc',
    # webauthn/
    browser_root / 'core' / 'Origin.cpp',
    browser_root / 'webauthn' / 'WebAuthnBridgeC.cc',
    browser_root / 'webauthn' / 'WebAuthnController.cpp',
  ),
  include_directories: include_directories(browser_root),
  cpp_args: ['-fvisibility=hidden'],
  install: false,
)

webkitium_bridges_dep = declare_dependency(
  link_with: webkitium_bridges,
  include_directories: include_directories(browser_root),
)

# ---- GTK4 / libadwaita executable --------------------------------------

sources = files(
  'src/main.c',
  'src/wk-application.c',
  'src/wk-window.c',
  'src/wk-sidebar.c',
  'src/wk-omnibar.c',
  'src/wk-tab-content.c',
  'src/wk-services.c',
)

deps = [gtk_dep, adw_dep, webkitium_bridges_dep]
if webkit_dep.found()
  deps += webkit_dep
endif

executable('webkitium',
  sources,
  dependencies: deps,
  install: true,
)

install_data('data/dev.webkitium.Browser.desktop',
  install_dir: get_option('datadir') / 'applications',
)
