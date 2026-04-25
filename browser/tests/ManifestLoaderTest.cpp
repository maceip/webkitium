#include "extensions/ExtensionManifest.h"
#include "extensions/ExtensionRegistry.h"
#include "extensions/ManifestLoader.h"

#include <cassert>
#include <cstdlib>
#include <iostream>
#include <string>

namespace {

int g_failures = 0;

#define EXPECT(cond)                                                        \
    do {                                                                    \
        if (!(cond)) {                                                      \
            std::cerr << "FAIL " << __FILE__ << ":" << __LINE__             \
                      << "  " #cond << "\n";                                \
            ++g_failures;                                                   \
        }                                                                   \
    } while (0)

#define EXPECT_EQ(a, b)                                                     \
    do {                                                                    \
        auto a_ = (a);                                                      \
        auto b_ = (b);                                                      \
        if (!(a_ == b_)) {                                                  \
            std::cerr << "FAIL " << __FILE__ << ":" << __LINE__             \
                      << "  " #a " == " #b "  (" << a_ << " vs " << b_     \
                      << ")\n";                                             \
            ++g_failures;                                                   \
        }                                                                   \
    } while (0)

// ---- happy path -------------------------------------------------------

void TestMinimalValidManifest() {
    const std::string json = R"({
        "manifest_version": 3,
        "name": "Hello",
        "version": "1.0.0"
    })";
    auto r = ng::loadManifestFromString(json, "abc-extension-id");
    EXPECT(r);
    if (!r) { std::cerr << "  err: " << r.error().message << "\n"; return; }
    EXPECT_EQ(r.value().id, std::string("abc-extension-id"));
    EXPECT(r.value().version == ng::ExtensionManifestVersion::ManifestV3);
    EXPECT_EQ(r.value().name, std::string("Hello"));
    EXPECT_EQ(r.value().versionString, std::string("1.0.0"));
    EXPECT(r.value().permissions.empty());
}

void TestRichManifest() {
    const std::string json = R"({
        "manifest_version": 3,
        "name": "Webkitium Devtools",
        "version": "0.2.1",
        "description": "Diagnostic tools",
        "permissions": ["storage", "tabs"],
        "host_permissions": ["https://example.com/*", "https://*.test/*"],
        "background": {
            "service_worker": "background.js"
        },
        "action": {
            "default_title": "Open Devtools",
            "default_popup": "popup.html"
        },
        "side_panel": {
            "default_path": "panel.html"
        },
        "content_scripts": [
            { "matches": ["<all_urls>", "https://example.com/*"], "js": ["cs.js"] }
        ]
    })";
    auto r = ng::loadManifestFromString(json, "rich-id");
    EXPECT(r);
    if (!r) return;
    const auto& m = r.value();
    EXPECT_EQ(m.name, std::string("Webkitium Devtools"));
    EXPECT_EQ(m.versionString, std::string("0.2.1"));
    EXPECT_EQ(m.permissions.size(), size_t{2});
    EXPECT(m.declaresPermission("storage"));
    EXPECT(m.declaresPermission("tabs"));
    EXPECT(!m.declaresPermission("downloads"));
    EXPECT_EQ(m.hostPermissions.size(), size_t{2});
    EXPECT_EQ(m.backgroundServiceWorkers.size(), size_t{1});
    EXPECT_EQ(m.backgroundServiceWorkers[0], std::string("background.js"));
    EXPECT_EQ(m.action.defaultTitle, std::string("Open Devtools"));
    EXPECT_EQ(m.action.defaultPopupPath, std::string("popup.html"));
    EXPECT_EQ(m.sidePanel.defaultPath, std::string("panel.html"));
    EXPECT_EQ(m.contentScriptMatches.size(), size_t{2});
}

void TestInstallAfterLoad() {
    const std::string json = R"({
        "manifest_version": 3,
        "name": "Pipe Demo",
        "version": "0.1.0"
    })";
    auto r = ng::loadManifestFromString(json, "pipe-demo");
    EXPECT(r);
    if (!r) return;
    ng::ExtensionRegistry registry;
    EXPECT(registry.install(std::move(r.value())));
    EXPECT_EQ(registry.installedExtensions().size(), size_t{1});
    auto* found = registry.get("pipe-demo");
    EXPECT(found != nullptr);
    if (found) EXPECT_EQ(found->name, std::string("Pipe Demo"));
}

// ---- error paths ------------------------------------------------------

void TestRejectsManifestV2() {
    const std::string json = R"({"manifest_version": 2, "name": "x", "version": "1"})";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(!r);
}

void TestRejectsMissingManifestVersion() {
    const std::string json = R"({"name": "x", "version": "1"})";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(!r);
}

void TestRejectsMissingName() {
    const std::string json = R"({"manifest_version": 3, "version": "1"})";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(!r);
}

void TestRejectsTrailingGarbage() {
    const std::string json = R"({"manifest_version": 3, "name": "x", "version": "1"} EXTRA)";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(!r);
}

void TestRejectsTruncatedJson() {
    const std::string json = R"({"manifest_version": 3, "name": "x")";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(!r);
}

void TestRejectsRootArray() {
    const std::string json = R"([1,2,3])";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(!r);
}

// ---- escapes / unicode -------------------------------------------------

void TestStringEscapes() {
    const std::string json = R"({
        "manifest_version": 3,
        "name": "Tab\tQuote\"Backslash\\End",
        "version": "1.0"
    })";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(r);
    if (!r) return;
    EXPECT_EQ(r.value().name, std::string("Tab\tQuote\"Backslash\\End"));
}

void TestUnicodeEscape() {
    // é is é (UTF-8 0xC3 0xA9)
    const std::string json = R"({
        "manifest_version": 3,
        "name": "Café",
        "version": "1.0"
    })";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(r);
    if (!r) return;
    EXPECT_EQ(r.value().name.size(), size_t{5});  // C-a-f-c3-a9
    EXPECT_EQ(static_cast<unsigned char>(r.value().name[3]), 0xC3u);
    EXPECT_EQ(static_cast<unsigned char>(r.value().name[4]), 0xA9u);
}

void TestUnknownKeyIgnored() {
    const std::string json = R"({
        "manifest_version": 3,
        "name": "Forward",
        "version": "1.0",
        "future_field_we_dont_know": { "anything": [1, 2, 3] }
    })";
    auto r = ng::loadManifestFromString(json, "id");
    EXPECT(r);  // tolerant; unknown keys ignored
}

}  // namespace

int main() {
    TestMinimalValidManifest();
    TestRichManifest();
    TestInstallAfterLoad();
    TestRejectsManifestV2();
    TestRejectsMissingManifestVersion();
    TestRejectsMissingName();
    TestRejectsTrailingGarbage();
    TestRejectsTruncatedJson();
    TestRejectsRootArray();
    TestStringEscapes();
    TestUnicodeEscape();
    TestUnknownKeyIgnored();

    if (g_failures > 0) {
        std::cerr << g_failures << " assertion failure(s)\n";
        return EXIT_FAILURE;
    }
    std::cout << "ManifestLoaderTest: all checks passed\n";
    return 0;
}
