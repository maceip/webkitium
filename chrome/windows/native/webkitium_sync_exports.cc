// Windows DLL export stamp for browser/sync/SyncBridgeC.h.

#include <cstdint>

extern "C" {

struct WkSyncStatus;

WkSyncStatus* wk_sync_create(void);
void          wk_sync_destroy(WkSyncStatus*);
int           wk_sync_record_count(const WkSyncStatus*);
int64_t       wk_sync_current_version(const WkSyncStatus*);
char*         wk_sync_store_birthday(const WkSyncStatus*);
void          wk_sync_string_free(char*);

__declspec(dllexport) WkSyncStatus* wk_sync_create_export(void) { return wk_sync_create(); }
__declspec(dllexport) void wk_sync_destroy_export(WkSyncStatus* h) { wk_sync_destroy(h); }
__declspec(dllexport) int wk_sync_record_count_export(const WkSyncStatus* h) { return wk_sync_record_count(h); }
__declspec(dllexport) int64_t wk_sync_current_version_export(const WkSyncStatus* h) { return wk_sync_current_version(h); }
__declspec(dllexport) char* wk_sync_store_birthday_export(const WkSyncStatus* h) { return wk_sync_store_birthday(h); }
__declspec(dllexport) void wk_sync_string_free_export(char* s) { wk_sync_string_free(s); }

}
