// Windows DLL export stamp for browser/extensions/ExtensionBridgeC.h.
//
// Mirrors the pattern used by webkitium_color_exports.cc: re-declare the
// portable C ABI here with __declspec(dllexport) so C# can DllImport
// without the portable header carrying any Windows-specific markers.

#include <cstdint>

extern "C" {

struct WkExtensionRegistry;

// Forward-declarations from extensions/ExtensionBridgeC.h.
WkExtensionRegistry* wk_extensions_create(void);
void                 wk_extensions_destroy(WkExtensionRegistry*);
int                  wk_extensions_count(const WkExtensionRegistry*);
char*                wk_extensions_id_at(const WkExtensionRegistry*, int);
char*                wk_extensions_name_at(const WkExtensionRegistry*, int);
void                 wk_extensions_string_free(char*);

__declspec(dllexport) WkExtensionRegistry* wk_extensions_create_export(void) {
    return wk_extensions_create();
}
__declspec(dllexport) void wk_extensions_destroy_export(WkExtensionRegistry* h) {
    wk_extensions_destroy(h);
}
__declspec(dllexport) int wk_extensions_count_export(const WkExtensionRegistry* h) {
    return wk_extensions_count(h);
}
__declspec(dllexport) char* wk_extensions_id_at_export(const WkExtensionRegistry* h, int i) {
    return wk_extensions_id_at(h, i);
}
__declspec(dllexport) char* wk_extensions_name_at_export(const WkExtensionRegistry* h, int i) {
    return wk_extensions_name_at(h, i);
}
__declspec(dllexport) void wk_extensions_string_free_export(char* s) {
    wk_extensions_string_free(s);
}

}
