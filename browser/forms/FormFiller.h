#pragma once

#include <optional>
#include <string>

namespace ng {

/// Snapshot of a single editable field in a form (from DOM or embedder).
struct HtmlFormField {
    std::string name;
    std::string id;
    /// Raw `autocomplete` attribute; matched case-insensitively (tokens per HTML).
    std::string autocomplete;
    /// Input type, e.g. text, email, tel.
    std::string type;
};

/// Minimal address/contact profile for heuristic form filling (no persistence here).
struct AutofillProfile {
    std::string givenName;
    std::string additionalName;
    std::string familyName;
    std::string fullName;
    std::string email;
    std::string tel;
    std::string organization;
    std::string streetAddress;
    std::string addressLine2;
    std::string locality;
    std::string region;
    std::string postalCode;
    std::string country;
};

/// Maps HTML fields to profile values using `autocomplete` tokens and common name/id hints.
class FormFiller {
public:
    static std::optional<std::string> suggestion(const HtmlFormField& field, const AutofillProfile& profile);
};

} // namespace ng
