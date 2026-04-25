// C ABI for browser/sync/ -- wired-but-inactive surface for shells.
//
// Exposes a single LoopbackSyncServer-backed status object so each shell
// can report record-count / version / birthday.  No commit / get-updates
// transport is exposed yet -- the bridge is read-only by design.

#ifndef WEBKITIUM_SYNC_BRIDGE_C_H_
#define WEBKITIUM_SYNC_BRIDGE_C_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WkSyncStatus WkSyncStatus;

WkSyncStatus* wk_sync_create(void);
void          wk_sync_destroy(WkSyncStatus*);

// Total records currently stored on the loopback server (incl. permanent
// roots, so a fresh server returns the count of pre-seeded roots --
// non-zero is fine).
int           wk_sync_record_count(const WkSyncStatus*);

// Monotonic server version. -1 if handle is null.
int64_t       wk_sync_current_version(const WkSyncStatus*);

// Caller must free with wk_sync_string_free.  Stable for the lifetime
// of the handle.
char*         wk_sync_store_birthday(const WkSyncStatus*);

void          wk_sync_string_free(char*);

#ifdef __cplusplus
}
#endif

#endif  // WEBKITIUM_SYNC_BRIDGE_C_H_
