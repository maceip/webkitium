// Pure C++ logic for URL normalization, tracking-parameter scrubbing,
// and search-engine URL construction. The C ABI wrapper in UrlBridgeC.cc
// is the only thing exposed to platform shells.

#ifndef WEBKITIUM_URL_NORMALIZE_H_
#define WEBKITIUM_URL_NORMALIZE_H_

#include <string>

namespace webkitium::url {

enum class Kind {
    Invalid = -1,
    Url     = 0,
    Search  = 1,
};

struct NormalizeResult {
    Kind        kind   = Kind::Invalid;
    std::string value;  // The URL string (kind Url) or the original query (kind Search).
};

// Match the Safari-ish heuristic that lived in TabWebView.normalize.
//   trim whitespace -> empty: Invalid
//   "http://" or "https://" prefix: Url, value = input verbatim
//   contains '.' and no space: Url, value = "https://" + input
//   else: Search, value = engine_search_url(engine_id, input)
NormalizeResult normalize(const std::string& raw_input, const std::string& engine_id);

// Strip known tracking parameters; preserve everything else and the
// fragment. Whitespace-equivalent if there were none.
std::string scrub_tracking(const std::string& url);

// Search and suggest URL builders. Empty string when the engine doesn't
// expose a suggest endpoint (kagi).
std::string search_url(const std::string& engine_id, const std::string& query);
std::string suggest_url(const std::string& engine_id, const std::string& query);

// Percent-encode for the value of a query parameter.
std::string percent_encode_query(const std::string& s);

}  // namespace webkitium::url

#endif  // WEBKITIUM_URL_NORMALIZE_H_
