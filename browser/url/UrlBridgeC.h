// Pure-C ABI for URL normalization, tracking-param scrubbing, and search
// engine URL construction. Same shape as browser/suggestions/SuggestionsBridgeC.h:
// no C++ types crossing the boundary, no exception propagation, no STL.
//
// All char* returns are heap-allocated and must be freed via `wk_url_free`.
// `wk_url_normalize` writes into `*out_url` only on return >= 0.

#ifndef WEBKITIUM_URL_BRIDGE_C_H_
#define WEBKITIUM_URL_BRIDGE_C_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// kind: 0 = URL (use as-is or with https:// prepended), 1 = search query.
// Returns -1 on empty/invalid input (and leaves *out_url unmodified).
// engine_id is the SearchEngine.rawValue ("duckduckgo", "brave", "kagi",
// "google"). NULL or unknown falls back to "duckduckgo".
int  wk_url_normalize(const char* raw_input, const char* engine_id, char** out_url);

// Returned by normalize/scrub/search/suggest. Must be freed by the caller.
void wk_url_free(char* p);

// Strip tracking query parameters (utm_*, fbclid, gclid, etc).
// Returns a fresh malloc'd string (semantically equal to input if no
// trackers were present). NULL on error / NULL input.
char* wk_url_scrub_tracking(const char* url);

// Build a search URL for engine_id + query. NULL on unknown engine.
char* wk_search_engine_search_url(const char* engine_id, const char* query);

// Build a suggestion-API URL. Returns NULL when the engine has none (kagi).
char* wk_search_engine_suggest_url(const char* engine_id, const char* query);

#ifdef __cplusplus
}
#endif

#endif  // WEBKITIUM_URL_BRIDGE_C_H_
