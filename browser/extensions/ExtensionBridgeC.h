// C ABI for browser/extensions/ -- wired-but-inactive surface for shells.
//
// Same shape as browser/color/ColorBridgeC.h: opaque handle, simple
// getters, no C++ symbols cross the boundary.  Each shell instantiates
// one WkExtensionRegistry at app startup so the runtime is alive even
// before any extension UI is exposed.

#ifndef WEBKITIUM_EXTENSIONS_BRIDGE_C_H_
#define WEBKITIUM_EXTENSIONS_BRIDGE_C_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WkExtensionRegistry WkExtensionRegistry;

WkExtensionRegistry* wk_extensions_create(void);
void                 wk_extensions_destroy(WkExtensionRegistry*);

// Number of currently-installed Manifest V3 extensions.
// Returns 0 on a fresh registry.
int                  wk_extensions_count(const WkExtensionRegistry*);

// Caller must free the returned pointer with wk_extensions_string_free.
// Returns NULL if index is out of range.
char*                wk_extensions_id_at(const WkExtensionRegistry*, int index);
char*                wk_extensions_name_at(const WkExtensionRegistry*, int index);

void                 wk_extensions_string_free(char*);

#ifdef __cplusplus
}
#endif

#endif  // WEBKITIUM_EXTENSIONS_BRIDGE_C_H_
