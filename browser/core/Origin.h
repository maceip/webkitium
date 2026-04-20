#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace ng {

struct Origin {
    std::string scheme;
    std::string host;
    uint16_t port { 0 };

    bool isPotentiallyTrustworthy() const;
    std::string serialize() const;
};

struct FrameContext {
    Origin origin;
    Origin topLevelOrigin;
    bool isTopLevel { false };
    bool hasTransientUserActivation { false };

    // When set, overrides the default same-origin-with-ancestors heuristic (e.g. sandboxed
    // opaque origins). When unset: top-level frames, or frames whose origin matches
    // topLevelOrigin, are treated as same-origin with ancestors.
    std::optional<bool> sameOriginWithAncestors;

    bool computedSameOriginWithAncestors() const
    {
        if (sameOriginWithAncestors.has_value())
            return *sameOriginWithAncestors;
        return isTopLevel || origin.serialize() == topLevelOrigin.serialize();
    }

    // WebAuthn CollectedClientData: include crossOrigin only when this is true (spec: present
    // and true when not same-origin with ancestors; omitted otherwise).
    bool includeCrossOriginClientDataMember() const { return !computedSameOriginWithAncestors(); }
};

} // namespace ng

