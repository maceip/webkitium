#include "UrlBridgeC.h"

#include <cstdlib>
#include <cstring>
#include <string>

#include "UrlNormalize.h"

namespace {

char* dup_to_c(const std::string& s) {
    char* out = static_cast<char*>(std::malloc(s.size() + 1));
    if (!out) return nullptr;
    std::memcpy(out, s.data(), s.size());
    out[s.size()] = '\0';
    return out;
}

}  // namespace

extern "C" {

int wk_url_normalize(const char* raw_input, const char* engine_id, char** out_url) {
    if (!raw_input || !out_url) return -1;
    std::string engine = engine_id ? std::string(engine_id) : std::string();
    auto result = webkitium::url::normalize(std::string(raw_input), engine);
    if (result.kind == webkitium::url::Kind::Invalid) return -1;

    char* dup = dup_to_c(result.value);
    if (!dup) return -1;
    *out_url = dup;
    return static_cast<int>(result.kind);
}

void wk_url_free(char* p) {
    if (p) std::free(p);
}

char* wk_url_scrub_tracking(const char* url) {
    if (!url) return nullptr;
    return dup_to_c(webkitium::url::scrub_tracking(std::string(url)));
}

char* wk_search_engine_search_url(const char* engine_id, const char* query) {
    if (!query) return nullptr;
    std::string engine = engine_id ? std::string(engine_id) : std::string();
    return dup_to_c(webkitium::url::search_url(engine, std::string(query)));
}

char* wk_search_engine_suggest_url(const char* engine_id, const char* query) {
    if (!query) return nullptr;
    std::string engine = engine_id ? std::string(engine_id) : std::string();
    auto s = webkitium::url::suggest_url(engine, std::string(query));
    if (s.empty()) return nullptr;
    return dup_to_c(s);
}

}  // extern "C"
