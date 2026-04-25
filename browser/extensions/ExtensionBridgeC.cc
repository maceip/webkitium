#include "extensions/ExtensionBridgeC.h"

#include <cstdlib>
#include <cstring>
#include <new>

#include "extensions/ExtensionRegistry.h"

extern "C" {

struct WkExtensionRegistry {
    ng::ExtensionRegistry registry;
};

WkExtensionRegistry* wk_extensions_create(void) {
    return new (std::nothrow) WkExtensionRegistry{};
}

void wk_extensions_destroy(WkExtensionRegistry* h) {
    delete h;
}

int wk_extensions_count(const WkExtensionRegistry* h) {
    if (!h) return 0;
    return static_cast<int>(h->registry.installedExtensions().size());
}

namespace {

char* DupString(const std::string& s) {
    char* out = static_cast<char*>(std::malloc(s.size() + 1));
    if (!out) return nullptr;
    std::memcpy(out, s.data(), s.size());
    out[s.size()] = '\0';
    return out;
}

}  // namespace

char* wk_extensions_id_at(const WkExtensionRegistry* h, int index) {
    if (!h) return nullptr;
    auto manifests = h->registry.installedExtensions();
    if (index < 0 || static_cast<size_t>(index) >= manifests.size())
        return nullptr;
    return DupString(manifests[index].id);
}

char* wk_extensions_name_at(const WkExtensionRegistry* h, int index) {
    if (!h) return nullptr;
    auto manifests = h->registry.installedExtensions();
    if (index < 0 || static_cast<size_t>(index) >= manifests.size())
        return nullptr;
    return DupString(manifests[index].name);
}

void wk_extensions_string_free(char* s) {
    std::free(s);
}

}  // extern "C"
