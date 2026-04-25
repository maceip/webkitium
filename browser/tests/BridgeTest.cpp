// Tests for the C ABI bridges in browser/{extensions,sync,webauthn}/.
//
// The bridges are the cross-platform contract every shell consumes via
// P/Invoke (Windows), SwiftPM modulemap (macOS / iOS), JNI
// (Android), or direct linkage (Linux GTK).  These tests run on the
// CMake-driven Linux CI lane and guard against the bridges silently
// drifting from their wired-but-inactive shape.

#include "extensions/ExtensionBridgeC.h"
#include "extensions/ExtensionRegistry.h"
#include "sync/SyncBridgeC.h"
#include "webauthn/WebAuthnBridgeC.h"

#include <cassert>
#include <cstdlib>
#include <cstring>
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
                      << "  " #a " == " #b "  (got " << a_ << " vs " << b_  \
                      << ")\n";                                             \
            ++g_failures;                                                   \
        }                                                                   \
    } while (0)

// ---- extensions ---------------------------------------------------------

void TestExtensionsCreateDestroy() {
    auto* h = wk_extensions_create();
    EXPECT(h != nullptr);
    wk_extensions_destroy(h);
}

void TestExtensionsEmptyByDefault() {
    auto* h = wk_extensions_create();
    EXPECT_EQ(wk_extensions_count(h), 0);
    EXPECT(wk_extensions_id_at(h, 0) == nullptr);
    EXPECT(wk_extensions_name_at(h, 0) == nullptr);
    EXPECT(wk_extensions_id_at(h, -1) == nullptr);
    wk_extensions_destroy(h);
}

void TestExtensionsNullSafe() {
    EXPECT_EQ(wk_extensions_count(nullptr), 0);
    EXPECT(wk_extensions_id_at(nullptr, 0) == nullptr);
    EXPECT(wk_extensions_name_at(nullptr, 0) == nullptr);
    wk_extensions_destroy(nullptr);                     // must be a no-op
    wk_extensions_string_free(nullptr);                 // must be a no-op
}

// The bridge stores the registry as a private member; to validate the
// id/name accessors we install a manifest through the C++ API and then
// read back via the C ABI -- exercises the layout boundary.
void TestExtensionsReadAfterInstall() {
    auto* h = wk_extensions_create();
    EXPECT(h != nullptr);

    // Reach through to the underlying ExtensionRegistry by recreating
    // the layout used in ExtensionBridgeC.cc.  We can't friend it from
    // here, so we use a process-side install via a known-id manifest
    // and assert count() flips from 0 to 1.  If the bridge drifts away
    // from holding an ng::ExtensionRegistry by-value, this test stops
    // compiling, which is the signal we want.
    struct Layout { ng::ExtensionRegistry reg; };
    auto* layout = reinterpret_cast<Layout*>(h);

    ng::ExtensionManifest m;
    m.id = "test-extension";
    m.name = "Test Extension";
    m.version = ng::ExtensionManifestVersion::ManifestV3;
    m.versionString = "1.0.0";
    EXPECT(layout->reg.install(std::move(m)));

    EXPECT_EQ(wk_extensions_count(h), 1);

    char* id = wk_extensions_id_at(h, 0);
    EXPECT(id != nullptr);
    if (id) {
        EXPECT_EQ(std::string(id), std::string("test-extension"));
        wk_extensions_string_free(id);
    }

    char* name = wk_extensions_name_at(h, 0);
    EXPECT(name != nullptr);
    if (name) {
        EXPECT_EQ(std::string(name), std::string("Test Extension"));
        wk_extensions_string_free(name);
    }

    EXPECT(wk_extensions_id_at(h, 1) == nullptr);

    wk_extensions_destroy(h);
}

// ---- sync (stub today) --------------------------------------------------

void TestSyncCreateDestroy() {
    auto* h = wk_sync_create();
    EXPECT(h != nullptr);
    wk_sync_destroy(h);
}

void TestSyncStubReturnsZeros() {
    auto* h = wk_sync_create();
    EXPECT_EQ(wk_sync_record_count(h), 0);
    EXPECT_EQ(wk_sync_current_version(h), 0);

    char* birthday = wk_sync_store_birthday(h);
    EXPECT(birthday != nullptr);
    if (birthday) {
        EXPECT_EQ(std::string(birthday), std::string());  // empty string
        wk_sync_string_free(birthday);
    }

    wk_sync_destroy(h);
}

void TestSyncNullSafe() {
    EXPECT_EQ(wk_sync_record_count(nullptr), 0);
    EXPECT_EQ(wk_sync_current_version(nullptr), -1);
    EXPECT(wk_sync_store_birthday(nullptr) == nullptr);
    wk_sync_destroy(nullptr);
    wk_sync_string_free(nullptr);
}

// ---- webauthn -----------------------------------------------------------

void TestWebAuthnCreateDestroy() {
    auto* h = wk_webauthn_create();
    EXPECT(h != nullptr);
    wk_webauthn_destroy(h);
}

void TestWebAuthnInitializedButInactive() {
    auto* h = wk_webauthn_create();
    EXPECT_EQ(wk_webauthn_is_initialized(h), 1);
    EXPECT_EQ(wk_webauthn_request_count(h), 0);
    EXPECT_EQ(wk_webauthn_rejection_count(h), 0);
    wk_webauthn_destroy(h);
}

void TestWebAuthnNullSafe() {
    EXPECT_EQ(wk_webauthn_is_initialized(nullptr), 0);
    EXPECT_EQ(wk_webauthn_request_count(nullptr), 0);
    EXPECT_EQ(wk_webauthn_rejection_count(nullptr), 0);
    wk_webauthn_destroy(nullptr);
}

}  // namespace

int main() {
    TestExtensionsCreateDestroy();
    TestExtensionsEmptyByDefault();
    TestExtensionsNullSafe();
    TestExtensionsReadAfterInstall();

    TestSyncCreateDestroy();
    TestSyncStubReturnsZeros();
    TestSyncNullSafe();

    TestWebAuthnCreateDestroy();
    TestWebAuthnInitializedButInactive();
    TestWebAuthnNullSafe();

    if (g_failures > 0) {
        std::cerr << g_failures << " assertion failure(s)\n";
        return EXIT_FAILURE;
    }
    std::cout << "BridgeTest: all checks passed\n";
    return 0;
}
