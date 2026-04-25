#include "sync/SyncBridgeC.h"

#include <cstdlib>
#include <cstring>
#include <new>

// Wired-but-inactive stub.  The portable LoopbackSyncServer is a
// substantial transitive dep (protobuf-generated wire types, RPC layer,
// SyncTypes), so for the first pass each shell just instantiates this
// trivial status surface.  When sync is activated the implementation
// swaps in a real LoopbackSyncServer-backed handle behind the same C
// ABI -- all callers stay unchanged.

extern "C" {

struct WkSyncStatus {
    // Reserved.  When activated this owns a LoopbackSyncServer.
    int    record_count    = 0;
    int64_t current_version = 0;
    const char* birthday    = "";
};

WkSyncStatus* wk_sync_create(void) {
    return new (std::nothrow) WkSyncStatus{};
}

void wk_sync_destroy(WkSyncStatus* h) {
    delete h;
}

int wk_sync_record_count(const WkSyncStatus* h) {
    return h ? h->record_count : 0;
}

int64_t wk_sync_current_version(const WkSyncStatus* h) {
    return h ? h->current_version : -1;
}

char* wk_sync_store_birthday(const WkSyncStatus* h) {
    if (!h || !h->birthday) return nullptr;
    size_t n = std::strlen(h->birthday);
    char* out = static_cast<char*>(std::malloc(n + 1));
    if (!out) return nullptr;
    std::memcpy(out, h->birthday, n);
    out[n] = '\0';
    return out;
}

void wk_sync_string_free(char* s) {
    std::free(s);
}

}  // extern "C"
