#include "UrlNormalize.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <string_view>
#include <vector>

namespace webkitium::url {

namespace {

bool starts_with(const std::string& s, std::string_view prefix) {
    return s.size() >= prefix.size() &&
           std::equal(prefix.begin(), prefix.end(), s.begin());
}

bool icase_equal(std::string_view a, std::string_view b) {
    if (a.size() != b.size()) return false;
    for (size_t i = 0; i < a.size(); ++i) {
        if (std::tolower(static_cast<unsigned char>(a[i])) !=
            std::tolower(static_cast<unsigned char>(b[i]))) return false;
    }
    return true;
}

bool icase_has_prefix(std::string_view key, std::string_view prefix) {
    if (key.size() < prefix.size()) return false;
    for (size_t i = 0; i < prefix.size(); ++i) {
        if (std::tolower(static_cast<unsigned char>(key[i])) !=
            std::tolower(static_cast<unsigned char>(prefix[i]))) return false;
    }
    return true;
}

std::string trim_whitespace(const std::string& s) {
    auto is_ws = [](unsigned char c) {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f';
    };
    size_t lo = 0;
    while (lo < s.size() && is_ws(static_cast<unsigned char>(s[lo]))) ++lo;
    size_t hi = s.size();
    while (hi > lo && is_ws(static_cast<unsigned char>(s[hi - 1]))) --hi;
    return s.substr(lo, hi - lo);
}

// RFC 3986 unreserved + the subset that ought to round-trip in a `q=` value.
// Mirrors Foundation's `.urlQueryAllowed` closely enough for our purposes:
// percent-encode anything that isn't unreserved (A-Z a-z 0-9 - _ . ~).
std::string percent_encode(std::string_view s, bool extra_strict) {
    static const char hex[] = "0123456789ABCDEF";
    std::string out;
    out.reserve(s.size());
    for (unsigned char c : s) {
        bool unreserved =
            (c >= 'A' && c <= 'Z') ||
            (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') ||
            c == '-' || c == '_' || c == '.' || c == '~';
        if (unreserved) {
            out.push_back(static_cast<char>(c));
        } else if (!extra_strict && c == ' ') {
            // urlQueryAllowed permits unencoded space? No — encode as %20.
            out.append("%20");
        } else {
            out.push_back('%');
            out.push_back(hex[(c >> 4) & 0xF]);
            out.push_back(hex[c & 0xF]);
        }
    }
    return out;
}

// Tracking parameter names to strip (case-insensitive).
constexpr std::array<std::string_view, 19> kStripExact = {{
    "fbclid", "gclid", "dclid", "msclkid",
    "mc_cid", "mc_eid",
    "ref_src", "_ga", "igshid", "twclid",
    "gclsrc", "oly_anon_id", "oly_enc_id",
    "__s", "ref", "ref_url",
    "vero_id", "vero_conv", "share",
}};

constexpr std::array<std::string_view, 2> kStripPrefix = {{
    "utm_", "hmb_",
}};

bool is_tracking_key(std::string_view key) {
    for (auto k : kStripExact) {
        if (icase_equal(key, k)) return true;
    }
    for (auto p : kStripPrefix) {
        if (icase_has_prefix(key, p)) return true;
    }
    return false;
}

struct EngineUrls {
    std::string_view search;
    std::string_view suggest;  // empty when unsupported
};

EngineUrls resolve_engine(const std::string& engine_id_in) {
    // Default & fallback: duckduckgo.
    std::string id = engine_id_in.empty() ? "duckduckgo" : engine_id_in;

    if (id == "duckduckgo") {
        return {
            "https://duckduckgo.com/?q={q}",
            "https://duckduckgo.com/ac/?q={q}&type=list",
        };
    }
    if (id == "brave") {
        return {
            "https://search.brave.com/search?q={q}",
            "https://search.brave.com/api/suggest?q={q}",
        };
    }
    if (id == "kagi") {
        return { "https://kagi.com/search?q={q}", {} };
    }
    if (id == "google") {
        return {
            "https://www.google.com/search?q={q}",
            "https://www.google.com/complete/search?client=firefox&q={q}",
        };
    }
    // Unknown -> duckduckgo.
    return resolve_engine("duckduckgo");
}

std::string fill_template(std::string_view tmpl, const std::string& q_encoded) {
    std::string out;
    out.reserve(tmpl.size() + q_encoded.size());
    constexpr std::string_view kPlaceholder = "{q}";
    size_t pos = 0;
    while (pos < tmpl.size()) {
        auto hit = tmpl.find(kPlaceholder, pos);
        if (hit == std::string_view::npos) {
            out.append(tmpl.substr(pos));
            break;
        }
        out.append(tmpl.substr(pos, hit - pos));
        out.append(q_encoded);
        pos = hit + kPlaceholder.size();
    }
    return out;
}

// Split "key=value" / "key" / "=value" — value may be empty. Encoded
// representations are preserved verbatim; we only inspect the key.
struct KV {
    std::string_view key;
    std::string_view value;
    bool             has_eq;
};

KV split_param(std::string_view pair) {
    auto eq = pair.find('=');
    if (eq == std::string_view::npos) {
        return { pair, {}, false };
    }
    return { pair.substr(0, eq), pair.substr(eq + 1), true };
}

}  // namespace

std::string percent_encode_query(const std::string& s) {
    return percent_encode(s, /*extra_strict=*/false);
}

NormalizeResult normalize(const std::string& raw_input, const std::string& engine_id) {
    NormalizeResult r;
    std::string trimmed = trim_whitespace(raw_input);
    if (trimmed.empty()) {
        r.kind = Kind::Invalid;
        return r;
    }
    if (starts_with(trimmed, "http://") || starts_with(trimmed, "https://")) {
        r.kind  = Kind::Url;
        r.value = trimmed;
        return r;
    }
    bool has_dot   = trimmed.find('.') != std::string::npos;
    bool has_space = trimmed.find(' ') != std::string::npos;
    if (has_dot && !has_space) {
        r.kind  = Kind::Url;
        r.value = "https://" + trimmed;
        return r;
    }
    r.kind  = Kind::Search;
    r.value = search_url(engine_id, trimmed);
    return r;
}

std::string scrub_tracking(const std::string& url) {
    // Locate the query and the fragment; rewrite only the query.
    auto frag_pos = url.find('#');
    std::string before_frag = (frag_pos == std::string::npos) ? url : url.substr(0, frag_pos);
    std::string fragment    = (frag_pos == std::string::npos) ? std::string{} : url.substr(frag_pos);

    auto q_pos = before_frag.find('?');
    if (q_pos == std::string::npos) return url;

    std::string scheme_path = before_frag.substr(0, q_pos);
    std::string query       = before_frag.substr(q_pos + 1);

    if (query.empty()) return url;

    std::vector<std::string_view> kept;
    kept.reserve(8);
    size_t i = 0;
    while (i <= query.size()) {
        size_t amp = query.find('&', i);
        std::string_view pair =
            (amp == std::string::npos) ? std::string_view(query).substr(i)
                                       : std::string_view(query).substr(i, amp - i);
        if (!pair.empty()) {
            KV kv = split_param(pair);
            if (!is_tracking_key(kv.key)) {
                kept.push_back(pair);
            }
        }
        if (amp == std::string::npos) break;
        i = amp + 1;
    }

    if (kept.size() == (query.empty() ? 0 : std::count(query.begin(), query.end(), '&') + 1)) {
        // Nothing stripped.
        return url;
    }

    std::string rebuilt = scheme_path;
    if (!kept.empty()) {
        rebuilt.push_back('?');
        for (size_t j = 0; j < kept.size(); ++j) {
            if (j != 0) rebuilt.push_back('&');
            rebuilt.append(kept[j]);
        }
    }
    rebuilt.append(fragment);
    return rebuilt;
}

std::string search_url(const std::string& engine_id, const std::string& query) {
    EngineUrls e = resolve_engine(engine_id);
    return fill_template(e.search, percent_encode_query(query));
}

std::string suggest_url(const std::string& engine_id, const std::string& query) {
    EngineUrls e = resolve_engine(engine_id);
    if (e.suggest.empty()) return {};
    return fill_template(e.suggest, percent_encode_query(query));
}

}  // namespace webkitium::url
